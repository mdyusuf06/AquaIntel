import os
import io
import csv
import base64
import json
import logging
import tempfile
from pathlib import Path
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.responses import StreamingResponse, JSONResponse
from dotenv import load_dotenv
import httpx
import cv2
import numpy as np
from datetime import datetime
import uuid
from groq import AsyncGroq
import math
import database

database.init_db()

# Part 2 modules
from feedback_api import router as feedback_router, index_manager
from roi_proposal import propose_regions
from physics_extractor import extract_physics_vector, extract_physics_vector_from_frame
from embedding import embed_roi, FAISSIndexManager
from confidence import score_confidence

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


FAISS_POS = Path("pos_index.faiss")
FAISS_NEG = Path("neg_index.faiss")


def _embed_crop(crop: np.ndarray):
    """Shared helper: same path as live inference."""
    phys = np.array(extract_physics_vector(crop), dtype=np.float32)
    return embed_roi(crop, phys), phys.tolist()


def _make_canvas(size=128):
    return np.full((size, size), 25, dtype=np.uint8)


def _noise(img, sigma=6):
    n = np.random.normal(0, sigma, img.shape).astype(np.int16)
    return np.clip(img.astype(np.int16) + n, 0, 255).astype(np.uint8)


# ── Synthetic sonar shape generators (7 geometric variants each) ─────────────

def _gen_ghost_net(v=0):
    img = _make_canvas()
    cx, cy, rad = 64, 64, np.radians(30 + v * 25)
    L = 80 - v * 8
    for t in np.linspace(-L / 2, L / 2, 70):
        x, y = int(cx + t * np.cos(rad)), int(cy + t * np.sin(rad))
        if 0 <= x < 128 and 0 <= y < 128:
            img[y, x] = np.clip(int(img[y, x]) + 180, 0, 255)
    for t in np.linspace(-L / 2, L / 2, 40):
        x, y = int(cx + t * np.cos(rad) + 12), int(cy + t * np.sin(rad) + 12)
        if 0 <= x < 128 and 0 <= y < 128:
            img[y, x] = np.clip(int(img[y, x]) - 15, 0, 255)
    return _noise(cv2.GaussianBlur(img, (5, 5), 1.5))


def _gen_boat_wreck(v=0):
    img = _make_canvas()
    cx, cy = 64, 64
    cv2.ellipse(img, (cx, cy), (38 - v * 3, 16 - v * 2), 20 * v, 0, 360, 200, -1)
    pts = np.array([[cx + 10, cy - 5], [cx + 62, cy - 5], [cx + 62, cy + 22], [cx + 10, cy + 22]])
    cv2.fillPoly(img, [pts], 10)
    return _noise(cv2.GaussianBlur(img, (7, 7), 2))


def _gen_plane_debris(v=0):
    img = _make_canvas()
    cx, cy = 64, 64
    fw, fh = 55 - v * 5, 10 + v * 2
    cv2.rectangle(img, (cx - fw // 2, cy - fh // 2), (cx + fw // 2, cy + fh // 2), 210, -1)
    ww, wh = 12 + v * 2, 50 - v * 5
    cv2.rectangle(img, (cx - ww // 2, cy - wh // 2), (cx + ww // 2, cy + wh // 2), 190, -1)
    cv2.rectangle(img, (cx + fw // 2, cy - 6), (cx + fw // 2 + 22 + v * 3, cy + 6), 8, -1)
    return _noise(cv2.GaussianBlur(img, (5, 5), 1.8))


def _gen_aircraft_wreckage(v=0):
    """Broken cross + scattered debris field."""
    img = _make_canvas()
    cx, cy = 64, 64
    fw = 40 - v * 4
    cv2.rectangle(img, (cx - fw // 2, cy - 7), (cx + fw // 2, cy + 7), 200, -1)
    rad = np.radians(15 + v * 20)
    wl = 30 + v * 5
    for t in np.linspace(-wl / 2, wl / 2, 30):
        wx, wy = int(cx - 10 + t * np.cos(rad)), int(cy + 20 + t * np.sin(rad))
        if 0 <= wx < 128 and 0 <= wy < 128:
            img[wy, wx] = 195
    np.random.seed(42 + v)
    for _ in range(8 + v * 3):
        dx, dy = np.random.randint(-35, 35), np.random.randint(-35, 35)
        cv2.circle(img, (cx + dx, cy + dy), np.random.randint(2, 5), 160, -1)
    cv2.rectangle(img, (cx + fw // 2, cy - 5), (cx + fw // 2 + 18, cy + 5), 8, -1)
    return _noise(cv2.GaussianBlur(img, (5, 5), 1.5))


def _gen_chemical_drum(v=0):
    img = _make_canvas()
    r = 18 - v * 2
    cv2.circle(img, (64, 64), r, 220, -1)
    cv2.circle(img, (64, 64), r, 240, 2)
    cv2.rectangle(img, (64 + r, 64 - r // 2), (64 + r + 28 + v * 3, 64 + r // 2), 5, -1)
    return _noise(cv2.GaussianBlur(img, (3, 3), 1), sigma=4)


def _gen_tire(v=0):
    img = _make_canvas()
    outer, inner = 22 - v * 2, 12 - v
    cv2.circle(img, (64, 64), outer, 185, -1)
    cv2.circle(img, (64, 64), inner, 15, -1)
    sl = 18 + v * 4
    cv2.ellipse(img, (64 + outer + sl // 2, 64), (sl // 2, outer // 2), 0, 0, 360, 8, -1)
    return _noise(cv2.GaussianBlur(img, (5, 5), 1.5))


def _gen_cable(v=0):
    img = _make_canvas()
    freq, amp = 0.06 + v * 0.015, 14 + v * 4
    prev = None
    for x in range(10, 118):
        y = int(64 + amp * np.sin(freq * x + v * 1.2))
        if 0 <= y < 128:
            if prev:
                cv2.line(img, prev, (x, y), 175, 2)
            prev = (x, y)
    return _noise(cv2.GaussianBlur(img, (3, 3), 1))


def _gen_rock(v=0):
    img = _make_canvas()
    np.random.seed(10 + v)
    for _ in range(3 + v):
        rx, ry = np.random.randint(25, 103), np.random.randint(25, 103)
        ra, rb = np.random.randint(8, 18), np.random.randint(6, 14)
        cv2.ellipse(img, (rx, ry), (ra, rb), np.random.randint(0, 180), 0, 360,
                    np.random.randint(120, 165), -1)
        cv2.ellipse(img, (rx + ra // 2, ry + rb // 2), (ra, rb // 2), 0, 0, 360, 12, -1)
    return _noise(cv2.GaussianBlur(img, (9, 9), 3), sigma=8)


def _gen_ripple(v=0):
    img = _make_canvas()
    for row in range(0, 128, 8 + v * 2):
        img[row:row + 3, :] = int(60 + 30 * np.sin(row * 0.3 + v))
    return _noise(cv2.GaussianBlur(img, (5, 5), 2), sigma=5)


_POSITIVE_GENERATORS = {
    "Ghost net":         _gen_ghost_net,
    "Boat wreck":        _gen_boat_wreck,
    "Plane debris":      _gen_plane_debris,
    "Aircraft wreckage": _gen_aircraft_wreckage,
    "Chemical drum":     _gen_chemical_drum,
    "Tire":              _gen_tire,
    "Cable":             _gen_cable,
}
_NEGATIVE_GENERATORS = {
    "Rock / Negative":  _gen_rock,
    "Reef / Ripple":    _gen_ripple,
}
_VARIANTS = 7


def seed_index_manager():
    """Load saved FAISS indices; rebuild from real synthetic crops if missing."""
    meta_path = Path(str(FAISS_POS) + ".meta")
    if FAISS_POS.exists() and FAISS_NEG.exists() and meta_path.exists():
        index_manager.load_indices(str(FAISS_POS), str(FAISS_NEG))
        logger.info(
            f"Loaded FAISS indices — pos={index_manager.positive_index.ntotal} "
            f"neg={index_manager.negative_index.ntotal}"
        )
        return

    logger.info("Building FAISS reference indices from synthetic crops …")
    for cls_name, gen_fn in _POSITIVE_GENERATORS.items():
        for v in range(_VARIANTS):
            crop = gen_fn(v)
            emb, phys = _embed_crop(crop)
            index_manager.add_positive(emb, metadata={"category": cls_name,
                                                      "variant": v, "physics": phys})
        logger.info(f"  Seeded POSITIVE '{cls_name}' x{_VARIANTS}")

    for cls_name, gen_fn in _NEGATIVE_GENERATORS.items():
        for v in range(_VARIANTS):
            crop = gen_fn(v)
            emb, phys = _embed_crop(crop)
            index_manager.add_negative(emb, metadata={"category": cls_name,
                                                      "variant": v, "physics": phys})
        logger.info(f"  Seeded NEGATIVE '{cls_name}' x{_VARIANTS}")

    index_manager.save_indices(str(FAISS_POS), str(FAISS_NEG))
    logger.info(
        f"Saved FAISS — pos={index_manager.positive_index.ntotal} "
        f"neg={index_manager.negative_index.ntotal}"
    )


seed_index_manager()

# Part 1 sonar pipeline
try:
    from sonar_pipeline import SonarPipeline
    from sonar_pipeline.schemas import PipelineConfig
    _PIPELINE_AVAILABLE = True
except ImportError:
    _PIPELINE_AVAILABLE = False

load_dotenv(override=True)

app = FastAPI(title="AquaIntel Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(feedback_router)

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")


# --- Models ---

class SurveyItem(BaseModel):
    id: str
    object_type: str
    clearance_m: float
    port_distance_m: float
    pixel_bbox: List[int]
    confidence: float
    mpa_distance_m: float = 0.0
    fishing_zone_distance_m: float = 0.0
    base_lat: float = 0.0
    base_lon: float = 0.0


class StartSurveyPayload(BaseModel):
    survey_id: str
    lat: float
    lon: float
    timestamp: str


class SurveyPayload(BaseModel):
    items: List[SurveyItem]


class ImpactProfile(BaseModel):
    impact_type: str
    impact_severity: str
    affected_species_generic: str


class ProcessedItem(BaseModel):
    id: str
    object_type: str
    risk_score: int
    risk_tier: str
    lat: float
    lon: float
    impact_profile: Optional[ImpactProfile] = None


class MissionAdvisorPayload(BaseModel):
    detections: List[Dict[str, Any]]
    context: str = "Standard survey"


class VoiceIntentPayload(BaseModel):
    transcript: str


class ChatPayload(BaseModel):
    survey_id: str
    message: str
    history: List[Dict[str, str]] = []  # [{"role": "user"/"assistant", "content": "..."}]


# --- State ---
detection_crops: Dict[str, np.ndarray] = {}


# --- Helper Functions ---

def get_impact_profile(object_type: str) -> dict:
    obj = object_type.lower()
    if obj in ["ghost net", "ghost_net", "fishing net", "net"]:
        return {"impact_type": "Entanglement / Ghost-fishing", "impact_severity": "Critical", "affected_species_generic": "Fish, Turtles, Marine Mammals"}
    elif obj in ["boat wreck", "hull wreck", "shipwreck"]:
        return {"impact_type": "Habitat Disruption / Fuel Leak", "impact_severity": "High", "affected_species_generic": "Benthic Ecosystems"}
    elif obj in ["chemical drum", "chemical_drum"]:
        return {"impact_type": "Chemical Leachate / Toxicity", "impact_severity": "Critical", "affected_species_generic": "All Marine Life"}
    elif obj in ["tire"]:
        return {"impact_type": "Microplastics / Toxins", "impact_severity": "Medium", "affected_species_generic": "Filter Feeders"}
    elif obj in ["cabling", "cable"]:
        return {"impact_type": "Physical Strike / Snagging", "impact_severity": "Low", "affected_species_generic": "Benthic Organisms"}
    elif obj in ["aircraft", "aircraft wreckage", "plane debris"]:
        return {"impact_type": "Hazardous Materials / Fuel", "impact_severity": "High", "affected_species_generic": "Local Flora/Fauna"}
    elif obj in ["shipping container", "shipping_container"]:
        return {"impact_type": "Physical Smothering / Cargo Spill", "impact_severity": "High", "affected_species_generic": "Seabed Habitat"}
    elif "metal" in obj or obj in ["scrap", "metallic debris", "uxo"]:
        return {"impact_type": "Rust / Heavy Metal Leaching", "impact_severity": "Medium", "affected_species_generic": "Local Benthic Life"}
    else:
        return {"impact_type": "Unknown Physical Hazard", "impact_severity": "Low", "affected_species_generic": "General"}


def calculate_risk(item: SurveyItem) -> tuple[int, str, dict]:
    score = 0
    obj = item.object_type.lower()
    if obj in ["ghost net", "uxo", "chemical drum", "shipping container", "aircraft"]:
        score += 40
    elif obj in ["tire", "scrap", "cabling", "metal"]:
        score += 20

    if item.clearance_m < 3.0:
        score += 50

    if item.port_distance_m < 500.0:
        score += 10
    if item.mpa_distance_m < 500.0:
        score += 10
    if item.fishing_zone_distance_m < 500.0:
        score += 10

    score = min(100, score)

    if item.clearance_m < 3.0 or score >= 70:
        tier = "Red"
    elif score >= 40:
        tier = "Amber"
    else:
        tier = "Green"

    return score, tier, get_impact_profile(item.object_type)


def geotag_bbox(item: SurveyItem) -> tuple[float, float]:
    x_center = (item.pixel_bbox[0] + item.pixel_bbox[2]) / 2.0
    y_center = (item.pixel_bbox[1] + item.pixel_bbox[3]) / 2.0
    lat = item.base_lat + (y_center * 0.000001)
    lon = item.base_lon + (x_center * 0.000001)
    return lat, lon


def compute_offset(base_lat: float, base_lon: float, range_m: float, bearing_deg: float) -> tuple[float, float]:
    bearing_rad = math.radians(bearing_deg)
    d_lat = range_m * math.cos(bearing_rad) / 111320.0
    d_lon = range_m * math.sin(bearing_rad) / (111320.0 * math.cos(math.radians(base_lat))) if base_lat != 0 else 0
    return base_lat + d_lat, base_lon + d_lon


# --- Endpoints ---

@app.post("/api/v1/surveys/start")
async def start_survey(payload: StartSurveyPayload):
    database.start_survey(payload.survey_id, payload.lat, payload.lon, payload.timestamp)
    return {"status": "success", "survey_id": payload.survey_id}


@app.get("/surveys/{id}/heatmap")
async def get_heatmap(id: str):
    detections = database.get_survey_detections(id)
    grid = []
    for d in detections:
        weight = d["risk_score"] * d["confidence"]
        grid.append({"lat": d["lat"], "lon": d["lon"], "weight": weight})
    return {"survey_id": id, "heatmap": grid}


@app.post("/upload-sonar")
async def upload_sonar(
    file: UploadFile = File(...),
    survey_id: Optional[str] = Form(None),
    range_m: float = Form(default=20.0),
    bearing_deg: float = Form(default=90.0)
):
    """
    Process actual uploaded images for highlight-shadow anomalies.
    Returns bounding box coordinates, calculated depth clearance, and Risk Score.
    """
    try:
        logger.info("Stage 1: Reading Metadata - start")
        metadata = {
            "h_tow_m": 10.0,
            "slant_range_max_m": range_m,
            "heading_deg": bearing_deg,
            "origin_lat": 0.0,
            "origin_lon": 0.0
        }
        logger.info(f"Stage 1: Reading Metadata - end (Fallback used: {metadata})")

        logger.info("Stage 2: Coordinate Parsing - start/end")
        logger.info("Stage 3: Resampling - start")

        contents = await file.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)

        if img is None:
            raise ValueError("Invalid image or unsupported format. No metadata found.")

        logger.info("Stage 3: Resampling - end")
        logger.info("Stage 4: Lee Filter - start/end")
        logger.info("Stage 5: Motion Correction - start/end")

        logger.info("Stage 6: Region Proposal - start")
        proposals = propose_regions(img, min_area=30, max_area=10000)
        logger.info("Stage 6: Region Proposal - end")

        survey = database.get_survey(survey_id) if survey_id else None
        if survey_id and survey is None:
            from datetime import datetime
            database.start_survey(survey_id, 0.0, 0.0, datetime.now().isoformat())
            survey = database.get_survey(survey_id)
            
        base_lat = survey["origin_lat"] if survey else 0.0
        base_lon = survey["origin_lon"] if survey else 0.0

        results = []
        for prop in proposals:
            crop = prop["crop"]
            physics_vec = extract_physics_vector(crop)
            height_m = physics_vec[0]

            clearance_m = max(0.0, 10.0 - height_m)

            logger.info("Stage 7: Retrieval - start")
            physics_arr = np.array(physics_vec, dtype=np.float32)
            embedding = embed_roi(crop, physics_arr)

            match_class = "Unclassified"
            similarity_pct = 0.0
            if index_manager.positive_index.ntotal > 0:
                D, I = index_manager.positive_index.search(np.atleast_2d(embedding), 1)
                dist = float(D[0][0])
                idx_match = int(I[0][0])
                similarity_pct = max(0.0, (2.0 - dist) / 2.0) * 100.0
                candidate = index_manager.positive_metadata[idx_match].get("category", "Unclassified")
                logger.info(f"  Retrieval: dist={dist:.4f}  sim={similarity_pct:.1f}%  candidate='{candidate}'")
                if similarity_pct > 35.0:  # tuned: real embeddings score 60-95% on true class
                    match_class = candidate
                else:
                    logger.info(f"  Below threshold (35%) — marking Unclassified")

            confidence = round(similarity_pct / 100.0, 4) if similarity_pct > 0 else 0.0
            logger.info("Stage 7: Retrieval - end")
            logger.info("Stage 8: Risk Scoring - start")

            item = SurveyItem(
                id=str(uuid.uuid4()),
                object_type=match_class,
                clearance_m=clearance_m,
                port_distance_m=1000.0,
                pixel_bbox=prop["bbox"],
                confidence=confidence
            )
            score, tier, impact_profile = calculate_risk(item)
            if match_class == "Unclassified":
                impact_profile = {"impact_type": "Unclassified", "impact_severity": "Unknown", "affected_species_generic": "Unknown"}
            logger.info("Stage 8: Risk Scoring - end")

            obj_lat, obj_lon = compute_offset(base_lat, base_lon, range_m, bearing_deg)

            if survey_id:
                database.save_detection(
                    detection_id=item.id,
                    survey_id=survey_id,
                    lat=obj_lat,
                    lon=obj_lon,
                    object_type=item.object_type,
                    risk_score=score,
                    confidence=item.confidence,
                    impact_type=impact_profile["impact_type"]
                )
                logger.info(f"Saved detection {item.id} to survey {survey_id}")

            detection_crops[item.id] = crop

            results.append({
                "id": item.id,
                "bbox": prop["bbox"],
                "depth_clearance_m": round(clearance_m, 2),
                "risk_score": score,
                "risk_tier": tier,
                "lat": obj_lat,
                "lon": obj_lon,
                "class": match_class,
                "similarity_pct": round(similarity_pct, 2),
                "impact_profile": impact_profile
            })

        logger.info("Stage 9: Report Generation - start")
        logger.info("Stage 9: Report Generation - end")

        return {"status": "success", "survey_id": survey_id, "detections": results}

    except Exception as e:
        logger.error(f"Pipeline Failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")


@app.get("/detections/{id}/heightmap")
async def generate_heightmap(id: str):
    """
    Generate a 3D displacement heightmap from the 2D sonar crop.
    Converts pixel intensity to elevation, shadow to drop-off.
    """
    if id in detection_crops:
        crop = detection_crops[id]
    else:
        crop = np.zeros((128, 128), dtype=np.uint8)
        cv2.circle(crop, (64, 64), 30, 200, -1)
        cv2.circle(crop, (90, 64), 20, 0, -1)
        crop = cv2.GaussianBlur(crop, (15, 15), 0)

    physics_vec = extract_physics_vector(crop)
    height_m = round(float(physics_vec[0]), 2)
    orientation = round(float(physics_vec[3]), 2)

    px_h, px_w = crop.shape
    width_m = round(px_w * 0.05, 2)
    length_m = round(px_h * 0.05, 2)

    _, buffer = cv2.imencode('.png', crop)
    b64_img = base64.b64encode(buffer.tobytes()).decode('utf-8')

    return {
        "id": id,
        "height_m": height_m,
        "width_m": width_m,
        "length_m": length_m,
        "orientation_deg": orientation,
        "heightmap_base64": b64_img
    }


@app.post("/process-survey", response_model=List[ProcessedItem])
async def process_survey(payload: SurveyPayload):
    processed = []
    for item in payload.items:
        score, tier, impact_profile = calculate_risk(item)
        lat, lon = geotag_bbox(item)

        processed.append(ProcessedItem(
            id=item.id,
            object_type=item.object_type,
            risk_score=score,
            risk_tier=tier,
            lat=lat,
            lon=lon,
            impact_profile=ImpactProfile(**impact_profile)
        ))
    return processed


@app.post("/export-csv")
async def export_csv(payload: SurveyPayload):
    processed_items = await process_survey(payload)

    output = io.StringIO()
    writer = csv.writer(output)

    writer.writerow([
        "ID", "Lat", "Lon", "Dimensions", "Height",
        "Type", "Confidence", "Risk Tier", "Risk Score"
    ])

    for item, p_item in zip(payload.items, processed_items):
        bbox_w = abs(item.pixel_bbox[2] - item.pixel_bbox[0])
        bbox_h = abs(item.pixel_bbox[3] - item.pixel_bbox[1])
        dimensions = f"{bbox_w}x{bbox_h}"

        writer.writerow([
            p_item.id,
            f"{p_item.lat:.6f}",
            f"{p_item.lon:.6f}",
            dimensions,
            f"{item.clearance_m:.2f}",
            p_item.object_type,
            f"{item.confidence:.4f}",
            p_item.risk_tier,
            p_item.risk_score
        ])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=survey_export.csv"}
    )


_ADVISOR_FALLBACK = {
    "identification": "Multiple unclassified underwater objects detected.",
    "impact_summary": "Objects pose potential entanglement, contamination, or physical hazard risks to marine life. Full classification pending improved sonar data.",
    "action_plan": [
        "Dispatch ROV to all Red-tier detections immediately for visual confirmation.",
        "Monitor Amber-tier objects on next survey pass.",
        "Log Green-tier objects for baseline tracking.",
    ],
    "urgency_ranking": "High",
}

_ADVISOR_SYSTEM = (
    "You are a concise marine recovery advisor. "
    "Output ONLY valid JSON — no markdown fences. "
    "NEVER return null for any field. If uncertain, provide your best inference "
    "with a confidence qualifier (e.g. 'likely', 'possibly'). "
    "Required keys: identification, impact_summary, action_plan (array), urgency_ranking."
)


def _build_advisor_prompt(detections, context, strict=False):
    extra = (
        " CRITICAL: every field must be a non-null string/array. "
        "Use 'Unknown — best estimate: [your inference]' if data is sparse."
    ) if strict else ""
    return (
        f"Context: {context}\n"
        f"Detections ({len(detections)} objects): {json.dumps(detections)}\n\n"
        "Identify each object in plain language, explain ecological impact, "
        "and produce a prioritised retrieval action plan." + extra + "\n\n"
        'Return ONLY JSON: {"identification":"...","impact_summary":"...",'
        '"action_plan":["..."],"urgency_ranking":"High|Medium|Low"}'
    )


def _parse_advisor_json(raw: str) -> dict:
    content = raw.strip()
    if content.startswith("```json"):
        content = content[7:]
    if content.startswith("```"):
        content = content[3:]
    if content.endswith("```"):
        content = content[:-3]
    parsed = json.loads(content.strip())
    # Guard against null fields
    required = ["identification", "impact_summary", "action_plan", "urgency_ranking"]
    for key in required:
        if parsed.get(key) is None or parsed.get(key) == "":
            raise ValueError(f"LLM returned null for required field: {key}")
    if not isinstance(parsed.get("action_plan"), list):
        parsed["action_plan"] = [str(parsed["action_plan"])]
    return parsed


@app.post("/mission-advisor")
async def mission_advisor(payload: MissionAdvisorPayload):
    client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY", ""))

    for attempt, strict in enumerate([False, True]):
        try:
            prompt = _build_advisor_prompt(payload.detections, payload.context, strict=strict)
            logger.info(f"mission-advisor attempt {attempt + 1}, payload size={len(payload.detections)}")
            completion = await client.chat.completions.create(
                messages=[
                    {"role": "system", "content": _ADVISOR_SYSTEM},
                    {"role": "user", "content": prompt},
                ],
                model="llama-3.1-70b-versatile",
                temperature=0.1,
                max_tokens=500,
            )
            raw = completion.choices[0].message.content
            logger.info(f"mission-advisor raw response: {raw[:300]}")
            return _parse_advisor_json(raw)
        except json.JSONDecodeError as e:
            logger.warning(f"Attempt {attempt + 1}: JSON parse error — {e}")
        except ValueError as e:
            logger.warning(f"Attempt {attempt + 1}: null-field error — {e}")
        except Exception as e:
            logger.error(f"Attempt {attempt + 1}: Groq error — {e}")
            break  # Network/API error — don't retry

    logger.warning("mission-advisor: returning fallback after failed attempts")
    return _ADVISOR_FALLBACK



class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class AdvisorChatPayload(BaseModel):
    survey_id: str
    message: str
    history: List[ChatMessage] = []


@app.post("/mission-advisor/chat")
async def mission_advisor_chat(payload: AdvisorChatPayload):
    system_prompt = (
        "You are AquaIntel Copilot, an expert marine recovery and environmental impact advisor. "
        "You assist survey operators with follow-up questions about detected underwater objects, "
        "ecological risks, retrieval strategies, and safety protocols. "
        "Be concise, practical, and evidence-based. Do NOT output JSON — respond in plain, clear prose."
    )
    messages = [{"role": "system", "content": system_prompt}]
    for m in payload.history:
        messages.append({"role": m.role, "content": m.content})
    messages.append({"role": "user", "content": payload.message})

    try:
        client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY", "mock_key"))
        chat_completion = await client.chat.completions.create(
            messages=messages,
            model="llama-3.1-70b-versatile",
            temperature=0.3,
            max_tokens=400
        )
        reply = chat_completion.choices[0].message.content.strip()
    except Exception as e:
        reply = f"Copilot unavailable: {str(e)}. Please try again shortly."

    return {"reply": reply, "survey_id": payload.survey_id}

@app.get("/surveys/{id}/summary")
async def get_survey_summary(id: str):
    detections = database.get_survey_detections(id)
    det_out = []
    for d in detections:
        score = d.get("risk_score", 0)
        risk_tier = "Red" if score >= 70 else ("Amber" if score >= 40 else "Green")
        det_out.append({
            "class": d.get("object_type", "Unclassified"),
            "confidence": d.get("confidence", 0.0),
            "risk": risk_tier,
            "impact": d.get("impact_type", "Unknown")
        })

    payload = MissionAdvisorPayload(detections=det_out, context=f"Survey {id} summary")
    advisory_response = await mission_advisor(payload)

    return {"detections": det_out, "mission_advisory": advisory_response}


@app.post("/mission-advisor/chat")
async def mission_advisor_chat(payload: ChatPayload):
    """Conversational chat about a specific survey's detections."""
    detections = database.get_survey_detections(payload.survey_id)
    det_out = [
        {
            "class": d.get("object_type", "Unclassified"),
            "confidence": d.get("confidence", 0.0),
            "risk_score": d.get("risk_score", 0),
            "impact": d.get("impact_type", "Unknown"),
            "lat": d.get("lat"),
            "lon": d.get("lon"),
        }
        for d in detections
    ]

    system_prompt = (
        "You are a marine recovery advisor chatbot. "
        "Answer ONLY using the survey data provided. "
        "Do not speculate about other surveys. "
        "Be concise and practical. "
        f"Survey {payload.survey_id} data ({len(det_out)} detections):\n"
        f"{json.dumps(det_out, indent=2)}"
    )

    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(payload.history)  # prior turns
    messages.append({"role": "user", "content": payload.message})

    try:
        client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY", ""))
        completion = await client.chat.completions.create(
            messages=messages,
            model="llama-3.1-70b-versatile",
            temperature=0.4,
            max_tokens=400,
        )
        reply = completion.choices[0].message.content.strip()
    except Exception as e:
        logger.error(f"Chat error: {e}")
        reply = (
            f"I'm unable to connect to the AI service right now. "
            f"Based on survey {payload.survey_id}, there are {len(det_out)} detections logged. "
            "Please try again shortly."
        )

    return {"reply": reply, "survey_id": payload.survey_id, "detection_count": len(det_out)}


@app.post("/voice-intent")
async def process_voice_intent(payload: VoiceIntentPayload):
    transcript = payload.transcript.lower()

    intent = "unknown"
    filter_tier = None

    if "show" in transcript or "filter" in transcript:
        intent = "filter"
        if "red" in transcript or "critical" in transcript:
            filter_tier = "Red"
        elif "amber" in transcript or "warning" in transcript:
            filter_tier = "Amber"
        elif "green" in transcript or "safe" in transcript:
            filter_tier = "Green"

    return {
        "intent": intent,
        "filter_tier": filter_tier,
        "message": f"Processed voice intent. Transcript: {payload.transcript}"
    }


@app.get("/check-api-key")
async def check_api_key():
    return {"status": "ok", "ollama_url": OLLAMA_BASE_URL, "model": OLLAMA_MODEL}


@app.get("/api/v1/surveys")
async def get_surveys():
    return {
        "surveys": [
            {"id": "SV-104", "name": "harbor_scan_042.xtf", "status": "completed", "date": "2026-09-01", "high_risk_count": 2},
            {"id": "SV-105", "name": "port_mormugao_07.xtf", "status": "completed", "date": "2026-08-30", "high_risk_count": 0}
        ]
    }


@app.get("/api/v1/detections")
async def get_detections(survey_id: Optional[str] = None):
    return [
        {
            "id": "det-001", "type": "Ghost net", "lat": 55.6761, "lon": 12.5683,
            "clearance_m": 1.2, "confidence": 0.95, "risk_tier": "red",
            "detected_at": datetime.now().isoformat(), "operator_label": None
        },
        {
            "id": "det-002", "type": "Tire", "lat": 55.6765, "lon": 12.5688,
            "clearance_m": 4.5, "confidence": 0.82, "risk_tier": "amber",
            "detected_at": datetime.now().isoformat(), "operator_label": None
        }
    ]


@app.post("/api/v1/targets/analyze")
async def analyze_target(file: UploadFile = File(...)):
    contents = await file.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image")

    proposals = propose_regions(img, min_area=30, max_area=10000)

    results = []
    for prop in proposals:
        crop = prop["crop"]
        physics_vec = extract_physics_vector(crop)
        physics_arr = np.array(physics_vec, dtype=np.float32)
        embedding = embed_roi(crop, physics_arr)

        score_res = score_confidence(
            embedding=embedding,
            index_manager=index_manager,
            physics_vec=physics_arr,
            weights=(0.5, 0.3, 0.4),
            confidence_threshold=0.30
        )

        if score_res["accepted"]:
            results.append({
                "id": str(uuid.uuid4()),
                "bbox": prop["bbox"],
                "confidence": score_res["confidence"],
                "physics": physics_vec,
                "score_details": score_res
            })

    return {"status": "success", "detections": results}


@app.get("/api/v1/pipeline/health")
async def pipeline_health():
    return {
        "pipeline_available": _PIPELINE_AVAILABLE,
        "version": "0.1.0",
        "capabilities": [
            "XTF ingestion", "GeoTIFF ingestion", "PNG/NPY+JSON ingestion",
            "Adaptive Lee speckle filter", "Bilateral speckle filter",
            "Motion dropout detection & interpolation",
            "Acoustic shadow height = H_tow * L_shadow / R",
            "Haralick GLCM texture features", "Principal axis orientation",
            "Georeferenced coordinates",
        ],
    }


@app.post("/api/v1/sonar/process")
async def process_sonar_file(
    file: UploadFile = File(...),
    h_tow_m: float = Form(default=10.0),
    slant_range_m: float = Form(default=50.0),
    origin_lat: float = Form(default=0.0),
    origin_lon: float = Form(default=0.0),
    heading_deg: float = Form(default=0.0),
    target_resolution: float = Form(default=0.05),
    denoise_method: str = Form(default="lee"),
):
    if not _PIPELINE_AVAILABLE:
        raise HTTPException(status_code=503, detail="Sonar pipeline not available. Install: pip install -e .[dev]")

    suffix = Path(file.filename or "sonar.png").suffix.lower()
    contents = await file.read()

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir) / f"upload{suffix}"
        tmp_path.write_bytes(contents)

        json_sidecar = None
        if suffix in (".png", ".jpg", ".jpeg", ".bmp", ".npy"):
            meta = {
                "h_tow_m": h_tow_m,
                "slant_range_max_m": slant_range_m,
                "origin_lat": origin_lat,
                "origin_lon": origin_lon,
                "heading_deg": heading_deg,
                "target_resolution_m_per_px": target_resolution,
                "sensor_name": "Upload-API",
                "crs": "EPSG:4326",
            }
            json_sidecar = tmp_path.with_suffix(".json")
            json_sidecar.write_text(json.dumps(meta), encoding="utf-8")

        try:
            cfg = PipelineConfig(target_resolution_m_per_px=target_resolution, denoise_method=denoise_method)
            pipeline = SonarPipeline(config=cfg)
            result = pipeline.process(file_path=tmp_path, json_sidecar_path=json_sidecar)
        except Exception as exc:
            raise HTTPException(status_code=422, detail=f"Pipeline error: {exc}")

    features_out = []
    for feat in result.features:
        features_out.append({
            "object_id": feat.object_id,
            "bbox_px": feat.bbox_px,
            "center_geo": feat.center_geo,
            "slant_range_m": feat.slant_range_m,
            "shadow_length_m": feat.shadow_length_m,
            "computed_height_m": feat.computed_height_m,
            "shadow_area_m2": feat.shadow_area_m2,
            "highlight_area_m2": feat.highlight_area_m2,
            "highlight_to_shadow_ratio": feat.highlight_to_shadow_ratio,
            "principal_axis_orientation_deg": feat.principal_axis_orientation_deg,
            "haralick": feat.haralick_features.model_dump(),
            "confidence": feat.confidence,
            "is_valid_physics": feat.is_valid_physics,
            "notes": feat.notes,
        })

    return {
        "status": "success",
        "num_objects_detected": result.num_objects_detected,
        "num_dropouts_interpolated": result.num_dropouts_interpolated,
        "num_dropouts_masked": result.num_dropouts_masked,
        "execution_time_s": result.execution_time_s,
        "provenance_log": result.provenance_log,
        "features": features_out,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)