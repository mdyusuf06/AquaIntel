"""
Tests for sonar_pipeline.physics (Step 2)
"""

import numpy as np
import pytest

from sonar_pipeline.physics import (
    compute_acoustic_shadow_height,
    compute_haralick_texture,
    compute_principal_axis_orientation,
    extract_physics_features,
)
from sonar_pipeline.schemas import PipelineConfig, SonarFrame, SonarMetadata


def test_compute_acoustic_shadow_height():
    # True test: H_tow = 10m, L_shadow = 5m, R = 25m -> Height = 10 * (5 / 25) = 2.0m
    h = compute_acoustic_shadow_height(h_tow_m=10.0, shadow_length_m=5.0, slant_range_m=25.0)
    assert h == pytest.approx(2.0, abs=1e-4)

    # Smaller object: H_tow = 8.0m, L_shadow = 1.5m, R = 20.0m -> Height = 8 * (1.5 / 20) = 0.60m
    h2 = compute_acoustic_shadow_height(h_tow_m=8.0, shadow_length_m=1.5, slant_range_m=20.0)
    assert h2 == pytest.approx(0.60, abs=1e-4)


def test_compute_acoustic_shadow_height_invalid():
    with pytest.raises(ValueError):
        compute_acoustic_shadow_height(h_tow_m=-1.0, shadow_length_m=2.0, slant_range_m=10.0)

    with pytest.raises(ValueError):
        compute_acoustic_shadow_height(h_tow_m=10.0, shadow_length_m=-2.0, slant_range_m=10.0)


def test_compute_haralick_texture():
    # 20x20 patch with texture
    patch = np.zeros((20, 20), dtype=np.float32)
    patch[:10, :10] = 200.0
    patch[10:, 10:] = 20.0

    features = compute_haralick_texture(patch, num_levels=16)
    assert features.contrast >= 0.0
    assert features.dissimilarity >= 0.0
    assert 0.0 <= features.homogeneity <= 1.0
    assert 0.0 <= features.energy <= 1.0
    assert -1.0 <= features.correlation <= 1.0
    assert 0.0 <= features.asm <= 1.0


def test_compute_principal_axis_orientation():
    # Horizontal bar: expect orientation ~ 0 or ~ 180 deg
    horiz_mask = np.zeros((30, 30), dtype=np.uint8)
    horiz_mask[13:17, 5:25] = 1
    ang_h = compute_principal_axis_orientation(horiz_mask)
    assert ang_h < 15.0 or ang_h > 165.0

    # Diagonal bar (45 degrees)
    diag_mask = np.zeros((30, 30), dtype=np.uint8)
    for i in range(5, 25):
        diag_mask[i, i] = 1
        diag_mask[i, min(29, i + 1)] = 1
    ang_d = compute_principal_axis_orientation(diag_mask)
    assert ang_d == pytest.approx(45.0, abs=10.0)


def test_extract_physics_features_synthetic_ground_truth():
    """
    Synthesizes a side-scan sonar waterfall with an embedded physical debris object
    with exact ground-truth dimensions and asserts accurate recovery of object height.
    """
    # 200 rows (along-track), 400 cols (cross-track). Nadir is at col 200.
    res_m = 0.05  # 0.05 m/px
    h_tow_m = 10.0  # 10 meters altitude
    
    intensity = np.ones((200, 400), dtype=np.float32) * 100.0  # Seafloor background

    # Starboard side object:
    # Placed at highlight col = 300 (Slant range distance from nadir col 200: 100 px * 0.05 = 5.0m)
    # Highlight: cols 300..305 (width 5 px), rows 80..100 -> intensity 240
    intensity[80:101, 300:306] = 240.0

    # Shadow cast to the right: cols 306..345 (length 40 px * 0.05 = 2.0m), rows 80..100 -> intensity 5.0
    intensity[80:101, 306:346] = 5.0

    # Expected physical height:
    # R = (300 - 200) * 0.05 = 5.0m
    # L_shadow = 40 * 0.05 = 2.0m
    # Expected Height = H_tow * (L_shadow / R) = 10.0 * (2.0 / 5.0) = 4.0m
    expected_height = 4.0

    valid_mask = np.ones((200, 400), dtype=bool)
    meta = SonarMetadata(
        h_tow_m=h_tow_m,
        slant_range_max_m=20.0,
        origin_lon=500000.0,
        origin_lat=5600000.0,
        source_resolution_x_m_per_px=res_m,
        source_resolution_y_m_per_px=res_m,
        target_resolution_m_per_px=res_m,
        crs="EPSG:32630",
        transform_matrix=[res_m, 0.0, 500000.0, 0.0, -res_m, 5600000.0],
    )

    frame = SonarFrame(intensity=intensity, valid_mask=valid_mask, metadata=meta)
    cfg = PipelineConfig(
        target_resolution_m_per_px=res_m,
        shadow_thresh_percentile=15.0,
        highlight_thresh_percentile=85.0,
        min_shadow_area_px=20,
        min_highlight_area_px=10,
    )

    features = extract_physics_features(frame, cfg)

    assert len(features) >= 1, "Failed to detect synthetic highlight-shadow pair"
    obj = features[0]

    # Verify recovered slant range and shadow length
    assert obj.slant_range_m == pytest.approx(5.0, abs=0.25)
    assert obj.shadow_length_m == pytest.approx(2.0, abs=0.25)
    # Verify acoustic shadow height recovery matches ground truth (4.0m) within tolerance
    assert obj.computed_height_m == pytest.approx(expected_height, abs=0.4)
    assert obj.is_valid_physics is True
    assert obj.shadow_area_m2 > 0.0
    assert obj.highlight_area_m2 > 0.0
    assert obj.confidence > 0.5
    assert obj.haralick_features.contrast >= 0.0
