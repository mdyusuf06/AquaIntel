"""
Tests for sonar_pipeline.ingestion (Step 0)
"""

import json
import struct
from pathlib import Path

import cv2
import numpy as np
import pytest
import rasterio
from rasterio.transform import Affine

from sonar_pipeline.ingestion import (
    detect_format,
    load_sonar_file,
    parse_geotiff,
    parse_png_npy_with_json,
    parse_xtf,
    resample_sonar_frame,
)
from sonar_pipeline.schemas import SonarFormat, SonarMetadata


@pytest.fixture
def synthetic_png_with_json(tmp_path: Path):
    """Generates a synthetic PNG image and JSON sidecar."""
    img_arr = np.random.randint(50, 200, size=(100, 200), dtype=np.uint8)
    img_path = tmp_path / "survey_01.png"
    cv2.imwrite(str(img_path), img_arr)

    meta_dict = {
        "h_tow_m": 12.0,
        "slant_range_max_m": 60.0,
        "origin_lon": -4.500,
        "origin_lat": 48.380,
        "heading_deg": 90.0,
        "source_resolution_x_m_per_px": 0.10,
        "source_resolution_y_m_per_px": 0.10,
        "crs": "EPSG:4326",
    }
    json_path = tmp_path / "survey_01.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(meta_dict, f)

    return img_path, json_path


@pytest.fixture
def synthetic_npy_with_json(tmp_path: Path):
    """Generates a synthetic NPY array and JSON sidecar."""
    npy_arr = np.random.uniform(0.1, 0.9, size=(80, 160)).astype(np.float32)
    npy_path = tmp_path / "sonar_ping.npy"
    np.save(npy_path, npy_arr)

    meta_dict = {
        "h_tow_m": 15.0,
        "slant_range_max_m": 80.0,
        "origin_lon": 320000.0,
        "origin_lat": 5400000.0,
        "heading_deg": 270.0,
        "source_resolution_x_m_per_px": 0.20,
        "source_resolution_y_m_per_px": 0.20,
        "crs": "EPSG:32630",
    }
    json_path = tmp_path / "sonar_ping.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(meta_dict, f)

    return npy_path, json_path


@pytest.fixture
def synthetic_geotiff(tmp_path: Path):
    """Generates a synthetic GeoTIFF with acoustic metadata tags."""
    tiff_path = tmp_path / "sonar_survey.tif"
    arr = np.random.randint(20, 220, size=(120, 240), dtype=np.uint8)
    
    # 0.1m pixel resolution in UTM CRS
    transform = Affine(0.1, 0.0, 500000.0, 0.0, -0.1, 5600000.0)
    
    with rasterio.open(
        tiff_path,
        "w",
        driver="GTiff",
        height=arr.shape[0],
        width=arr.shape[1],
        count=1,
        dtype=arr.dtype,
        crs="EPSG:32630",
        transform=transform,
    ) as dst:
        dst.write(arr, 1)
        dst.update_tags(
            H_TOW="10.5",
            SLANT_RANGE="50.0",
            HEADING="45.0",
            SENSOR_NAME="SimulatedGeoTIFFSonar",
        )
        
    return tiff_path


@pytest.fixture
def synthetic_xtf(tmp_path: Path):
    """Generates a minimal valid synthetic binary XTF file."""
    xtf_path = tmp_path / "survey_line.xtf"
    with open(xtf_path, "wb") as f:
        # File Header (1024 bytes)
        file_header = bytearray(1024)
        file_header[0] = 0x7B  # FileFormat
        file_header[1] = 1     # SystemType
        file_header[2:10] = b"SONAR_V1"
        file_header[14] = 2    # NumSidescanChannels
        f.write(file_header)

        # Write 5 Ping Packets
        num_samples_per_chan = 64
        for ping_idx in range(5):
            # XTFPINGHEADER (256 bytes)
            hdr = bytearray(256)
            # MagicNumber (0xFACE) + HeaderType (0 = sidescan)
            struct.pack_into("<HB", hdr, 0, 0xFACE, 0)
            # Heading at offset 38
            struct.pack_into("<f", hdr, 38, 120.0)
            # Altitude (H_tow) at offset 54
            struct.pack_into("<f", hdr, 54, 8.5)
            # Nav coordinates at offset 70, 78
            struct.pack_into("<d", hdr, 70, -1.55)
            struct.pack_into("<d", hdr, 78, 50.85)
            # Slant range at offset 90
            struct.pack_into("<f", hdr, 90, 40.0)
            # Total packet byte size at offset 100
            total_packet_bytes = 256 + 64 + 64 + (num_samples_per_chan * 2)
            struct.pack_into("<I", hdr, 100, total_packet_bytes)
            f.write(hdr)

            # ChanHeader 0 (Port) - 64 bytes
            chan0 = bytearray(64)
            struct.pack_into("<I", chan0, 10, num_samples_per_chan)
            f.write(chan0)

            # ChanHeader 1 (Stbd) - 64 bytes
            chan1 = bytearray(64)
            struct.pack_into("<I", chan1, 10, num_samples_per_chan)
            f.write(chan1)

            # Port & Stbd samples
            port_bytes = bytes([100 + ping_idx] * num_samples_per_chan)
            stbd_bytes = bytes([120 + ping_idx] * num_samples_per_chan)
            f.write(port_bytes)
            f.write(stbd_bytes)

    return xtf_path


def test_detect_format(synthetic_png_with_json, synthetic_npy_with_json, synthetic_geotiff, synthetic_xtf):
    png_path, _ = synthetic_png_with_json
    npy_path, _ = synthetic_npy_with_json
    
    assert detect_format(png_path) == SonarFormat.PNG_JSON
    assert detect_format(npy_path) == SonarFormat.NPY_JSON
    assert detect_format(synthetic_geotiff) == SonarFormat.GEOTIFF
    assert detect_format(synthetic_xtf) == SonarFormat.XTF


def test_parse_png_with_json(synthetic_png_with_json):
    img_path, json_path = synthetic_png_with_json
    intensity, metadata = parse_png_npy_with_json(img_path, json_path)
    
    assert intensity.shape == (100, 200)
    assert metadata.h_tow_m == 12.0
    assert metadata.slant_range_max_m == 60.0
    assert metadata.heading_deg == 90.0
    assert metadata.source_resolution_x_m_per_px == 0.10


def test_parse_npy_with_json(synthetic_npy_with_json):
    npy_path, json_path = synthetic_npy_with_json
    intensity, metadata = parse_png_npy_with_json(npy_path, json_path)
    
    assert intensity.shape == (80, 160)
    assert metadata.h_tow_m == 15.0
    assert metadata.crs == "EPSG:32630"


def test_parse_geotiff(synthetic_geotiff):
    intensity, metadata = parse_geotiff(synthetic_geotiff)
    
    assert intensity.shape == (120, 240)
    assert metadata.h_tow_m == 10.5
    assert metadata.slant_range_max_m == 50.0
    assert metadata.heading_deg == 45.0
    assert metadata.crs == "EPSG:32630"
    assert metadata.source_resolution_x_m_per_px == pytest.approx(0.1, abs=1e-3)


def test_parse_xtf(synthetic_xtf):
    intensity, metadata = parse_xtf(synthetic_xtf)
    
    assert intensity.shape == (5, 128)  # 5 pings, 64 port + 64 stbd = 128 cols
    assert metadata.h_tow_m == pytest.approx(8.5, abs=1e-2)
    assert metadata.slant_range_max_m == pytest.approx(40.0, abs=1e-2)
    assert metadata.heading_deg == pytest.approx(120.0, abs=1e-2)


def test_resample_sonar_frame():
    # Source is 100x100 pixels at 0.10 m/px -> covers 10m x 10m
    intensity = np.ones((100, 100), dtype=np.float32) * 128.0
    meta = SonarMetadata(
        h_tow_m=10.0,
        slant_range_max_m=50.0,
        origin_lon=500000.0,
        origin_lat=5600000.0,
        heading_deg=0.0,
        source_resolution_x_m_per_px=0.10,
        source_resolution_y_m_per_px=0.10,
        target_resolution_m_per_px=0.05,
        crs="EPSG:32630",
        transform_matrix=[0.10, 0.0, 500000.0, 0.0, -0.10, 5600000.0],
    )
    
    # Resample to 0.05 m/px -> should become 200x200 pixels
    frame = resample_sonar_frame(intensity, meta, target_resolution_m_per_px=0.05)
    
    assert frame.intensity.shape == (200, 200)
    assert frame.valid_mask.shape == (200, 200)
    assert frame.metadata.target_resolution_m_per_px == 0.05
    # Check transformed matrix has 0.05 m/px step
    new_tf = frame.metadata.transform_matrix
    assert new_tf is not None
    assert abs(new_tf[0]) == pytest.approx(0.05, abs=1e-4)
    assert abs(new_tf[4]) == pytest.approx(0.05, abs=1e-4)


def test_load_sonar_file_end_to_end(synthetic_png_with_json):
    png_path, json_path = synthetic_png_with_json
    frame = load_sonar_file(png_path, target_resolution_m_per_px=0.05)
    
    # Source was 100x200 at 0.10 m/px -> target 0.05 m/px should be 200x400
    assert frame.intensity.shape == (200, 400)
    assert frame.valid_mask.all()
    assert frame.metadata.h_tow_m == 12.0
