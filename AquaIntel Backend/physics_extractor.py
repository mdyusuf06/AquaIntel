"""
AquaIntel - Physics Feature Extractor
======================================
Bridges the lightweight 5-element physics vector (used by ROI proposal flow)
with the full sonar_pipeline physics engine (GLCM Haralick, shadow geometry,
principal axis). Exported: extract_physics_vector, extract_physics_vector_from_frame.
"""

from typing import List, Any
import cv2
import numpy as np


def extract_physics_vector(crop: Any) -> List[float]:
    """
    Extract 5 sonar physical features from a grayscale ROI crop numpy array.

    Applies bilateral speckle smoothing, adaptive percentile thresholds,
    full GLCM Haralick texture (via skimage), and principal-axis orientation.

    Returns: [height, shadow_area, highlight_shadow_ratio, axis_orientation, haralick_texture]
    """
    img = np.asarray(crop) if not isinstance(crop, np.ndarray) else crop

    if img is None or img.size == 0:
        return [0.5, 10.0, 1.0, 0.0, 0.5]

    if img.dtype != np.uint8:
        img = np.clip(img * 255 if img.max() <= 1.0 else img, 0, 255).astype(np.uint8)
    if len(img.shape) == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    h_crop, w_crop = img.shape
    total_pixels = float(h_crop * w_crop)

    blur = cv2.bilateralFilter(img, d=5, sigmaColor=40, sigmaSpace=40)
    std_val = float(np.std(blur))

    highlight_thresh = float(np.percentile(blur, 85))
    shadow_thresh = float(np.percentile(blur, 15))
    highlight_pixels = float(np.sum(blur >= highlight_thresh))
    shadow_pixels = float(np.sum(blur <= shadow_thresh))

    height = float(round((h_crop / 100.0) * (highlight_pixels / max(1.0, total_pixels)), 4))
    if height <= 0:
        height = float(round(0.05 + 0.1 * (std_val / 255.0), 4))

    shadow_area = float(round(shadow_pixels / 10.0, 4))
    if shadow_area <= 0:
        shadow_area = float(round(total_pixels * 0.1, 4))

    hs_ratio = float(round(highlight_pixels / shadow_pixels, 4)) if shadow_pixels > 0 else 1.0

    moments = cv2.moments(img)
    mu20, mu02, mu11 = moments["mu20"], moments["mu02"], moments["mu11"]
    if abs(mu20 - mu02) > 1e-5 or abs(mu11) > 1e-5:
        orientation = float(round(0.5 * np.arctan2(2 * mu11, mu20 - mu02), 4))
    else:
        orientation = 0.0

    try:
        from skimage.feature import graycomatrix, graycoprops
        num_levels = 16
        mn, mx = float(img.min()), float(img.max())
        if mx - mn > 1e-4:
            norm_patch = ((img.astype(np.float32) - mn) / (mx - mn) * (num_levels - 1)).astype(np.uint8)
        else:
            norm_patch = np.zeros_like(img, dtype=np.uint8)
        if norm_patch.shape[0] >= 2 and norm_patch.shape[1] >= 2:
            glcm = graycomatrix(norm_patch, distances=[1],
                                angles=[0, 0.785, 1.571, 2.356],
                                levels=num_levels, symmetric=True, normed=True)
            haralick_texture = float(round(float(np.mean(graycoprops(glcm, "contrast"))) / (num_levels ** 2), 4))
        else:
            raise ValueError("patch too small")
    except Exception:
        gx = cv2.Sobel(img, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(img, cv2.CV_32F, 0, 1, ksize=3)
        mag, _ = cv2.cartToPolar(gx, gy)
        haralick_texture = float(round(float(np.mean(mag)) / 255.0, 4))

    return [height, shadow_area, hs_ratio, orientation, haralick_texture]


def extract_physics_vector_from_frame(frame: Any) -> List[float]:
    """
    Extract a summarized 5-element physics vector from a full SonarFrame by
    running the complete Part 1 physics engine and averaging across detections.
    Falls back to crop-level extraction if no objects are detected.
    """
    try:
        from sonar_pipeline.physics import extract_physics_features
        features = extract_physics_features(frame)
        if features:
            return [
                float(np.mean([f.computed_height_m for f in features])),
                float(np.mean([f.shadow_area_m2 for f in features])),
                float(np.mean([f.highlight_to_shadow_ratio for f in features])),
                float(np.mean([f.principal_axis_orientation_deg for f in features])),
                float(np.mean([f.haralick_features.contrast for f in features])),
            ]
    except Exception:
        pass

    arr = frame.intensity if hasattr(frame, "intensity") else np.zeros((64, 64), dtype=np.float32)
    return extract_physics_vector(arr)
