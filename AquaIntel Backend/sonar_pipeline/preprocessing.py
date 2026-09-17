"""
AquaIntel Sonar Pipeline — Preprocessing & Denoising Engine (Step 1)
Problem Statement 26057 | Team Brainwave | SIH 2026

Implements:
1. Adaptive Lee Filter for speckle reduction while strictly preserving acoustic shadow boundaries.
2. Bilateral Filter alternative behind configuration flag.
3. Motion dropout detection, linear 1D interpolation for short gaps (<= 3 rows), and
   non-surveyable masking with logging for large gaps (> 3 rows).
"""

from __future__ import annotations
import logging
from typing import List, Optional, Tuple

import cv2
import numpy as np
from scipy import ndimage

from sonar_pipeline.schemas import DropoutSpan, PipelineConfig, SonarFrame

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Speckle Filtering: Adaptive Lee Filter & Bilateral Filter
# ---------------------------------------------------------------------------

def adaptive_lee_filter(
    intensity: np.ndarray,
    window_size: int = 7,
    noise_var: Optional[float] = None,
) -> np.ndarray:
    r"""
    Applies an Adaptive Lee Filter to suppress multiplicative acoustic speckle noise
    while preserving sharp highlight-to-shadow acoustic boundaries.
    
    Mathematical Formulation:
      - Local Mean: \mu_{i,j} = \frac{1}{N} \sum_{(k,l) \in W} I(k,l)
      - Local Variance: \sigma_y^2 = \overline{I^2} - \mu^2
      - Weighting Factor: W = \max\left(0, \frac{\sigma_y^2 - \sigma_n^2}{\sigma_y^2}\right)
      - Filtered Output: \hat{I}_{i,j} = \mu_{i,j} + W \cdot (I_{i,j} - \mu_{i,j})
      
    When W -> 1 (near shadow edges and targets with high variance), \hat{I} \approx I (retains edge sharpness).
    When W -> 0 (homogeneous seafloor speckle), \hat{I} \approx \mu (smooths out speckle).
    
    Units:
        - intensity: 2D numpy array [rows, cols] (float32)
        - window_size: pixels (must be odd, >= 3)
        - noise_var: variance of noise (in intensity^2 units; auto-estimated if None)
        
    Args:
        intensity: 2D float32 sonar intensity waterfall array.
        window_size: Moving filter kernel dimension in pixels (default 7).
        noise_var: Optional prior on speckle noise variance.
        
    Returns:
        Filtered 2D float32 array with preserved shadow edges.
    """
    if intensity.ndim != 2:
        raise ValueError(f"Intensity must be 2D, got shape {intensity.shape}")
    if window_size % 2 == 0 or window_size < 3:
        raise ValueError(f"Window size must be an odd integer >= 3, got {window_size}")

    img = intensity.astype(np.float32)
    k_shape = (window_size, window_size)

    # Compute local mean \mu and local mean of squares \overline{I^2} using uniform box filter
    local_mean = cv2.boxFilter(img, ddepth=-1, ksize=k_shape, borderType=cv2.BORDER_REFLECT)
    local_mean_sq = cv2.boxFilter(img ** 2, ddepth=-1, ksize=k_shape, borderType=cv2.BORDER_REFLECT)

    # Local variance \sigma_y^2
    local_var = np.maximum(0.0, local_mean_sq - (local_mean ** 2))

    # Estimate noise variance \sigma_n^2 if not explicitly provided
    if noise_var is None:
        # Standard speckle model: ratio of std / mean for homogeneous 1-look sonar is ~ 0.28
        # We estimate background noise variance from the lower 25th percentile of local variances
        noise_var = float(np.percentile(local_var[local_mean > 1e-3], 25)) if np.any(local_mean > 1e-3) else 1e-3
        noise_var = max(1e-5, noise_var)

    # Weighting factor W in [0.0, 1.0]
    # To avoid division by zero:
    denom = local_var + 1e-6
    weight = np.clip((local_var - noise_var) / denom, 0.0, 1.0)

    # Filtered estimate: \hat{I} = \mu + W * (I - \mu)
    filtered = local_mean + weight * (img - local_mean)
    return filtered.astype(np.float32)


def bilateral_filter_sonar(
    intensity: np.ndarray,
    d: int = 7,
    sigma_color: float = 50.0,
    sigma_space: float = 50.0,
) -> np.ndarray:
    """
    Applies OpenCV bilateral filtering for edge-preserving smoothing.
    
    Units:
        - intensity: 2D numpy array [rows, cols] (float32)
        - d: pixel neighborhood diameter (pixels)
        - sigma_color: filter sigma in the intensity space
        - sigma_space: filter sigma in the coordinate space (pixels)
        
    Args:
        intensity: 2D float32 sonar intensity array.
        d: Diameter of pixel neighborhood.
        sigma_color: Filter sigma in intensity space.
        sigma_space: Filter sigma in coordinate space.
        
    Returns:
        Filtered 2D float32 array.
    """
    img = intensity.astype(np.float32)
    # cv2.bilateralFilter supports float32 natively
    filtered = cv2.bilateralFilter(img, d=d, sigmaColor=sigma_color, sigmaSpace=sigma_space)
    return filtered.astype(np.float32)


def denoise_sonar_frame(
    frame: SonarFrame,
    config: Optional[PipelineConfig] = None,
) -> SonarFrame:
    """
    Applies speckle denoising to the sonar frame based on pipeline configuration.
    
    Args:
        frame: Ingested SonarFrame.
        config: PipelineConfig parameters.
        
    Returns:
        Denoised SonarFrame.
    """
    cfg = config or PipelineConfig()
    method = cfg.denoise_method.lower()

    if method == "lee":
        denoised_intensity = adaptive_lee_filter(
            frame.intensity,
            window_size=cfg.lee_window_size,
            noise_var=cfg.lee_noise_var,
        )
    elif method == "bilateral":
        denoised_intensity = bilateral_filter_sonar(
            frame.intensity,
            d=cfg.bilateral_d,
            sigma_color=cfg.bilateral_sigma_color,
            sigma_space=cfg.bilateral_sigma_space,
        )
    else:
        raise ValueError(f"Unknown denoising method: {method}. Choose 'lee' or 'bilateral'.")

    return SonarFrame(
        intensity=denoised_intensity,
        valid_mask=frame.valid_mask.copy(),
        metadata=frame.metadata,
        dropout_spans=frame.dropout_spans.copy(),
    )


# ---------------------------------------------------------------------------
# Motion Dropout Detection & Correction
# ---------------------------------------------------------------------------

def detect_and_correct_dropouts(
    intensity: np.ndarray,
    valid_mask: np.ndarray,
    max_interp_rows: int = 3,
    intensity_thresh: float = 1.5,
    var_ratio_thresh: float = 0.05,
) -> Tuple[np.ndarray, np.ndarray, List[DropoutSpan]]:
    """
    Scans cross-ping rows for motion dropouts, transmission dropouts, or heave/roll gaps.
    
    Gap Rule:
      - Contiguous gap <= 3 rows: 1D linear interpolation across columns using neighboring valid pings.
      - Contiguous gap > 3 rows: Mask span as non-surveyable (valid_mask = False), do NOT interpolate
        over severe data loss, and log dropout span with metadata provenance.
        
    Units:
        - intensity: 2D numpy array [pings_along_track (rows), range_bins_cross_track (cols)]
        - valid_mask: 2D boolean array [rows, cols]
        - max_interp_rows: rows (pings)
        - intensity_thresh: intensity units (mean row intensity below which row is dropped)
        - var_ratio_thresh: ratio (row variance / mean survey variance)
        
    Args:
        intensity: 2D float32 sonar waterfall image.
        valid_mask: 2D boolean survey mask (True=valid, False=masked).
        max_interp_rows: Maximum contiguous dropped rows to interpolate (default 3).
        intensity_thresh: Threshold for zero-intensity detection.
        var_ratio_thresh: Threshold for sudden variance collapse detection.
        
    Returns:
        Tuple of (corrected intensity array, updated valid_mask, list of DropoutSpan records).
    """
    out_intensity = intensity.copy().astype(np.float32)
    out_mask = valid_mask.copy().astype(bool)
    num_rows, num_cols = out_intensity.shape
    
    if num_rows == 0:
        return out_intensity, out_mask, []

    # Calculate row-level statistics along-track
    row_means = np.mean(out_intensity, axis=1)
    row_vars = np.var(out_intensity, axis=1)

    valid_survey_means = row_means[row_means > intensity_thresh]
    mean_survey_var = float(np.mean(row_vars[row_means > intensity_thresh])) if len(valid_survey_means) > 0 else 1.0
    var_lower_bound = var_ratio_thresh * max(1e-3, mean_survey_var)

    # Identify dropped ping rows
    dropped_flags = np.zeros(num_rows, dtype=bool)
    for r in range(num_rows):
        if row_means[r] <= intensity_thresh:
            dropped_flags[r] = True
        elif row_vars[r] < var_lower_bound and row_means[r] < (np.mean(valid_survey_means) * 0.2 if len(valid_survey_means) else 1.0):
            dropped_flags[r] = True

    # Identify contiguous spans of dropped rows
    dropout_spans: List[DropoutSpan] = []
    r = 0
    while r < num_rows:
        if dropped_flags[r]:
            span_start = r
            while r < num_rows and dropped_flags[r]:
                r += 1
            span_end = r - 1
            span_length = span_end - span_start + 1

            if span_length <= max_interp_rows:
                # 1D Linear Interpolation across the gap along each column
                prev_valid_idx = span_start - 1
                next_valid_idx = span_end + 1

                has_prev = prev_valid_idx >= 0 and not dropped_flags[prev_valid_idx]
                has_next = next_valid_idx < num_rows and not dropped_flags[next_valid_idx]

                if has_prev and has_next:
                    y0 = out_intensity[prev_valid_idx, :]
                    y1 = out_intensity[next_valid_idx, :]
                    total_steps = span_length + 1
                    for step, row_idx in enumerate(range(span_start, span_end + 1), start=1):
                        alpha = step / float(total_steps)
                        out_intensity[row_idx, :] = (1.0 - alpha) * y0 + alpha * y1
                elif has_prev:
                    for row_idx in range(span_start, span_end + 1):
                        out_intensity[row_idx, :] = out_intensity[prev_valid_idx, :]
                elif has_next:
                    for row_idx in range(span_start, span_end + 1):
                        out_intensity[row_idx, :] = out_intensity[next_valid_idx, :]

                dropout_spans.append(
                    DropoutSpan(
                        start_row=span_start,
                        end_row=span_end,
                        length_rows=span_length,
                        action="interpolated",
                        reason="short_dropout_interpolated",
                    )
                )
                logger.info(f"Interpolated short motion dropout span: rows [{span_start}:{span_end}] (length={span_length})")
            else:
                # Severe data loss: Mask as non-surveyable, do not interpolate
                out_mask[span_start : span_end + 1, :] = False
                dropout_spans.append(
                    DropoutSpan(
                        start_row=span_start,
                        end_row=span_end,
                        length_rows=span_length,
                        action="masked_non_surveyable",
                        reason="large_gap_exceeds_threshold",
                    )
                )
                logger.warning(
                    f"Non-surveyable span detected and masked: rows [{span_start}:{span_end}] (length={span_length} > {max_interp_rows})"
                )
        else:
            r += 1

    return out_intensity, out_mask, dropout_spans


def preprocess_sonar_frame(
    frame: SonarFrame,
    config: Optional[PipelineConfig] = None,
) -> SonarFrame:
    """
    Executes Step 1 preprocessing pipeline:
      1. Motion dropout scanning, linear 1D interpolation for short gaps (<=3 rows),
         and non-surveyable masking for long gaps (>3 rows).
      2. Adaptive Lee filtering or bilateral filtering for speckle noise reduction.
      
    Args:
        frame: SonarFrame from Step 0 ingestion.
        config: PipelineConfig parameters.
        
    Returns:
        Clean, preprocessed SonarFrame with updated validity mask and dropout spans.
    """
    cfg = config or PipelineConfig()
    
    # 1. Motion Dropout Detection & Correction
    corrected_intensity, updated_mask, dropouts = detect_and_correct_dropouts(
        intensity=frame.intensity,
        valid_mask=frame.valid_mask,
        max_interp_rows=cfg.dropout_max_interp_rows,
        intensity_thresh=cfg.dropout_intensity_thresh,
        var_ratio_thresh=cfg.dropout_var_ratio_thresh,
    )

    # 2. Speckle Denoising (Adaptive Lee or Bilateral)
    if cfg.denoise_method.lower() == "lee":
        denoised_intensity = adaptive_lee_filter(
            corrected_intensity,
            window_size=cfg.lee_window_size,
            noise_var=cfg.lee_noise_var,
        )
    elif cfg.denoise_method.lower() == "bilateral":
        denoised_intensity = bilateral_filter_sonar(
            corrected_intensity,
            d=cfg.bilateral_d,
            sigma_color=cfg.bilateral_sigma_color,
            sigma_space=cfg.bilateral_sigma_space,
        )
    else:
        raise ValueError(f"Unknown denoise method: {cfg.denoise_method}")

    return SonarFrame(
        intensity=denoised_intensity,
        valid_mask=updated_mask,
        metadata=frame.metadata,
        dropout_spans=frame.dropout_spans + dropouts,
    )
