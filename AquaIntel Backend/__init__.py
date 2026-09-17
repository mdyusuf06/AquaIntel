"""
AquaIntel — Underwater Debris Detection System
Part 2: Candidate Region Proposal & Retrieval Engine

Modules
-------
roi_proposal   : Step 3 — MSER + adaptive threshold ROI extraction
embedding      : Step 4 — MobileNetV3 feature extraction + FAISS indices
confidence     : Step 5 — Top-k NN scoring against pos/neg libraries
feedback_api   : Step 6 — FastAPI live-learning feedback endpoint
"""

__version__ = "0.2.0"
__all__ = ["roi_proposal", "embedding", "confidence", "feedback_api"]
