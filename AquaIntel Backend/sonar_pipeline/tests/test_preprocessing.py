"""
Tests for sonar_pipeline.preprocessing (Step 1)
"""

import numpy as np
import pytest

from sonar_pipeline.preprocessing import (
    adaptive_lee_filter,
    bilateral_filter_sonar,
    detect_and_correct_dropouts,
    preprocess_sonar_frame,
)
from sonar_pipeline.schemas import PipelineConfig, SonarFrame, SonarMetadata


@pytest.fixture
def synthetic_frame():
    """Generates a synthetic sonar frame."""
    intensity = np.ones((100, 100), dtype=np.float32) * 100.0
    mask = np.ones((100, 100), dtype=bool)
    meta = SonarMetadata(
        h_tow_m=10.0,
        slant_range_max_m=50.0,
        source_resolution_x_m_per_px=0.05,
        source_resolution_y_m_per_px=0.05,
        target_resolution_m_per_px=0.05,
    )
    return SonarFrame(intensity=intensity, valid_mask=mask, metadata=meta)


def test_adaptive_lee_filter_speckle_reduction():
    # Constant seafloor + multiplicative speckle noise
    np.random.seed(42)
    clean_seafloor = np.ones((100, 100), dtype=np.float32) * 120.0
    speckle_noise = np.random.exponential(scale=1.0, size=(100, 100)).astype(np.float32)
    noisy_sonar = clean_seafloor * speckle_noise

    filtered = adaptive_lee_filter(noisy_sonar, window_size=7)

    # Variance of filtered image must be significantly lower than noisy input
    var_noisy = np.var(noisy_sonar[10:90, 10:90])
    var_filtered = np.var(filtered[10:90, 10:90])

    assert var_filtered < var_noisy * 0.5, "Lee filter failed to suppress speckle noise in homogeneous region"


def test_adaptive_lee_filter_shadow_edge_preservation():
    # Synthetic image with sharp shadow boundary:
    # Left side (cols 0..49) = Seafloor (intensity 150)
    # Right side (cols 50..99) = Acoustic Shadow (intensity 5)
    step_edge = np.zeros((80, 100), dtype=np.float32)
    step_edge[:, 0:50] = 150.0
    step_edge[:, 50:100] = 5.0

    filtered = adaptive_lee_filter(step_edge, window_size=7)

    # In Lee filter, where variance across edge is high (W -> 1), pixel values at the edge
    # should retain sharp contrast without being smeared into a blur
    intensity_before_edge = filtered[:, 45]  # Seafloor side
    intensity_after_edge = filtered[:, 55]   # Shadow side

    assert np.mean(intensity_before_edge) > 130.0, "Seafloor intensity lost near shadow edge"
    assert np.mean(intensity_after_edge) < 20.0, "Shadow intensity artificially inflated near edge"


def test_bilateral_filter_sonar():
    img = np.ones((50, 50), dtype=np.float32) * 100.0
    img[20:30, 20:30] = 10.0  # Shadow box
    filtered = bilateral_filter_sonar(img, d=5, sigma_color=30.0, sigma_space=30.0)
    
    assert filtered.shape == (50, 50)
    assert np.mean(filtered[22:28, 22:28]) < 20.0


def test_motion_dropout_short_gap_interpolated():
    # 50 pings: Rows 20 and 21 (length 2 <= 3) are dropouts (zero intensity)
    intensity = np.ones((50, 60), dtype=np.float32) * 100.0
    intensity[19, :] = 80.0
    intensity[20:22, :] = 0.0  # Dropped 2 rows
    intensity[22, :] = 110.0
    mask = np.ones((50, 60), dtype=bool)

    corrected, out_mask, spans = detect_and_correct_dropouts(intensity, mask, max_interp_rows=3)

    assert len(spans) == 1
    assert spans[0].length_rows == 2
    assert spans[0].action == "interpolated"
    # Mask should remain valid (True) since gap was repaired
    assert out_mask[20:22, :].all()
    # Interpolated values should lie strictly between row 19 (80.0) and row 22 (110.0)
    assert np.all(corrected[20, :] > 80.0)
    assert np.all(corrected[21, :] < 110.0)


def test_motion_dropout_long_gap_masked():
    # 50 pings: Rows 25 to 30 (length 6 > 3) are severe data loss
    intensity = np.ones((50, 60), dtype=np.float32) * 100.0
    intensity[25:31, :] = 0.0  # 6 dropped rows
    mask = np.ones((50, 60), dtype=bool)

    corrected, out_mask, spans = detect_and_correct_dropouts(intensity, mask, max_interp_rows=3)

    assert len(spans) == 1
    assert spans[0].length_rows == 6
    assert spans[0].action == "masked_non_surveyable"
    # Span must be masked out in valid_mask
    assert not np.any(out_mask[25:31, :])


def test_preprocess_sonar_frame_end_to_end(synthetic_frame):
    # Insert both a short gap and a long gap
    synthetic_frame.intensity[10:12, :] = 0.0  # 2 rows (interpolated)
    synthetic_frame.intensity[40:46, :] = 0.0  # 6 rows (masked)

    cfg = PipelineConfig(denoise_method="lee", dropout_max_interp_rows=3)
    preprocessed = preprocess_sonar_frame(synthetic_frame, cfg)

    assert len(preprocessed.dropout_spans) == 2
    actions = {s.action for s in preprocessed.dropout_spans}
    assert "interpolated" in actions
    assert "masked_non_surveyable" in actions
    assert not np.any(preprocessed.valid_mask[40:46, :])
