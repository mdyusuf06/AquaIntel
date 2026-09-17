# -*- coding: utf-8 -*-
"""
AquaIntel - FAISS Database Seeder
===================================
Seeds positive/negative FAISS vector indices using:
  1. training_data/positives/* (ghost nets, tires)
  2. training_data/negatives/* (sand ripples, rocks)
  3. sonar_pipeline/dataset_sample (Roboflow sonar_detect dataset)
     - aircraft / shipwreck / fish -> positive
     - other -> negative

Run once before starting the server:
    python seed_database.py
"""
import cv2
import numpy as np
from pathlib import Path
from embedding import FAISSIndexManager, embed_roi
from physics_extractor import extract_physics_vector

EMBEDDING_DIM = 581  # 576 MobileNet + 5 Physics
index_manager = FAISSIndexManager(dimension=EMBEDDING_DIM)

DATASET_DIR = Path("sonar_pipeline/dataset_sample")
CLASS_NAMES = [
    "aircraft", "fish", "other", "shipwreck", 
    "ghost net", "fishing net", "boat wreck", "hull wreck", 
    "shipping container", "chemical drum", "tire", 
    "cabling", "generic metallic debris", "natural rock", "reef"
]
DATASET_CLASS_MAP = {
    "aircraft": "positive",
    "shipwreck": "positive",
    "fish": "positive",
    "ghost net": "positive",
    "fishing net": "positive",
    "boat wreck": "positive",
    "hull wreck": "positive",
    "shipping container": "positive",
    "chemical drum": "positive",
    "tire": "positive",
    "cabling": "positive",
    "generic metallic debris": "positive",
    "natural rock": "negative",
    "reef": "negative",
    "other": "negative",
}


def embed_image_file(filepath):
    img = cv2.imread(str(filepath), cv2.IMREAD_GRAYSCALE)
    if img is None:
        return None, None
    physics_vec = extract_physics_vector(img)
    physics_arr = np.array(physics_vec, dtype=np.float32)
    embedding = embed_roi(img, physics_arr)
    return embedding, {"filename": str(filepath), "physics": physics_vec}


def seed_directory(folder_path, label, category):
    folder = Path(folder_path)
    if not folder.exists():
        folder.mkdir(parents=True, exist_ok=True)
        print("  Created {} - drop {} images here.".format(folder, category))
        return 0
    count = 0
    for ext in ("*.png", "*.jpg", "*.jpeg"):
        for filepath in folder.glob(ext):
            embedding, meta = embed_image_file(filepath)
            if embedding is None:
                continue
            meta["category"] = category
            if label == "positive":
                index_manager.add_positive(embedding, metadata=meta)
            else:
                index_manager.add_negative(embedding, metadata=meta)
            count += 1
    if count:
        print("  [{}] {} samples from {}".format(label.upper(), count, folder))
    return count


def seed_from_roboflow_dataset(split="train"):
    images_dir = DATASET_DIR / split / "images"
    labels_dir = DATASET_DIR / split / "labels"
    if not images_dir.exists():
        print("  Dataset split not found:", images_dir)
        return 0
    count = 0
    for img_path in images_dir.glob("*.jpg"):
        label_path = labels_dir / img_path.with_suffix(".txt").name
        if not label_path.exists():
            continue
        lines = label_path.read_text().strip().splitlines()
        if not lines:
            continue
        class_id = int(lines[0].split()[0])
        class_name = CLASS_NAMES[class_id] if class_id < len(CLASS_NAMES) else "other"
        label = DATASET_CLASS_MAP.get(class_name, "negative")
        embedding, meta = embed_image_file(img_path)
        if embedding is None:
            continue
        meta["category"] = class_name
        meta["split"] = split
        if label == "positive":
            index_manager.add_positive(embedding, metadata=meta)
        else:
            index_manager.add_negative(embedding, metadata=meta)
        count += 1
    print("  [DATASET/{}] {} samples seeded".format(split.upper(), count))
    return count


print("=" * 60)
print("AquaIntel FAISS Database Seeding")
print("=" * 60)

print("\n[1/3] Seeding from training_data/...")
seed_directory("training_data/positives/ghost_nets", "positive", "ghost_net")
seed_directory("training_data/positives/tires",      "positive", "tire")
seed_directory("training_data/negatives/sand_ripples","negative", "ripple")
seed_directory("training_data/negatives/rocks",       "negative", "rock")

print("\n[2/3] Seeding from Roboflow dataset (train)...")
seed_from_roboflow_dataset("train")

print("\n[3/3] Seeding from Roboflow dataset (valid)...")
seed_from_roboflow_dataset("valid")

print("\n" + "=" * 60)
print("Total positive vectors:", index_manager.positive_index.ntotal)
print("Total negative vectors:", index_manager.negative_index.ntotal)
print("Embedding dimension:", EMBEDDING_DIM)

index_manager.save_indices("pos_index.faiss", "neg_index.faiss")
print("\nSaved pos_index.faiss & neg_index.faiss")
print("Seeding complete!")
