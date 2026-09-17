"""
AquaIntel Sonar Pipeline — Physics Feature Engine (Step 2)
Problem Statement 26057 | Team Brainwave | SIH 2026

Calculates true physical dimensions and acoustic properties of underwater anomalies:
1. Detects highlight-shadow pairs along acoustic range lines.
2. Computes true object height using the side-scan acoustic shadow equation:
     Height = H_tow * (L_shadow / R)
3. Extracts auxiliary geometric descriptors (shadow area, highlight-to-shadow ratio, orientation).
4. Computes Haralick texture features via scikit-image GLCM (Gray-Level Co-occurrence Matrix).
5. Emits strongly typed SonarObjectFeature records for downstream vector retrieval.
"""

from __future__ import annotations
import logging
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
# Texture feature justification:
# We select `skimage.feature.graycomatrix` and `skimage.feature.graycoprops` over `mahotas`
# because skimage is natively pure Python/NumPy vectorized with zero C-compiler dependency
# issues on edge embedded platforms (NVIDIA Jetson, Windows, Linux), provides thread-safe
# execution, supports flexible multi-distance/multi-angle GLCMs, and is actively maintained.
from skimage.feature import graycomatrix, graycoprops

from sonar_pipeline.schemas import (
    HaralickFeatures,
    PipelineConfig,
    SonarFrame,
    SonarObjectFeature,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Acoustic Shadow Physics
# ---------------------------------------------------------------------------

def compute_acoustic_shadow_height(
    h_tow_m: float,
    shadow_length_m: float,
    slant_range_m: float,
) -> float:
    """
    Computes true physical object height above the seabed using the fundamental
    side-scan sonar acoustic shadow geometry equation.
    
    Equation:
        Height = H_tow * (L_shadow / R)
        
    Geometric Derivation:
        Similar triangles formed by the towfish altitude H_tow, slant range R to the target,
        and acoustic shadow length L_shadow cast on the flat seafloor.
        
    Units:
        - h_tow_m: meters (sensor altitude above seafloor)
        - shadow_length_m: meters (acoustic shadow extent along range ray)
        - slant_range_m: meters (distance from sonar to object highlight)
        - Return value: meters (object vertical height above seafloor)
        
    Args:
        h_tow_m: Towfish altitude in meters (> 0).
        shadow_length_m: Measured acoustic shadow length in meters (>= 0).
        slant_range_m: Slant range from sonar nadir to target in meters (> 0).
        
    Returns:
        Computed vertical height in meters.
    """
    if h_tow_m <= 0.0:
        raise ValueError(f"Tow altitude H_tow must be positive, got {h_tow_m} m")
    if slant_range_m <= 0.0:
        raise ValueError(f"Slant range R must be positive, got {slant_range_m} m")
    if shadow_length_m < 0.0:
        raise ValueError(f"Shadow length L_shadow cannot be negative, got {shadow_length_m} m")

    height_m = h_tow_m * (shadow_length_m / slant_range_m)
    return float(height_m)


# ---------------------------------------------------------------------------
# Texture & Morphology Descriptors
# ---------------------------------------------------------------------------

def compute_haralick_texture(
    patch: np.ndarray,
    num_levels: int = 16,
) -> HaralickFeatures:
    r"""
    Computes Gray-Level Co-occurrence Matrix (GLCM) Haralick texture descriptors
    over an acoustic highlight/shadow patch.
    
    Metrics:
        - Contrast: \sum |i - j|^2 P_{i,j}
        - Dissimilarity: \sum |i - j| P_{i,j}
        - Homogeneity: \sum \frac{P_{i,j}}{1 + (i - j)^2}
        - Energy: \sqrt{ASM}
        - Correlation: Linear gray-level dependency
        - ASM (Angular Second Moment): \sum P_{i,j}^2
        
    Units:
        - patch: 2D numpy array [height_px, width_px] (float32 or uint8)
        - Return fields: dimensionless texture metrics
        
    Args:
        patch: 2D image ROI crop containing object highlight and shadow.
        num_levels: Gray-level quantization bins (default 16 for robust statistics).
        
    Returns:
        HaralickFeatures model.
    """
    if patch.size == 0 or patch.shape[0] < 2 or patch.shape[1] < 2:
        return HaralickFeatures(
            contrast=0.0,
            dissimilarity=0.0,
            homogeneity=1.0,
            energy=1.0,
            correlation=1.0,
            asm=1.0,
        )

    # Normalize patch to [0, num_levels - 1] uint8
    min_val, max_val = float(np.min(patch)), float(np.max(patch))
    if max_val - min_val > 1e-4:
        norm_patch = ((patch - min_val) / (max_val - min_val) * (num_levels - 1)).astype(np.uint8)
    else:
        norm_patch = np.zeros(patch.shape, dtype=np.uint8)

    # Compute GLCM over 4 standard directions [0, 45, 90, 135 deg] at distance 1
    glcm = graycomatrix(
        norm_patch,
        distances=[1],
        angles=[0, np.pi / 4, np.pi / 2, 3 * np.pi / 4],
        levels=num_levels,
        symmetric=True,
        normed=True,
    )

    contrast_val = float(np.mean(graycoprops(glcm, "contrast")))
    dissimilarity_val = float(np.mean(graycoprops(glcm, "dissimilarity")))
    homogeneity_val = float(np.mean(graycoprops(glcm, "homogeneity")))
    energy_val = float(np.mean(graycoprops(glcm, "energy")))
    correlation_val = float(np.mean(graycoprops(glcm, "correlation")))
    asm_val = float(np.mean(graycoprops(glcm, "ASM")))

    # Handle NaN correlations (e.g. uniform patch)
    if np.isnan(correlation_val):
        correlation_val = 1.0

    return HaralickFeatures(
        contrast=round(contrast_val, 4),
        dissimilarity=round(dissimilarity_val, 4),
        homogeneity=round(homogeneity_val, 4),
        energy=round(energy_val, 4),
        correlation=round(correlation_val, 4),
        asm=round(asm_val, 4),
    )


def compute_principal_axis_orientation(mask: np.ndarray) -> float:
    r"""
    Computes principal orientation angle (in degrees) of a binary object mask
    using second-order central image moments.
    
    Mathematical Formulation:
        \theta = 0.5 * \arctan2(2 * \mu_{11}, \mu_{20} - \mu_{02})
        
    Units:
        - mask: 2D binary numpy array [height_px, width_px]
        - Return value: degrees in [0.0, 180.0) relative to range (horizontal) axis
        
    Args:
        mask: 2D boolean or uint8 mask of the target.
        
    Returns:
        Orientation angle in degrees.
    """
    mask_u8 = mask.astype(np.uint8)
    moments = cv2.moments(mask_u8)
    
    mu20 = moments["mu20"]
    mu02 = moments["mu02"]
    mu11 = moments["mu11"]

    if abs(mu20 - mu02) < 1e-5 and abs(mu11) < 1e-5:
        return 0.0

    theta_rad = 0.5 * np.arctan2(2.0 * mu11, mu20 - mu02)
    theta_deg = float(np.degrees(theta_rad)) % 180.0
    return round(theta_deg, 2)


# ---------------------------------------------------------------------------
# Highlight-Shadow Pair Extraction & Physical Feature Engine
# ---------------------------------------------------------------------------

def extract_physics_features(
    frame: SonarFrame,
    config: Optional[PipelineConfig] = None,
) -> List[SonarObjectFeature]:
    """
    Performs physics-based highlight-shadow detection, geometric measurement,
    and texture characterization on the preprocessed sonar frame.
    
    Pipeline Steps:
      1. Acoustic segmentation into Highlight candidates and Shadow candidates.
         [EXTENSION POINT]: Modular hook for deep learning (e.g. U-Net) segmentation.
      2. Highlight-to-shadow acoustic range pairing.
      3. Geometry & height calculation: Height = H_tow * (L_shadow / R).
      4. Auxiliary descriptor generation (areas, ratios, principal axis, GLCM Haralick).
      5. Georeferenced coordinate transformation.
      
    Units:
        - Coordinates: pixels (bbox_px, center_px), meters/degrees (center_geo)
        - Height, Slant range, Shadow length: meters
        - Areas: square meters (m^2)
        - Orientation: degrees [0.0, 180.0)
        
    Args:
        frame: Preprocessed SonarFrame.
        config: PipelineConfig parameters.
        
    Returns:
        List of SonarObjectFeature records.
    """
    cfg = config or PipelineConfig()
    intensity = frame.intensity
    valid_mask = frame.valid_mask
    meta = frame.metadata
    
    res_m = float(meta.target_resolution_m_per_px)
    h_tow_m = float(meta.h_tow_m)
    num_rows, num_cols = intensity.shape
    
    if num_rows == 0 or num_cols == 0:
        return []

    # Center column corresponds to sonar nadir trackline
    nadir_col = num_cols / 2.0

    # -----------------------------------------------------------------------
    # [EXTENSION POINT]: Deep Learning / U-Net Segmentation Slot
    # In future stages of AquaIntel, a trained U-Net semantic segmentation network
    # can directly supply high-precision highlight and shadow probability masks here.
    # Below is the robust physics-based adaptive percentile baseline segmentation.
    # -----------------------------------------------------------------------
    valid_pixels = intensity[valid_mask]
    if len(valid_pixels) == 0:
        return []

    p_shadow = float(np.percentile(valid_pixels, cfg.shadow_thresh_percentile))
    p_high = float(np.percentile(valid_pixels, cfg.highlight_thresh_percentile))
    bg_median = float(np.median(valid_pixels))
    bg_std = float(np.std(valid_pixels))

    # Adaptive threshold fallback when background is nearly uniform
    if abs(p_high - p_shadow) < 5.0 or p_shadow >= bg_median:
        shadow_thresh = bg_median - max(10.0, 1.5 * bg_std)
        highlight_thresh = bg_median + max(15.0, 1.5 * bg_std)
    else:
        shadow_thresh = p_shadow
        highlight_thresh = p_high

    # Binary masks (masked with valid survey area)
    shadow_mask = (intensity <= shadow_thresh) & valid_mask
    highlight_mask = (intensity >= highlight_thresh) & valid_mask

    # Find connected components for shadows and highlights
    num_shadow_labels, shadow_labels, shadow_stats, shadow_centroids = cv2.connectedComponentsWithStats(
        shadow_mask.astype(np.uint8), connectivity=8
    )
    num_high_labels, high_labels, high_stats, high_centroids = cv2.connectedComponentsWithStats(
        highlight_mask.astype(np.uint8), connectivity=8
    )

    detected_features: List[SonarObjectFeature] = []
    object_counter = 0

    # Minimum pixel counts from config
    min_shadow_px = cfg.min_shadow_area_px
    min_high_px = cfg.min_highlight_area_px

    # Iterate over shadow candidates
    for s_idx in range(1, num_shadow_labels):
        s_area_px = int(shadow_stats[s_idx, cv2.CC_STAT_AREA])
        if s_area_px < min_shadow_px:
            continue

        s_left = int(shadow_stats[s_idx, cv2.CC_STAT_LEFT])
        s_top = int(shadow_stats[s_idx, cv2.CC_STAT_TOP])
        s_width = int(shadow_stats[s_idx, cv2.CC_STAT_WIDTH])
        s_height = int(shadow_stats[s_idx, cv2.CC_STAT_HEIGHT])
        s_cx, s_cy = shadow_centroids[s_idx]

        # Determine acoustic propagation direction relative to nadir:
        # Starboard side (s_cx >= nadir_col): Sound travels right (+X). Highlight is to the LEFT of shadow.
        # Port side (s_cx < nadir_col): Sound travels left (-X). Highlight is to the RIGHT of shadow.
        is_starboard = s_cx >= nadir_col

        best_high_idx = -1
        best_high_dist = float("inf")

        # Search for matching highlight in proximal range direction within vertical row overlap
        y_min_search = max(0, s_top - 5)
        y_max_search = min(num_rows, s_top + s_height + 5)

        for h_idx in range(1, num_high_labels):
            h_area_px = int(high_stats[h_idx, cv2.CC_STAT_AREA])
            if h_area_px < min_high_px:
                continue

            h_cx, h_cy = high_centroids[h_idx]

            # Check vertical alignment (along-track ping overlap)
            if not (y_min_search <= h_cy <= y_max_search):
                continue

            # Check horizontal range direction:
            # Highlight must be between nadir and shadow
            if is_starboard:
                # Starboard: Highlight is left of shadow (h_cx <= s_left + 2) and right of nadir
                if h_cx <= s_left + 5 and h_cx >= nadir_col - 5:
                    dist = abs(s_left - h_cx)
                    if dist < best_high_dist:
                        best_high_dist = dist
                        best_high_idx = h_idx
            else:
                # Port: Highlight is right of shadow (h_cx >= s_left + s_width - 5) and left of nadir
                if h_cx >= (s_left + s_width - 5) and h_cx <= nadir_col + 5:
                    dist = abs(h_cx - (s_left + s_width))
                    if dist < best_high_dist:
                        best_high_dist = dist
                        best_high_idx = h_idx

        # If a valid highlight-shadow pair is confirmed
        if best_high_idx != -1:
            h_left = int(high_stats[best_high_idx, cv2.CC_STAT_LEFT])
            h_top = int(high_stats[best_high_idx, cv2.CC_STAT_TOP])
            h_width = int(high_stats[best_high_idx, cv2.CC_STAT_WIDTH])
            h_height = int(high_stats[best_high_idx, cv2.CC_STAT_HEIGHT])
            h_area_px = int(high_stats[best_high_idx, cv2.CC_STAT_AREA])
            h_cx, h_cy = high_centroids[best_high_idx]

            # Combined bounding box
            bbox_xmin = min(s_left, h_left)
            bbox_ymin = min(s_top, h_top)
            bbox_xmax = max(s_left + s_width, h_left + h_width)
            bbox_ymax = max(s_top + s_height, h_top + h_height)

            obj_center_x = (h_cx + s_cx) / 2.0
            obj_center_y = (h_cy + s_cy) / 2.0

            # ---------------------------------------------------------------
            # Acoustic Physics Calculations
            # ---------------------------------------------------------------
            # Slant range R: physical distance from nadir to the highlight/object tip
            slant_range_px = abs(h_cx - nadir_col)
            slant_range_m = max(1.0, slant_range_px * res_m)

            # Shadow length L_shadow: cross-track extent of shadow along range ray
            shadow_length_px = float(s_width)
            shadow_length_m = shadow_length_px * res_m

            # Physical Height = H_tow * (L_shadow / R)
            computed_height_m = compute_acoustic_shadow_height(
                h_tow_m=h_tow_m,
                shadow_length_m=shadow_length_m,
                slant_range_m=slant_range_m,
            )

            # Areas in square meters
            shadow_area_m2 = round(s_area_px * (res_m ** 2), 4)
            highlight_area_m2 = round(h_area_px * (res_m ** 2), 4)
            high_to_shadow_ratio = round(highlight_area_m2 / max(1e-4, shadow_area_m2), 4)

            # Extract combined ROI mask for orientation & texture
            pair_mask = ((shadow_labels == s_idx) | (high_labels == best_high_idx))[
                bbox_ymin : bbox_ymax + 1, bbox_xmin : bbox_xmax + 1
            ]
            orientation_deg = compute_principal_axis_orientation(pair_mask)

            # Crop patch for Haralick texture analysis
            patch = intensity[bbox_ymin : bbox_ymax + 1, bbox_xmin : bbox_xmax + 1]
            haralick = compute_haralick_texture(patch)

            # Compute Georeferenced Coordinates
            tf = meta.transform_matrix or [res_m, 0.0, meta.origin_lon, 0.0, -res_m, meta.origin_lat]
            geo_x = tf[0] * obj_center_x + tf[1] * obj_center_y + tf[2]
            geo_y = tf[3] * obj_center_x + tf[4] * obj_center_y + tf[5]

            # Physical validity check: Height cannot exceed tow altitude
            is_valid_physics = bool((0.01 <= computed_height_m <= h_tow_m * 1.5) and (slant_range_m >= 1.0))
            
            # Confidence estimation based on alignment and contrast
            contrast_score = min(1.0, abs(highlight_thresh - shadow_thresh) / 100.0)
            alignment_score = max(0.2, 1.0 - (best_high_dist / max(1.0, shadow_length_px)))
            confidence = round(float(np.clip(0.5 * contrast_score + 0.5 * alignment_score, 0.1, 0.99)), 3)

            object_counter += 1
            feature_record = SonarObjectFeature(
                object_id=f"sonar_obj_{object_counter:03d}",
                bbox_px=(bbox_xmin, bbox_ymin, bbox_xmax, bbox_ymax),
                center_px=(round(obj_center_x, 2), round(obj_center_y, 2)),
                center_geo=(round(geo_x, 6), round(geo_y, 6)),
                slant_range_m=round(slant_range_m, 3),
                shadow_length_m=round(shadow_length_m, 3),
                computed_height_m=round(computed_height_m, 3),
                shadow_area_m2=shadow_area_m2,
                highlight_area_m2=highlight_area_m2,
                highlight_to_shadow_ratio=high_to_shadow_ratio,
                principal_axis_orientation_deg=orientation_deg,
                haralick_features=haralick,
                confidence=confidence,
                is_valid_physics=is_valid_physics,
                notes="Physics-derived highlight-shadow pair",
            )
            detected_features.append(feature_record)

    logger.info(f"Physics feature extraction completed: {len(detected_features)} object features extracted.")
    return detected_features
