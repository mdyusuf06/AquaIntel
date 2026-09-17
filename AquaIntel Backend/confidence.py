"""
AquaIntel - Step 5: Retrieval-Based Confidence Scoring Engine
============================================================
Computes candidate anomaly confidence scores via k-nearest neighbor (k-NN)
search against target (positive) and clutter (negative) FAISS libraries combined
with physics geometry consistency metrics.
"""

from typing import Dict, Any, Tuple, Optional
import numpy as np
import faiss
from embedding import FAISSIndexManager


def l2_distance_to_similarity(distance: float, sigma: float = 1.0) -> float:
    """
    Convert FAISS L2 squared distance to similarity score in range (0, 1].
    Uses radial basis function (RBF) conversion: exp(-distance / (2 * sigma^2)).
    """
    return float(np.exp(-distance / (2.0 * (sigma ** 2))))


def compute_geometry_consistency(physics_vec: np.ndarray) -> float:
    """
    Evaluate physics geometry consistency score in [0, 1] from Part 1 physics vector.

    physics_vec expected fields:
    [height, shadow_area, highlight_to_shadow_ratio, axis_orientation, haralick_texture]

    Rules:
    - Target objects (ghost nets, tires, drums) have non-zero height & shadow area.
    - Highlight-to-shadow ratio typically ranges between 0.1 and 5.0 for real structures.
    - Haralick texture high variance indicates non-smooth, artificial structures.
    """
    if len(physics_vec) < 5:
        return 0.5  # Neutral fallback if vector is short

    height = physics_vec[0]
    shadow_area = physics_vec[1]
    hs_ratio = physics_vec[2]
    haralick_texture = physics_vec[4]

    score = 1.0

    # Sanity check height (> 0.05m)
    if height < 0.05:
        score -= 0.3

    # Sanity check shadow area (> 1.0 sq meters / pixels)
    if shadow_area < 0.1:
        score -= 0.3

    # Highlight-to-shadow ratio range check
    if hs_ratio < 0.05 or hs_ratio > 10.0:
        score -= 0.2

    # High acoustic texture/contrast boost
    if haralick_texture > 0.2:
        score += 0.1

    return float(np.clip(score, 0.0, 1.0))


def score_confidence(
    embedding: np.ndarray,
    index_manager: FAISSIndexManager,
    physics_vec: Optional[np.ndarray] = None,
    k: int = 3,
    weights: Tuple[float, float, float] = (0.5, 0.3, 0.4),
    confidence_threshold: float = 0.35,
    max_neg_similarity_threshold: float = 0.75
) -> Dict[str, Any]:
    """
    Function score_confidence(embedding) computing top-k NN search against both indices:

    confidence = w1 * sim_pos + w2 * geometry_consistency - w3 * sim_neg_clutter

    Reject candidates below threshold or matching negative library strongly.

    Parameters
    ----------
    embedding : np.ndarray
        Single unified feature vector float32 array (D,).
    index_manager : FAISSIndexManager
        Contains positive_index and negative_index.
    physics_vec : Optional[np.ndarray]
        Raw 5-element physics vector for geometry consistency. If None, sliced from embedding.
    k : int
        Number of nearest neighbors to query.
    weights : Tuple[float, float, float]
        (w1, w2, w3) weight coefficients.
    confidence_threshold : float
        Minimum final confidence score to accept candidate.
    max_neg_similarity_threshold : float
        Maximum allowable negative clutter similarity before automatic rejection.

    Returns
    -------
    Dict[str, Any]
        Dictionary containing decision, final score, and detailed components.
    """
    w1, w2, w3 = weights
    vec_query = np.atleast_2d(embedding).astype(np.float32)

    # 1. Query Positive Index
    sim_pos = 0.0
    if index_manager.positive_index.ntotal > 0:
        k_pos = min(k, index_manager.positive_index.ntotal)
        dist_pos, _ = index_manager.positive_index.search(vec_query, k_pos)
        avg_dist_pos = np.mean(dist_pos[0])
        sim_pos = l2_distance_to_similarity(avg_dist_pos)

    # 2. Query Negative Index
    sim_neg = 0.0
    if index_manager.negative_index.ntotal > 0:
        k_neg = min(k, index_manager.negative_index.ntotal)
        dist_neg, _ = index_manager.negative_index.search(vec_query, k_neg)
        avg_dist_neg = np.mean(dist_neg[0])
        sim_neg = l2_distance_to_similarity(avg_dist_neg)

    # 3. Compute Geometry Consistency
    if physics_vec is None:
        # Extract physics tail from unified embedding if present (last 5 elements)
        physics_vec = embedding[-5:]
    geom_consistency = compute_geometry_consistency(physics_vec)

    # 4. Formula: confidence = w1*sim_pos + w2*geometry_consistency - w3*sim_neg_clutter
    raw_confidence = (w1 * sim_pos) + (w2 * geom_consistency) - (w3 * sim_neg)
    confidence = float(np.clip(raw_confidence, 0.0, 1.0))

    # 5. Rejection Rules
    rejection_reasons = []
    accepted = True

    if sim_neg >= max_neg_similarity_threshold:
        accepted = False
        rejection_reasons.append(
            f"Strong negative clutter match (sim_neg={sim_neg:.3f} >= threshold {max_neg_similarity_threshold})"
        )

    if confidence < confidence_threshold:
        accepted = False
        rejection_reasons.append(
            f"Confidence score ({confidence:.3f}) below acceptance threshold ({confidence_threshold})"
        )

    return {
        "accepted": accepted,
        "confidence": confidence,
        "sim_pos": float(sim_pos),
        "sim_neg": float(sim_neg),
        "geometry_consistency": float(geom_consistency),
        "rejection_reasons": rejection_reasons
    }
