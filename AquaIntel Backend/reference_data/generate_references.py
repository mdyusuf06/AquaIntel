"""
Generate synthetic sonar reference crops for each debris class.
Each class has a distinct geometric shadow/highlight signature matching
known sonar physics for that object type, then run through the SAME
extract_physics_vector -> embed_roi pipeline used at inference.

Run from the AquaIntel Backend root:
    python reference_data/generate_references.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import cv2
import numpy as np
from pathlib import Path
from embedding import FAISSIndexManager, embed_roi
from physics_extractor import extract_physics_vector

EMBEDDING_DIM = 581
REF_DIR = Path(__file__).parent
FAISS_POS = str(REF_DIR.parent / "pos_index.faiss")
FAISS_NEG = str(REF_DIR.parent / "neg_index.faiss")
SIZE = 128


def make_canvas():
    """Dark background (sonar water column = 20-40 intensity)."""
    return np.full((SIZE, SIZE), 25, dtype=np.uint8)


def add_gaussian_noise(img, sigma=6):
    noise = np.random.normal(0, sigma, img.shape).astype(np.int16)
    return np.clip(img.astype(np.int16) + noise, 0, 255).astype(np.uint8)


# ─── Class shape generators ──────────────────────────────────────────────────

def make_ghost_net(variant=0):
    """Long thin diagonal mesh: elongated highlight band + diffuse shadow."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    angle = 30 + variant * 25  # degrees
    rad = np.radians(angle)
    length = 80 - variant * 10
    # highlight strand
    for t in np.linspace(-length // 2, length // 2, 60):
        x = int(cx + t * np.cos(rad))
        y = int(cy + t * np.sin(rad))
        if 0 <= x < SIZE and 0 <= y < SIZE:
            img[y, x] = min(255, img[y, x] + 180)
    # diffuse shadow offset
    shadow_offset = 12
    for t in np.linspace(-length // 2, length // 2, 40):
        x = int(cx + t * np.cos(rad) + shadow_offset)
        y = int(cy + t * np.sin(rad) + shadow_offset)
        if 0 <= x < SIZE and 0 <= y < SIZE:
            img[y, x] = max(0, img[y, x] - 15)
    img = cv2.GaussianBlur(img, (5, 5), 1.5)
    return add_gaussian_noise(img)


def make_boat_wreck(variant=0):
    """Large asymmetric hull: bright elongated ellipse + wide shadow trailing edge."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    a, b = 38 - variant * 3, 16 - variant * 2
    cv2.ellipse(img, (cx, cy), (a, b), 20 * variant, 0, 360, 200, -1)
    # shadow rectangle to the right/bottom
    shadow_rect = np.array([[cx + 10, cy - 5], [cx + a + 25, cy - 5],
                             [cx + a + 25, cy + b + 10], [cx + 10, cy + b + 10]])
    cv2.fillPoly(img, [shadow_rect], 10)
    img = cv2.GaussianBlur(img, (7, 7), 2)
    return add_gaussian_noise(img)


def make_plane_debris(variant=0):
    """Cross/T-shape fuselage + wings — distinctive aircraft sonar signature."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    # Fuselage (long horizontal bar)
    fw = 55 - variant * 5
    fh = 10 + variant * 2
    cv2.rectangle(img, (cx - fw // 2, cy - fh // 2), (cx + fw // 2, cy + fh // 2), 210, -1)
    # Wings (vertical bar crossing fuselage)
    ww = 12 + variant * 2
    wh = 50 - variant * 5
    cv2.rectangle(img, (cx - ww // 2, cy - wh // 2), (cx + ww // 2, cy + wh // 2), 190, -1)
    # Shadow trailing behind fuselage
    shadow_x = cx + fw // 2
    cv2.rectangle(img, (shadow_x, cy - 6), (shadow_x + 20 + variant * 3, cy + 6), 8, -1)
    img = cv2.GaussianBlur(img, (5, 5), 1.8)
    return add_gaussian_noise(img)


def make_aircraft_wreckage(variant=0):
    """Broken/scattered cross + debris field — degraded plane signature."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    # Broken fuselage segment
    fw = 40 - variant * 4
    cv2.rectangle(img, (cx - fw // 2, cy - 7), (cx + fw // 2, cy + 7), 200, -1)
    # Detached wing fragment (rotated)
    angle = 15 + variant * 20
    rad = np.radians(angle)
    wl = 30 + variant * 5
    for t in np.linspace(-wl // 2, wl // 2, 30):
        wx = int(cx - 10 + t * np.cos(rad))
        wy = int(cy + 20 + t * np.sin(rad))
        if 0 <= wx < SIZE and 0 <= wy < SIZE:
            img[wy, wx] = 195
    # Scattered debris dots
    np.random.seed(42 + variant)
    for _ in range(8 + variant * 3):
        dx = np.random.randint(-35, 35)
        dy = np.random.randint(-35, 35)
        r = np.random.randint(2, 5)
        cv2.circle(img, (cx + dx, cy + dy), r, 160, -1)
    # Shadow
    cv2.rectangle(img, (cx + fw // 2, cy - 5), (cx + fw // 2 + 18, cy + 5), 8, -1)
    img = cv2.GaussianBlur(img, (5, 5), 1.5)
    return add_gaussian_noise(img)


def make_chemical_drum(variant=0):
    """Compact circular/cylindrical bright spot + sharp rectangular shadow."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    r = 18 - variant * 2
    cv2.circle(img, (cx, cy), r, 220, -1)
    # Highlight ring (high specular return of metal drum)
    cv2.circle(img, (cx, cy), r, 240, 2)
    # Sharp rectangular shadow
    cv2.rectangle(img, (cx + r, cy - r // 2), (cx + r + 25 + variant * 3, cy + r // 2), 5, -1)
    img = cv2.GaussianBlur(img, (3, 3), 1)
    return add_gaussian_noise(img, sigma=4)


def make_tire(variant=0):
    """Doughnut/annulus shape: bright ring, dark centre, moderate shadow."""
    img = make_canvas()
    cx, cy = SIZE // 2, SIZE // 2
    outer_r = 22 - variant * 2
    inner_r = 12 - variant
    cv2.circle(img, (cx, cy), outer_r, 185, -1)
    cv2.circle(img, (cx, cy), inner_r, 15, -1)   # hollow centre
    # Shadow
    shadow_len = 18 + variant * 4
    cv2.ellipse(img, (cx + outer_r + shadow_len // 2, cy), (shadow_len // 2, outer_r // 2),
                0, 0, 360, 8, -1)
    img = cv2.GaussianBlur(img, (5, 5), 1.5)
    return add_gaussian_noise(img)


def make_cable(variant=0):
    """Sinusoidal thin bright line: cable lying on seabed."""
    img = make_canvas()
    freq = 0.06 + variant * 0.015
    amp = 14 + variant * 4
    x_start = 10
    x_end = SIZE - 10
    prev = None
    for x in range(x_start, x_end):
        y = int(SIZE // 2 + amp * np.sin(freq * x + variant * 1.2))
        if 0 <= y < SIZE:
            if prev:
                cv2.line(img, prev, (x, y), 175, 2)
            prev = (x, y)
    # thin shadow offset
    prev = None
    for x in range(x_start, x_end):
        y = int(SIZE // 2 + amp * np.sin(freq * x + variant * 1.2) + 5)
        if 0 <= y < SIZE:
            if prev:
                cv2.line(img, prev, (x, y), 12, 1)
            prev = (x, y)
    img = cv2.GaussianBlur(img, (3, 3), 1)
    return add_gaussian_noise(img)


def make_rock_clutter(variant=0):
    """Irregular bright blobs + natural soft shadow — negative class."""
    img = make_canvas()
    np.random.seed(10 + variant)
    num_rocks = 3 + variant
    for _ in range(num_rocks):
        rx = np.random.randint(25, SIZE - 25)
        ry = np.random.randint(25, SIZE - 25)
        ra = np.random.randint(8, 18)
        rb = np.random.randint(6, 14)
        angle = np.random.randint(0, 180)
        intensity = np.random.randint(120, 165)
        cv2.ellipse(img, (rx, ry), (ra, rb), angle, 0, 360, intensity, -1)
        # soft shadow
        cv2.ellipse(img, (rx + ra // 2, ry + rb // 2), (ra, rb // 2), angle, 0, 360, 12, -1)
    img = cv2.GaussianBlur(img, (9, 9), 3)
    return add_gaussian_noise(img, sigma=8)


def make_reef_ripple(variant=0):
    """Horizontal ripple pattern — another negative class texture."""
    img = make_canvas()
    for row in range(0, SIZE, 8 + variant * 2):
        intensity = 60 + 30 * np.sin(row * 0.3 + variant)
        img[row:row + 3, :] = int(intensity)
    img = cv2.GaussianBlur(img, (5, 5), 2)
    return add_gaussian_noise(img, sigma=5)


# ─── Main seeding logic ───────────────────────────────────────────────────────

CLASS_GENERATORS = {
    "Ghost net":          make_ghost_net,
    "Boat wreck":         make_boat_wreck,
    "Plane debris":       make_plane_debris,
    "Aircraft wreckage":  make_aircraft_wreckage,
    "Chemical drum":      make_chemical_drum,
    "Tire":               make_tire,
    "Cable":              make_cable,
}

NEGATIVE_GENERATORS = {
    "Rock / Negative":  make_rock_clutter,
    "Reef / Ripple":    make_reef_ripple,
}

VARIANTS_PER_CLASS = 7   # 7 geometric variants per class


def embed_crop(crop: np.ndarray):
    physics_vec = extract_physics_vector(crop)
    physics_arr = np.array(physics_vec, dtype=np.float32)
    return embed_roi(crop, physics_arr), physics_vec


def save_reference_crop(cls_name: str, variant: int, crop: np.ndarray):
    safe = cls_name.lower().replace(" ", "_").replace("/", "_")
    out_dir = REF_DIR / safe
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"variant_{variant:02d}.png"
    cv2.imwrite(str(path), crop)


def build_and_save_indices():
    idx = FAISSIndexManager(dimension=EMBEDDING_DIM)

    print("=" * 60)
    print("AquaIntel — Building real reference FAISS indices")
    print("=" * 60)

    # ── Positive classes ──
    for cls_name, gen_fn in CLASS_GENERATORS.items():
        count = 0
        for v in range(VARIANTS_PER_CLASS):
            crop = gen_fn(variant=v)
            save_reference_crop(cls_name, v, crop)
            emb, phys = embed_crop(crop)
            idx.add_positive(emb, metadata={"category": cls_name, "variant": v,
                                             "physics": phys})
            count += 1
        print(f"  [POSITIVE] {cls_name}: {count} embeddings")

    # ── Negative classes ──
    for cls_name, gen_fn in NEGATIVE_GENERATORS.items():
        count = 0
        for v in range(VARIANTS_PER_CLASS):
            crop = gen_fn(variant=v)
            save_reference_crop(cls_name, v, crop)
            emb, phys = embed_crop(crop)
            idx.add_negative(emb, metadata={"category": cls_name, "variant": v,
                                              "physics": phys})
            count += 1
        print(f"  [NEGATIVE] {cls_name}: {count} embeddings")

    idx.save_indices(FAISS_POS, FAISS_NEG)
    total_pos = idx.positive_index.ntotal
    total_neg = idx.negative_index.ntotal
    print(f"\nSaved  {FAISS_POS}")
    print(f"       {FAISS_NEG}")
    print(f"Total positive: {total_pos}  |  Total negative: {total_neg}")
    print("=" * 60)
    return idx


if __name__ == "__main__":
    build_and_save_indices()
    print("\nDone. Run validation:")
    print("  python reference_data/validate_embeddings.py")
