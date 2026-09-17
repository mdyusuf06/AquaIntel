"""
AquaIntel Sonar Pipeline — Data Schemas & Configurations
Problem Statement 26057 | Team Brainwave | SIH 2026

Defines the core data contracts, Pydantic models, and configuration containers
used across the ingestion, preprocessing, and physics feature extraction engine.
All units are explicitly defined and enforced in metadata and models.
"""

from __future__ import annotations
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple
import numpy as np
from pydantic import BaseModel, ConfigDict, Field, field_validator


class SonarFormat(str, Enum):
    """Supported side-scan sonar input formats."""
    XTF = "xtf"
    GEOTIFF = "geotiff"
    PNG_JSON = "png_json"
    NPY_JSON = "npy_json"
    SYNTHETIC = "synthetic"


class SonarMetadata(BaseModel):
    """
    Metadata representation for a side-scan sonar waterfall or survey record.
    
    Units:
      - h_tow_m: meters (tow altitude above seabed)
      - slant_range_max_m: meters (maximum slant range per channel)
      - origin_lon: degrees / projected easting (GPS longitude or CRS X origin)
      - origin_lat: degrees / projected northing (GPS latitude or CRS Y origin)
      - heading_deg: degrees (survey heading relative to True North, 0.0-360.0)
      - source_resolution_x_m_per_px: meters/pixel (cross-track resolution)
      - source_resolution_y_m_per_px: meters/pixel (along-track resolution)
      - target_resolution_m_per_px: meters/pixel (resampled resolution, default 0.05)
      - crs: Coordinate Reference System string (e.g., 'EPSG:4326', 'EPSG:32630')
      - transform_matrix: List[float] (6-element affine transform [a, b, c, d, e, f])
    """
    model_config = ConfigDict(arbitrary_types_allowed=True)

    h_tow_m: float = Field(..., gt=0.0, description="Tow altitude above seabed in meters")
    slant_range_max_m: float = Field(..., gt=0.0, description="Maximum slant range in meters")
    origin_lon: float = Field(default=0.0, description="GPS longitude or projected Easting at ping 0")
    origin_lat: float = Field(default=0.0, description="GPS latitude or projected Northing at ping 0")
    heading_deg: float = Field(default=0.0, ge=0.0, le=360.0, description="Towfish heading in degrees")
    source_resolution_x_m_per_px: float = Field(..., gt=0.0, description="Cross-track resolution in meters/pixel")
    source_resolution_y_m_per_px: float = Field(..., gt=0.0, description="Along-track resolution in meters/pixel")
    target_resolution_m_per_px: float = Field(default=0.05, gt=0.0, description="Target resampled metric resolution in meters/pixel")
    crs: str = Field(default="EPSG:4326", description="Coordinate reference system (e.g. EPSG:4326, EPSG:32630)")
    transform_matrix: Optional[List[float]] = Field(
        default=None,
        description="Affine georeferencing matrix [a, b, c, d, e, f] where X = a*px + b*py + c, Y = d*px + e*py + f"
    )
    sensor_name: Optional[str] = Field(default="GenericSideScan", description="Sensor identifier or model")
    extra_tags: Dict[str, Any] = Field(default_factory=dict, description="Raw format-specific tags and headers")


class DropoutSpan(BaseModel):
    """
    Record of a detected cross-ping motion dropout or missing data span.
    
    Units:
      - start_row: pixel index (ping number along-track)
      - end_row: pixel index (ping number along-track, inclusive)
      - length_rows: number of pings (rows)
    """
    start_row: int = Field(..., ge=0, description="Start ping row index (0-based)")
    end_row: int = Field(..., ge=0, description="End ping row index (inclusive)")
    length_rows: int = Field(..., gt=0, description="Number of contiguous dropped ping rows")
    action: str = Field(..., description="'interpolated' (gap <= 3) or 'masked_non_surveyable' (gap > 3)")
    reason: str = Field(..., description="Dropout trigger: 'zero_intensity', 'variance_drop', 'heave_roll'")


class SonarFrame(BaseModel):
    """
    Unified container holding 2D sonar waterfall array, validity mask, metadata, and dropout history.
    
    Dimensions:
      - intensity: 2D numpy array [pings_along_track (rows), range_bins_cross_track (cols)]
      - valid_mask: 2D boolean array [rows, cols] (True = surveyable/valid, False = non-surveyable)
    """
    model_config = ConfigDict(arbitrary_types_allowed=True)

    intensity: np.ndarray = Field(..., description="2D sonar intensity array (float32, normalized 0.0 to 1.0 or uint8)")
    valid_mask: np.ndarray = Field(..., description="2D boolean mask indicating surveyable valid pixels")
    metadata: SonarMetadata = Field(..., description="Georeferencing and acoustic sensor metadata")
    dropout_spans: List[DropoutSpan] = Field(default_factory=list, description="Detected dropout anomalies")

    @field_validator("intensity", mode="before")
    def validate_intensity_array(cls, v: Any) -> np.ndarray:
        if not isinstance(v, np.ndarray):
            v = np.asarray(v, dtype=np.float32)
        if v.ndim != 2:
            raise ValueError(f"Intensity array must be 2D [rows, cols], got shape {v.shape}")
        return v.astype(np.float32)

    @field_validator("valid_mask", mode="before")
    def validate_mask_array(cls, v: Any, info: Any) -> np.ndarray:
        if not isinstance(v, np.ndarray):
            v = np.asarray(v, dtype=bool)
        if v.ndim != 2:
            raise ValueError(f"Valid mask array must be 2D [rows, cols], got shape {v.shape}")
        return v.astype(bool)


class HaralickFeatures(BaseModel):
    """
    Gray-Level Co-occurrence Matrix (GLCM) Haralick texture descriptors.
    Computed on the acoustic highlight/shadow region of interest.
    """
    contrast: float = Field(..., description="Intensity contrast between neighboring pixels")
    dissimilarity: float = Field(..., description="Linear difference in gray levels")
    homogeneity: float = Field(..., description="Closeness of GLCM element distribution to diagonal")
    energy: float = Field(..., description="Uniformity / square root of ASM")
    correlation: float = Field(..., description="Linear dependency of gray levels")
    asm: float = Field(..., description="Angular Second Moment / textural energy")


class SonarObjectFeature(BaseModel):
    """
    Structured physical and geometric feature record for a detected marine debris anomaly.
    Directly ingestible by downstream vector embedding and retrieval stages.
    
    Units:
      - bbox_px: (xmin, ymin, xmax, ymax) in pixels
      - center_px: (x, y) in pixels
      - center_geo: (lon / easting, lat / northing) in CRS units (degrees or meters)
      - slant_range_m: meters (acoustic slant range from nadir trackline to object)
      - shadow_length_m: meters (measured acoustic shadow length along range direction)
      - computed_height_m: meters (true physical height from shadow geometry)
      - shadow_area_m2: square meters
      - highlight_area_m2: square meters
      - highlight_to_shadow_ratio: unitless
      - principal_axis_orientation_deg: degrees [0.0, 180.0) relative to range axis
      - confidence: unitless [0.0, 1.0]
    """
    object_id: str = Field(..., description="Unique anomaly identifier (e.g. 'obj_001')")
    bbox_px: Tuple[int, int, int, int] = Field(..., description="(xmin, ymin, xmax, ymax) bounding box in resampled pixels")
    center_px: Tuple[float, float] = Field(..., description="(x, y) centroid in resampled pixel coordinates")
    center_geo: Tuple[float, float] = Field(..., description="(X, Y) georeferenced coordinate (lon/lat or easting/northing)")
    slant_range_m: float = Field(..., gt=0.0, description="Slant range R from sensor nadir in meters")
    shadow_length_m: float = Field(..., ge=0.0, description="Acoustic shadow length L_shadow in meters")
    computed_height_m: float = Field(..., ge=0.0, description="Physical object height in meters: H_tow * (L_shadow / R)")
    shadow_area_m2: float = Field(..., ge=0.0, description="Total acoustic shadow area in square meters")
    highlight_area_m2: float = Field(..., ge=0.0, description="Total acoustic highlight area in square meters")
    highlight_to_shadow_ratio: float = Field(..., ge=0.0, description="Ratio of highlight area to shadow area")
    principal_axis_orientation_deg: float = Field(..., ge=0.0, le=180.0, description="Principal orientation in degrees [0, 180)")
    haralick_features: HaralickFeatures = Field(..., description="GLCM texture metrics")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Detection confidence score")
    is_valid_physics: bool = Field(default=True, description="True if geometry passes physical validity sanity checks")
    notes: str = Field(default="", description="Provenance notes, dropout warnings, or quality flags")


class PipelineConfig(BaseModel):
    """Configuration parameters for the end-to-end sonar processing pipeline."""
    target_resolution_m_per_px: float = Field(default=0.05, gt=0.0, description="Standardized metric resolution in m/px")
    denoise_method: str = Field(default="lee", description="'lee' (Adaptive Lee filter) or 'bilateral'")
    lee_window_size: int = Field(default=7, ge=3, description="Kernel window size for Adaptive Lee filter (must be odd)")
    lee_noise_var: Optional[float] = Field(default=None, description="Assumed noise variance (auto-estimated if None)")
    bilateral_d: int = Field(default=7, ge=1, description="Diameter of pixel neighborhood for bilateral filter")
    bilateral_sigma_color: float = Field(default=50.0, gt=0.0, description="Bilateral filter color space sigma")
    bilateral_sigma_space: float = Field(default=50.0, gt=0.0, description="Bilateral filter coordinate space sigma")
    
    # Motion dropout thresholds
    dropout_max_interp_rows: int = Field(default=3, ge=1, description="Maximum contiguous dropped rows to interpolate")
    dropout_intensity_thresh: float = Field(default=1.5, ge=0.0, description="Threshold below which row mean indicates missing ping")
    dropout_var_ratio_thresh: float = Field(default=0.05, gt=0.0, description="Minimum ratio of row variance to mean variance")
    
    # Physics feature extraction thresholds
    shadow_thresh_percentile: float = Field(default=15.0, ge=0.0, le=50.0, description="Intensity percentile for shadow mask")
    highlight_thresh_percentile: float = Field(default=85.0, ge=50.0, le=100.0, description="Intensity percentile for highlight mask")
    min_shadow_area_px: int = Field(default=15, ge=1, description="Minimum pixel count for valid acoustic shadow")
    min_highlight_area_px: int = Field(default=10, ge=1, description="Minimum pixel count for valid acoustic highlight")
    target_crs: str = Field(default="EPSG:32630", description="Target projected CRS for metric georeferencing")


class PipelineResult(BaseModel):
    """Final output container from the end-to-end sonar processing pipeline."""
    model_config = ConfigDict(arbitrary_types_allowed=True)

    frame: SonarFrame = Field(..., description="Preprocessed sonar frame with validity mask")
    features: List[SonarObjectFeature] = Field(default_factory=list, description="Extracted physical feature records")
    num_objects_detected: int = Field(default=0, ge=0)
    num_dropouts_interpolated: int = Field(default=0, ge=0)
    num_dropouts_masked: int = Field(default=0, ge=0)
    execution_time_s: float = Field(default=0.0, ge=0.0)
    provenance_log: List[str] = Field(default_factory=list)
