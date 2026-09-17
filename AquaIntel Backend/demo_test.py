"""
AquaIntel Part 2 — End-to-End Integration Demo & Validation Script
===================================================================
Wires together Steps 3 -> 4 -> 5 -> 6:
1. Generates synthetic sonar image + physics vector.
2. Step 3: Propose candidate ROIs via propose_regions().
3. Step 4: Extract unified embeddings (MobileNetV3 + physics_vec) via embed_roi()
   and initialize positive/negative FAISS indices.
4. Step 5: Score candidates with score_confidence().
5. Step 6: Test live learning API feedback submission (POST /api/v1/targets/feedback).
"""

import cv2
import numpy as np
from fastapi.testclient import TestClient

# Import AquaIntel Part 2 modules
from roi_proposal import propose_regions
from embedding import embed_roi, FAISSIndexManager
from confidence import score_confidence
from main import app
from feedback_api import index_manager


def create_synthetic_sonar_image(width: int = 512, height: int = 512) -> np.ndarray:
    """Create synthetic sonar image with acoustic highlights and shadows."""
    np.random.seed(42)
    seabed = np.random.normal(60, 5, (height, width)).astype(np.float32)
    seabed = cv2.GaussianBlur(seabed, (3, 3), 0)

    # Add Target 1: Synthetic Drum / Container (Extreme bright highlight + acoustic shadow)
    cv2.circle(seabed, (150, 200), 25, 255, -1)  # Bright Highlight
    cv2.rectangle(seabed, (180, 185), (240, 215), 0, -1)  # Dark Acoustic Shadow

    # Add Target 2: Synthetic Rock / Ripple (Clutter anomaly)
    cv2.ellipse(seabed, (350, 350), (40, 15), 45, 0, 360, 250, -1)
    cv2.ellipse(seabed, (380, 380), (45, 18), 45, 0, 360, 0, -1)

    return np.clip(seabed, 0, 255).astype(np.uint8)


def run_demo():
    print("=" * 65)
    print("      AquaIntel Part 2: Proposal & Retrieval Engine Demo      ")
    print("=" * 65)

    # -------------------------------------------------------------
    # 1. Input Simulation (Sonar Image + Physics Feature Vectors)
    # -------------------------------------------------------------
    print("\n[Step 1] Loading preprocessed sonar image & physics vector...")
    sonar_img = create_synthetic_sonar_image()
    print(f"   -> Sonar Image Shape: {sonar_img.shape}, dtype: {sonar_img.dtype}")

    # Physics feature vector format: [height, shadow_area, hs_ratio, orientation, haralick]
    target_physics_vec = np.array([0.85, 25.4, 1.45, 0.32, 0.78], dtype=np.float32)
    clutter_physics_vec = np.array([0.08, 2.1, 0.22, 1.15, 0.15], dtype=np.float32)

    # -------------------------------------------------------------
    # 2. Step 3: ROI Candidate Proposal
    # -------------------------------------------------------------
    print("\n[Step 3] Executing propose_regions(image) via MSER + Adaptive Thresh...")
    proposals = propose_regions(sonar_img, min_area=30, max_area=10000)
    print(f"   -> Detected {len(proposals)} candidate regions of interest (ROIs).")

    if not proposals:
        print("   [!] Warning: Fallback proposal crop invoked.")
        proposals = [{
            "bbox": (140, 180, 80, 40),
            "crop": sonar_img[180:220, 140:220],
            "area": 3200.0,
            "center": (180, 200)
        }]

    first_proposal = proposals[0]
    print(f"   -> Top Proposal Bounding Box: {first_proposal['bbox']}, Area: {first_proposal['area']}")

    # -------------------------------------------------------------
    # 3. Step 4: ROI Embedding & FAISS Index Building
    # -------------------------------------------------------------
    print("\n[Step 4] Extracting embeddings & initializing FAISS indices...")
    crop_img = first_proposal["crop"]
    embedding = embed_roi(crop_img, target_physics_vec)
    print(f"   -> MobileNetV3 + Physics Unified Vector Shape: {embedding.shape}")

    # Initialize local FAISS manager for testing
    dim = embedding.shape[0]
    faiss_mgr = FAISSIndexManager(dimension=dim)

    # Seed Positive Library (Ghost nets, drums, tires, containers)
    dummy_pos_crop = np.full((64, 64), 200, dtype=np.uint8)
    pos_vec_1 = embed_roi(dummy_pos_crop, target_physics_vec)
    faiss_mgr.add_positive(pos_vec_1, metadata={"category": "container"})

    # Seed Negative Library (Rocks, ripples, seabed clutter)
    dummy_neg_crop = np.full((64, 64), 50, dtype=np.uint8)
    neg_vec_1 = embed_roi(dummy_neg_crop, clutter_physics_vec)
    faiss_mgr.add_negative(neg_vec_1, metadata={"category": "rock"})

    print(f"   -> FAISS Positive Index Count: {faiss_mgr.positive_index.ntotal}")
    print(f"   -> FAISS Negative Index Count: {faiss_mgr.negative_index.ntotal}")

    # Save indices test
    faiss_mgr.save_indices("test_pos.faiss", "test_neg.faiss")
    print("   -> FAISS indices successfully saved to disk.")

    # -------------------------------------------------------------
    # 4. Step 5: Retrieval-Based Confidence Scoring
    # -------------------------------------------------------------
    print("\n[Step 5] Running score_confidence() against FAISS indices...")
    score_result = score_confidence(
        embedding=embedding,
        index_manager=faiss_mgr,
        physics_vec=target_physics_vec,
        weights=(0.5, 0.3, 0.4),
        confidence_threshold=0.30
    )

    print(f"   -> Accepted Candidate? {score_result['accepted']}")
    print(f"   -> Final Confidence Score: {score_result['confidence']:.4f}")
    print(f"   -> Sim Target (Pos): {score_result['sim_pos']:.4f}")
    print(f"   -> Sim Clutter (Neg): {score_result['sim_neg']:.4f}")
    print(f"   -> Geometry Consistency: {score_result['geometry_consistency']:.4f}")

    # -------------------------------------------------------------
    # 5. Step 6: Live Learning API Endpoint (POST /api/v1/targets/feedback)
    # -------------------------------------------------------------
    print("\n[Step 6] Testing FastAPI Multipart File Upload Feedback Endpoint (without physics_vec parameter)...")
    client = TestClient(app)

    # Encode crop to JPEG bytes
    _, img_bytes = cv2.imencode(".jpg", crop_img)

    # Test 1: With target_category provided
    response1 = client.post(
        "/api/v1/targets/feedback",
        files={"file": ("roi_crop.jpg", img_bytes.tobytes(), "image/jpeg")},
        data={
            "label": "positive",
            "target_category": "ghost_net"
        }
    )

    assert response1.status_code == 201
    assert response1.json()["status"] == "success"
    assert response1.json()["target_category"] == "ghost_net"
    print(f"   -> Test 1 (with category) Payload: {response1.json()}")

    # Test 2: With target_category omitted completely
    response2 = client.post(
        "/api/v1/targets/feedback",
        files={"file": ("roi_crop.jpg", img_bytes.tobytes(), "image/jpeg")},
        data={
            "label": "negative"
        }
    )

    assert response2.status_code == 201
    assert response2.json()["status"] == "success"
    assert response2.json()["target_category"] is None
    print(f"   -> Test 2 (category omitted) Payload: {response2.json()}")

    print("\n" + "=" * 65)
    print("       AquaIntel Part 2 Pipeline Execution SUCCESS!       ")
    print("=" * 65)


if __name__ == "__main__":
    run_demo()
