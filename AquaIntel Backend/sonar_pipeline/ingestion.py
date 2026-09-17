"""
AquaIntel Sonar Pipeline — Ingestion & Georeferencing Engine (Step 0)
Problem Statement 26057 | Team Brainwave | SIH 2026

Ingests raw side-scan sonar files across formats (XTF, GeoTIFF, PNG/NPY with JSON sidecar),
extracts physical acoustic metadata (H_tow, Slant Range, GPS, Heading), and standardizes
the data to a uniform metric resolution (m/pixel) with CRS-aware georeferencing.
"""

from __future__ import annotations
import json
import logging
import os
import struct
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

import cv2
import numpy as np
import pyproj
import rasterio
from rasterio.transform import Affine

from sonar_pipeline.schemas import (
    SonarFormat,
    SonarMetadata,
    SonarFrame,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Format Detectors & Parsers
# ---------------------------------------------------------------------------

def detect_format(file_path: Union[str, Path]) -> SonarFormat:
    """
    Identifies the sonar file format from file extension and header inspection.
    
    Args:
        file_path: Path to the sonar data file.
        
    Returns:
        SonarFormat enum value.
    """
    path = Path(file_path)
    suffix = path.suffix.lower()
    if suffix in [".xtf"]:
        return SonarFormat.XTF
    elif suffix in [".tif", ".tiff", ".geotiff"]:
        return SonarFormat.GEOTIFF
    elif suffix in [".npy"]:
        return SonarFormat.NPY_JSON
    elif suffix in [".png", ".jpg", ".jpeg", ".bmp"]:
        return SonarFormat.PNG_JSON
    else:
        # Fallback to magic bytes check
        try:
            with open(path, "rb") as f:
                magic = f.read(4)
                if len(magic) >= 1 and magic[0] == 0x7B:  # XTF file header magic
                    return SonarFormat.XTF
                if magic.startswith(b"II*\x00") or magic.startswith(b"MM\x00*"):
                    return SonarFormat.GEOTIFF
                if magic.startswith(b"\x93NUMPY"):
                    return SonarFormat.NPY_JSON
        except Exception:
            pass
        raise ValueError(f"Unsupported sonar file format: {file_path}")


def parse_png_npy_with_json(
    image_path: Union[str, Path],
    json_path: Optional[Union[str, Path]] = None,
) -> Tuple[np.ndarray, SonarMetadata]:
    """
    Parses a PNG or NPY side-scan sonar image accompanied by a JSON metadata sidecar.
    
    Units:
        - Returned intensity: 2D numpy array [pings_along_track (rows), range_bins_cross_track (cols)] (float32)
        - Metadata fields: h_tow_m (meters), slant_range_max_m (meters), heading_deg (degrees),
          source_resolution (meters/pixel), crs (string).
          
    Args:
        image_path: Path to .png or .npy array.
        json_path: Path to .json sidecar. If None, expects <image_stem>.json.
        
    Returns:
        Tuple of (2D intensity array, SonarMetadata).
    """
    img_path = Path(image_path)
    if json_path is None:
        json_candidates = [
            img_path.with_suffix(".json"),
            img_path.parent / f"{img_path.stem}_meta.json",
            img_path.parent / "metadata.json",
        ]
        for candidate in json_candidates:
            if candidate.exists():
                json_path = candidate
                break
        if json_path is None:
            raise FileNotFoundError(f"JSON sidecar not found for {image_path}. Checked: {json_candidates}")
    
    with open(json_path, "r", encoding="utf-8") as f:
        meta_dict = json.load(f)

    # Load image array
    if img_path.suffix.lower() == ".npy":
        raw_arr = np.load(img_path)
    else:
        raw_arr = cv2.imread(str(img_path), cv2.IMREAD_UNCHANGED)
        if raw_arr is None:
            raise ValueError(f"Failed to read image file: {img_path}")
    
    if raw_arr.ndim == 3:
        # Convert multi-channel to grayscale intensity
        raw_arr = cv2.cvtColor(raw_arr, cv2.COLOR_BGR2GRAY)
        
    intensity = raw_arr.astype(np.float32)
    rows, cols = intensity.shape

    # Extract acoustic geometry parameters
    h_tow_m = float(meta_dict.get("h_tow_m") or meta_dict.get("h_tow") or meta_dict.get("altitude_m", 10.0))
    slant_range_max_m = float(
        meta_dict.get("slant_range_max_m") or meta_dict.get("slant_range") or meta_dict.get("range_m", 50.0)
    )
    origin_lon = float(meta_dict.get("origin_lon") or meta_dict.get("longitude", 0.0))
    origin_lat = float(meta_dict.get("origin_lat") or meta_dict.get("latitude", 0.0))
    heading_deg = float(meta_dict.get("heading_deg") or meta_dict.get("heading", 0.0))
    crs = str(meta_dict.get("crs", "EPSG:4326"))
    
    # Compute or read pixel resolutions (meters/pixel)
    source_res_x = float(
        meta_dict.get("source_resolution_x_m_per_px")
        or meta_dict.get("resolution_x_m")
        or (slant_range_max_m / cols)
    )
    source_res_y = float(
        meta_dict.get("source_resolution_y_m_per_px")
        or meta_dict.get("resolution_y_m")
        or source_res_x
    )
    target_res = float(meta_dict.get("target_resolution_m_per_px", 0.05))
    
    transform_matrix = meta_dict.get("transform_matrix")
    if transform_matrix is None:
        # Default top-left affine transform: [res_x, 0, origin_x, 0, -res_y, origin_y]
        transform_matrix = [source_res_x, 0.0, origin_lon, 0.0, -source_res_y, origin_lat]

    metadata = SonarMetadata(
        h_tow_m=h_tow_m,
        slant_range_max_m=slant_range_max_m,
        origin_lon=origin_lon,
        origin_lat=origin_lat,
        heading_deg=heading_deg,
        source_resolution_x_m_per_px=source_res_x,
        source_resolution_y_m_per_px=source_res_y,
        target_resolution_m_per_px=target_res,
        crs=crs,
        transform_matrix=transform_matrix,
        sensor_name=meta_dict.get("sensor_name", "SideScan-JSON-Source"),
        extra_tags=meta_dict,
    )
    
    return intensity, metadata


def parse_geotiff(geotiff_path: Union[str, Path]) -> Tuple[np.ndarray, SonarMetadata]:
    """
    Parses a raw GeoTIFF side-scan sonar waterfall or mosaic file, reading embedded
    geographic metadata, spatial affine transform, and acoustic sensor tags.
    
    Units:
        - Returned intensity: 2D numpy array [pings_along_track (rows), range_bins_cross_track (cols)] (float32)
        - Metadata fields: h_tow_m (meters), slant_range_max_m (meters), heading_deg (degrees),
          source_resolution (meters/pixel), crs (string).
          
    Args:
        geotiff_path: Path to the GeoTIFF file.
        
    Returns:
        Tuple of (2D intensity array, SonarMetadata).
    """
    path = Path(geotiff_path)
    with rasterio.open(path) as ds:
        raw_arr = ds.read(1).astype(np.float32)
        crs_str = ds.crs.to_string() if ds.crs else "EPSG:4326"
        transform = ds.transform  # Affine(a, b, c, d, e, f)
        tags = ds.tags()
        rows, cols = raw_arr.shape

        # Calculate pixel resolution from Affine transform
        res_x_m = abs(float(transform.a))
        res_y_m = abs(float(transform.e))
        
        # If coordinates are in degrees (EPSG:4326), convert degree step to approximate meters at latitude
        origin_x = float(transform.c)
        origin_y = float(transform.f)
        if "4326" in crs_str:
            # 1 deg lat ~= 111,320m; 1 deg lon ~= 111,320m * cos(lat)
            lat_rad = np.radians(origin_y)
            res_x_m = res_x_m * 111320.0 * max(0.1, np.cos(lat_rad))
            res_y_m = res_y_m * 111320.0
            
        # Parse acoustic parameters from TIFF tags if available
        h_tow_m = float(tags.get("H_TOW") or tags.get("ALTITUDE") or tags.get("SENSOR_ALTITUDE", 10.0))
        slant_range_max_m = float(
            tags.get("SLANT_RANGE") or tags.get("RANGE") or (cols * res_x_m / 2.0)
        )
        heading_deg = float(tags.get("HEADING") or tags.get("SENSOR_HEADING", 0.0))
        sensor_name = tags.get("SENSOR_NAME", "GeoTIFF-SideScan")
        
        transform_matrix = [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f]

        metadata = SonarMetadata(
            h_tow_m=h_tow_m,
            slant_range_max_m=slant_range_max_m,
            origin_lon=origin_x,
            origin_lat=origin_y,
            heading_deg=heading_deg,
            source_resolution_x_m_per_px=max(1e-4, res_x_m),
            source_resolution_y_m_per_px=max(1e-4, res_y_m),
            target_resolution_m_per_px=0.05,
            crs=crs_str,
            transform_matrix=transform_matrix,
            sensor_name=sensor_name,
            extra_tags=tags,
        )

    return raw_arr, metadata


def parse_xtf(xtf_path: Union[str, Path]) -> Tuple[np.ndarray, SonarMetadata]:
    """
    Parses an eXtended Triton Format (XTF) side-scan sonar binary file.
    Reads file header, side-scan ping packets (XTFPINGHEADER), extracts tow altitude,
    slant range, GPS coordinates, heading, and builds the 2D waterfall image.
    
    Units:
        - Returned intensity: 2D numpy array [pings_along_track (rows), range_bins_cross_track (cols)] (float32)
        - Metadata fields: h_tow_m (meters), slant_range_max_m (meters), heading_deg (degrees),
          source_resolution (meters/pixel), crs ('EPSG:4326').
          
    Args:
        xtf_path: Path to the .xtf file.
        
    Returns:
        Tuple of (2D intensity array, SonarMetadata).
    """
    path = Path(xtf_path)
    file_size = path.stat().st_size
    
    pings: List[np.ndarray] = []
    altitudes: List[float] = []
    slant_ranges: List[float] = []
    headings: List[float] = []
    nav_xs: List[float] = []
    nav_ys: List[float] = []
    
    with open(path, "rb") as f:
        # Read XTF File Header (1024 bytes)
        file_header = f.read(1024)
        if len(file_header) < 1024:
            raise ValueError(f"XTF file is truncated: {xtf_path}")
        
        file_format = file_header[0]
        if file_format != 0x7B:  # Standard XTF FileFormat byte
            logger.warning(f"XTF FileFormat byte is 0x{file_format:02X} (expected 0x7B)")
            
        # Parse ping packets
        while f.tell() < file_size:
            packet_start = f.tell()
            # Read Packet Header (first 14 bytes: MagicNumber, HeaderType, SubChannelNumber, NumChansToFollow, ...)
            header_bytes = f.read(256)
            if len(header_bytes) < 256:
                break
                
            magic_number, header_type = struct.unpack("<HB", header_bytes[0:3])
            if magic_number != 0xFACE:
                # Seek to next byte to resynchronize if header corrupt
                f.seek(packet_start + 1)
                continue
                
            # HeaderType 0 = XTF_DATA_SIDESCAN_PING
            if header_type == 0:
                # Unpack XTFPINGHEADER fields (standard offsets)
                # Offset 38: SensorHeading (float, 4 bytes)
                sensor_heading = struct.unpack("<f", header_bytes[38:42])[0]
                # Offset 46: SensorPitch (float, 4 bytes)
                # Offset 54: SensorAltitude (float, 4 bytes) -> H_tow
                sensor_altitude = struct.unpack("<f", header_bytes[54:58])[0]
                # Offset 70: SensorXcoordinate / NavLongitude (double, 8 bytes)
                sensor_x = struct.unpack("<d", header_bytes[70:78])[0]
                # Offset 78: SensorYcoordinate / NavLatitude (double, 8 bytes)
                sensor_y = struct.unpack("<d", header_bytes[78:86])[0]
                # Offset 90: SlantRange (float, 4 bytes)
                slant_range = struct.unpack("<f", header_bytes[90:94])[0]
                # Offset 100: NumBytes (uint32, 4 bytes)
                num_bytes = struct.unpack("<I", header_bytes[100:104])[0]
                
                # Side-scan channel header (64 bytes per channel)
                # For Port & Starboard (2 channels):
                chan0_bytes = f.read(64)
                chan1_bytes = f.read(64)
                if len(chan0_bytes) < 64 or len(chan1_bytes) < 64:
                    break
                    
                # Channel 0 (Port) sample count: offset 10 in ChanHeader (uint32)
                num_samples_port = struct.unpack("<I", chan0_bytes[10:14])[0] if len(chan0_bytes) >= 14 else 1024
                # Channel 1 (Stbd) sample count: offset 10 in ChanHeader
                num_samples_stbd = struct.unpack("<I", chan1_bytes[10:14])[0] if len(chan1_bytes) >= 14 else 1024
                
                # Read sample data (8-bit or 16-bit)
                port_data = f.read(num_samples_port)
                stbd_data = f.read(num_samples_stbd)
                if len(port_data) < num_samples_port or len(stbd_data) < num_samples_stbd:
                    break
                    
                port_arr = np.frombuffer(port_data, dtype=np.uint8).astype(np.float32)
                stbd_arr = np.frombuffer(stbd_data, dtype=np.uint8).astype(np.float32)
                # In side-scan: Port scans outward to the left (reversed), Starboard to the right
                full_ping = np.concatenate([port_arr[::-1], stbd_arr])
                
                pings.append(full_ping)
                altitudes.append(max(0.1, float(sensor_altitude)))
                slant_ranges.append(max(1.0, float(slant_range)))
                headings.append(float(sensor_heading) % 360.0)
                nav_xs.append(float(sensor_x))
                nav_ys.append(float(sensor_y))
            else:
                # Other packet types (annotation, bathymetry, nav) - skip packet
                # Offset 100 has NumBytes in generic packet header
                num_bytes = struct.unpack("<I", header_bytes[100:104])[0] if len(header_bytes) >= 104 else 0
                if num_bytes > 256:
                    f.seek(packet_start + num_bytes)

    if not pings:
        raise ValueError(f"No valid side-scan ping packets found in XTF file: {xtf_path}")

    # Align ping array dimensions
    max_len = max(len(p) for p in pings)
    aligned_pings = [np.pad(p, (0, max_len - len(p)), mode="edge") if len(p) < max_len else p for p in pings]
    intensity = np.vstack(aligned_pings)
    
    rows, cols = intensity.shape
    h_tow_mean = float(np.mean(altitudes)) if altitudes else 10.0
    slant_range_mean = float(np.mean(slant_ranges)) if slant_ranges else 50.0
    heading_mean = float(np.mean(headings)) if headings else 0.0
    origin_x = float(nav_xs[0]) if nav_xs else 0.0
    origin_y = float(nav_ys[0]) if nav_ys else 0.0

    res_x = (2.0 * slant_range_mean) / cols
    res_y = res_x  # Typical nominal isotropic ping spacing

    transform_matrix = [res_x, 0.0, origin_x, 0.0, -res_y, origin_y]

    metadata = SonarMetadata(
        h_tow_m=max(0.5, h_tow_mean),
        slant_range_max_m=max(5.0, slant_range_mean),
        origin_lon=origin_x,
        origin_lat=origin_y,
        heading_deg=heading_mean,
        source_resolution_x_m_per_px=max(1e-4, res_x),
        source_resolution_y_m_per_px=max(1e-4, res_y),
        target_resolution_m_per_px=0.05,
        crs="EPSG:4326",
        transform_matrix=transform_matrix,
        sensor_name="XTF-SideScan",
        extra_tags={"ping_count": len(pings), "samples_per_ping": cols},
    )

    return intensity, metadata


# ---------------------------------------------------------------------------
# Metric Resampling & Georeferencing
# ---------------------------------------------------------------------------

def resample_sonar_frame(
    intensity: np.ndarray,
    metadata: SonarMetadata,
    target_resolution_m_per_px: float = 0.05,
    target_crs: Optional[str] = None,
) -> SonarFrame:
    """
    Resamples a raw side-scan sonar image array to a standardized metric resolution
    (default 0.05 meters/pixel) using bicubic interpolation, while scaling and updating
    the georeferencing Affine transform matrix and CRS.
    
    Units:
        - intensity: input 2D numpy array [rows, cols] (float32)
        - target_resolution_m_per_px: target physical pixel size in meters/pixel
        - Affine transform: converts pixel (px, py) to metric or geographic coordinates
        
    Args:
        intensity: Raw 2D sonar intensity array.
        metadata: SonarMetadata associated with the raw frame.
        target_resolution_m_per_px: Desired metric resolution (m/px). Default = 0.05 m/px (5 cm/px).
        target_crs: Desired projected CRS (e.g. 'EPSG:32630'). If provided and different from
                    metadata.crs, reprojects origin coordinates.
                    
    Returns:
        SonarFrame containing resampled intensity, valid mask, and updated SonarMetadata.
    """
    orig_rows, orig_cols = intensity.shape
    src_res_x = float(metadata.source_resolution_x_m_per_px)
    src_res_y = float(metadata.source_resolution_y_m_per_px)
    tgt_res = float(target_resolution_m_per_px)

    # Compute target dimensions in pixels
    new_cols = max(1, int(round(orig_cols * (src_res_x / tgt_res))))
    new_rows = max(1, int(round(orig_rows * (src_res_y / tgt_res))))

    # Resample intensity using high-fidelity bicubic interpolation
    resampled_intensity = cv2.resize(
        intensity,
        (new_cols, new_rows),
        interpolation=cv2.INTER_CUBIC,
    ).astype(np.float32)

    # Scale factors
    scale_x = new_cols / float(orig_cols)
    scale_y = new_rows / float(orig_rows)

    # Update Affine transform matrix: [a', b', c', d', e', f']
    # If source transform is [a, b, c, d, e, f], scaling pixels by scale_x, scale_y gives:
    # a' = a / scale_x, e' = e / scale_y (so step per pixel scales down to target resolution)
    current_transform = metadata.transform_matrix or [src_res_x, 0.0, metadata.origin_lon, 0.0, -src_res_y, metadata.origin_lat]
    a, b, c, d, e, f = current_transform
    new_transform = [
        a / scale_x,
        b / scale_x,
        c,
        d / scale_y,
        e / scale_y,
        f,
    ]

    out_crs = metadata.crs
    origin_lon = metadata.origin_lon
    origin_lat = metadata.origin_lat

    # Reproject origin if target_crs requested
    if target_crs and target_crs != metadata.crs:
        try:
            transformer = pyproj.Transformer.from_crs(metadata.crs, target_crs, always_xy=True)
            new_x, new_y = transformer.transform(origin_lon, origin_lat)
            origin_lon, origin_lat = new_x, new_y
            out_crs = target_crs
            # In metric projected CRS, pixel spacing is exact target_res
            new_transform = [tgt_res, 0.0, new_x, 0.0, -tgt_res, new_y]
        except Exception as ex:
            logger.warning(f"Failed to reproject CRS from {metadata.crs} to {target_crs}: {ex}")

    updated_metadata = SonarMetadata(
        h_tow_m=metadata.h_tow_m,
        slant_range_max_m=metadata.slant_range_max_m,
        origin_lon=origin_lon,
        origin_lat=origin_lat,
        heading_deg=metadata.heading_deg,
        source_resolution_x_m_per_px=src_res_x,
        source_resolution_y_m_per_px=src_res_y,
        target_resolution_m_per_px=tgt_res,
        crs=out_crs,
        transform_matrix=new_transform,
        sensor_name=metadata.sensor_name,
        extra_tags=metadata.extra_tags,
    )

    valid_mask = np.ones((new_rows, new_cols), dtype=bool)

    return SonarFrame(
        intensity=resampled_intensity,
        valid_mask=valid_mask,
        metadata=updated_metadata,
        dropout_spans=[],
    )


# ---------------------------------------------------------------------------
# Unified Ingestion Interface
# ---------------------------------------------------------------------------

def load_sonar_file(
    file_path: Union[str, Path],
    json_sidecar_path: Optional[Union[str, Path]] = None,
    target_resolution_m_per_px: float = 0.05,
    target_crs: Optional[str] = None,
) -> SonarFrame:
    """
    Unified entry point for loading and standardizing any side-scan sonar file.
    Downstream pipeline stages receive a consistent, metric-resampled SonarFrame.
    
    Args:
        file_path: Path to raw sonar file (XTF, GeoTIFF, PNG, NPY).
        json_sidecar_path: Optional path to JSON metadata sidecar.
        target_resolution_m_per_px: Target metric resolution in meters/pixel (default 0.05).
        target_crs: Target coordinate reference system (e.g. 'EPSG:32630').
        
    Returns:
        Standardized SonarFrame.
    """
    fmt = detect_format(file_path)
    logger.info(f"Ingesting sonar file: {file_path} (Detected format: {fmt.value})")

    if fmt == SonarFormat.XTF:
        raw_arr, metadata = parse_xtf(file_path)
    elif fmt == SonarFormat.GEOTIFF:
        raw_arr, metadata = parse_geotiff(file_path)
    elif fmt in [SonarFormat.PNG_JSON, SonarFormat.NPY_JSON]:
        raw_arr, metadata = parse_png_npy_with_json(file_path, json_sidecar_path)
    else:
        raise ValueError(f"Unsupported format handler for: {fmt}")

    frame = resample_sonar_frame(
        intensity=raw_arr,
        metadata=metadata,
        target_resolution_m_per_px=target_resolution_m_per_px,
        target_crs=target_crs,
    )
    
    logger.info(
        f"Ingestion complete: raw shape {raw_arr.shape} -> resampled shape {frame.intensity.shape} "
        f"at {target_resolution_m_per_px} m/px. H_tow = {frame.metadata.h_tow_m:.2f}m, "
        f"Slant Range = {frame.metadata.slant_range_max_m:.2f}m"
    )
    return frame
