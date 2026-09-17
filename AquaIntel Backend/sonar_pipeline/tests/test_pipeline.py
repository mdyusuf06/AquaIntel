"""
Tests for sonar_pipeline.pipeline (End-to-End Orchestration)
"""

import json
from pathlib import Path

import cv2
import numpy as np
import pytest

from sonar_pipeline.pipeline import SonarPipeline
from sonar_pipeline.schemas import PipelineConfig


@pytest.fixture
def synthetic_survey_session(tmp_path: Path):
    """
    Creates a realistic synthetic side-scan sonar waterfall session:
    - 200 pings along track, 400 range bins cross track (nadir at col 200).
    - Seafloor background intensity = 110.0 + random speckle noise.
    - Injected Debris Target on Starboard side at col 300 (Slant range R = 100 px * 0.05 = 5.0m):
      - Highlight: cols 300..305, rows 70..85 -> intensity 245.0
      - Shadow: cols 306..345 (length 40 px * 0.05 = 2.0m), rows 70..85 -> intensity 5.0
      - Ground truth height: H_tow (10m) * (2.0m / 5.0m) = 4.0m
    - Injected Motion Dropouts:
      - 2-row short gap at rows 20:22 (should be interpolated)
      - 5-row severe dropout at rows 140:145 (should be masked as non-surveyable)
    """
    res_m = 0.05
    img = np.ones((200, 400), dtype=np.float32) * 110.0
    
    # Add speckle noise
    speckle = np.random.uniform(0.9, 1.1, size=(200, 400)).astype(np.float32)
    img = img * speckle

    # Injected target
    img[70:86, 300:306] = 245.0  # Highlight
    img[70:86, 306:346] = 5.0    # Shadow

    # Injected dropouts
    img[20:22, :] = 0.0   # 2-row short gap
    img[140:145, :] = 0.0 # 5-row severe dropout

    img_u8 = np.clip(img, 0, 255).astype(np.uint8)
    img_path = tmp_path / "survey_mission_01.png"
    cv2.imwrite(str(img_path), img_u8)

    meta = {
        "h_tow_m": 10.0,
        "slant_range_max_m": 20.0,
        "origin_lon": 500000.0,
        "origin_lat": 5600000.0,
        "heading_deg": 45.0,
        "source_resolution_x_m_per_px": 0.05,
        "source_resolution_y_m_per_px": 0.05,
        "target_resolution_m_per_px": 0.05,
        "crs": "EPSG:32630",
        "sensor_name": "AquaIntel-Towfish-Sim",
    }
    json_path = tmp_path / "survey_mission_01.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(meta, f)

    return img_path, json_path


def test_sonar_pipeline_end_to_end(synthetic_survey_session, tmp_path: Path):
    img_path, json_path = synthetic_survey_session

    cfg = PipelineConfig(
        target_resolution_m_per_px=0.05,
        denoise_method="lee",
        lee_window_size=5,
        dropout_max_interp_rows=3,
        shadow_thresh_percentile=15.0,
        highlight_thresh_percentile=85.0,
        min_shadow_area_px=15,
        min_highlight_area_px=10,
    )

    pipeline = SonarPipeline(config=cfg)
    result = pipeline.process(img_path, json_path)

    # 1. Check frame dimensions & masking
    assert result.frame.intensity.shape == (200, 400)
    assert not np.any(result.frame.valid_mask[140:145, :]), "Long dropout span was not properly masked"
    assert result.frame.valid_mask[20:22, :].all(), "Short dropout span should have remained valid after interpolation"

    # 2. Check dropout statistics
    assert result.num_dropouts_interpolated == 1
    assert result.num_dropouts_masked == 1

    # 3. Check detected physical features
    assert result.num_objects_detected >= 1
    obj = result.features[0]

    # Expected height = 10.0 * (2.0 / 5.0) = 4.0m
    assert obj.computed_height_m == pytest.approx(4.0, abs=0.5)
    assert obj.shadow_length_m == pytest.approx(2.0, abs=0.3)
    assert obj.slant_range_m == pytest.approx(5.0, abs=0.3)
    assert obj.is_valid_physics is True
    assert obj.haralick_features.contrast >= 0.0
    assert obj.haralick_features.homogeneity <= 1.0

    # 4. Check provenance logging
    assert len(result.provenance_log) >= 4
    assert any("Step 0 Ingestion" in line for line in result.provenance_log)
    assert any("Step 1 Preprocessing" in line for line in result.provenance_log)
    assert any("Step 2 Physics" in line for line in result.provenance_log)

    # 5. Check JSON export
    export_path = tmp_path / "extracted_features.json"
    pipeline.export_features_json(result.features, export_path)
    assert export_path.exists()

    with open(export_path, "r", encoding="utf-8") as f:
        exported_data = json.load(f)
    assert len(exported_data) == len(result.features)
    assert exported_data[0]["object_id"] == obj.object_id
    assert "haralick_features" in exported_data[0]
