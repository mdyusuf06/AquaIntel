"""
Tests for sonar_pipeline.schemas
"""

import numpy as np
import pytest
from pydantic import ValidationError

from sonar_pipeline.schemas import (
    SonarFormat,
    SonarMetadata,
    SonarFrame,
    DropoutSpan,
    HaralickFeatures,
    SonarObjectFeature,
    PipelineConfig,
    PipelineResult,
)


def test_sonar_metadata_valid():
    meta = SonarMetadata(
        h_tow_m=10.0,
        slant_range_max_m=50.0,
        origin_lon=-1.5000,
        origin_lat=50.8000,
        heading_deg=180.0,
        source_resolution_x_m_per_px=0.1,
        source_resolution_y_m_per_px=0.1,
        target_resolution_m_per_px=0.05,
        crs="EPSG:4326",
    )
    assert meta.h_tow_m == 10.0
    assert meta.slant_range_max_m == 50.0
    assert meta.heading_deg == 180.0
    assert meta.target_resolution_m_per_px == 0.05


def test_sonar_metadata_invalid():
    with pytest.raises(ValidationError):
        SonarMetadata(
            h_tow_m=-5.0,  # Negative altitude is invalid
            slant_range_max_m=50.0,
            source_resolution_x_m_per_px=0.1,
            source_resolution_y_m_per_px=0.1,
        )


def test_sonar_frame_creation():
    intensity = np.zeros((100, 200), dtype=np.float32)
    mask = np.ones((100, 200), dtype=bool)
    meta = SonarMetadata(
        h_tow_m=8.0,
        slant_range_max_m=40.0,
        source_resolution_x_m_per_px=0.08,
        source_resolution_y_m_per_px=0.08,
    )
    frame = SonarFrame(intensity=intensity, valid_mask=mask, metadata=meta)
    assert frame.intensity.shape == (100, 200)
    assert frame.valid_mask.shape == (100, 200)
    assert frame.metadata.h_tow_m == 8.0


def test_dropout_span():
    span = DropoutSpan(
        start_row=10,
        end_row=12,
        length_rows=3,
        action="interpolated",
        reason="zero_intensity",
    )
    assert span.start_row == 10
    assert span.length_rows == 3
    assert span.action == "interpolated"


def test_sonar_object_feature():
    haralick = HaralickFeatures(
        contrast=12.5,
        dissimilarity=2.1,
        homogeneity=0.85,
        energy=0.45,
        correlation=0.92,
        asm=0.20,
    )
    feature = SonarObjectFeature(
        object_id="obj_001",
        bbox_px=(50, 60, 80, 95),
        center_px=(65.0, 77.5),
        center_geo=(-1.498, 50.801),
        slant_range_m=25.0,
        shadow_length_m=5.0,
        computed_height_m=2.0,  # H = 10 * (5 / 25) = 2.0m
        shadow_area_m2=3.5,
        highlight_area_m2=1.2,
        highlight_to_shadow_ratio=0.342,
        principal_axis_orientation_deg=45.0,
        haralick_features=haralick,
        confidence=0.95,
        is_valid_physics=True,
    )
    assert feature.computed_height_m == 2.0
    assert feature.haralick_features.contrast == 12.5
    assert feature.is_valid_physics is True
