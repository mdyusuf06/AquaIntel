"""
AquaIntel Sonar Pipeline — Core Package
Problem Statement 26057 | Team Brainwave | SIH 2026

Physics-based, retrieval-driven underwater marine debris and anomaly detection
system using side-scan sonar imagery.
"""

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
from sonar_pipeline.ingestion import (
    detect_format,
    load_sonar_file,
    parse_geotiff,
    parse_png_npy_with_json,
    parse_xtf,
    resample_sonar_frame,
)
from sonar_pipeline.preprocessing import (
    adaptive_lee_filter,
    bilateral_filter_sonar,
    detect_and_correct_dropouts,
    preprocess_sonar_frame,
)
from sonar_pipeline.physics import (
    compute_acoustic_shadow_height,
    compute_haralick_texture,
    compute_principal_axis_orientation,
    extract_physics_features,
)
from sonar_pipeline.pipeline import SonarPipeline

__version__ = "0.1.0"
__all__ = [
    "SonarFormat",
    "SonarMetadata",
    "SonarFrame",
    "DropoutSpan",
    "HaralickFeatures",
    "SonarObjectFeature",
    "PipelineConfig",
    "PipelineResult",
    "detect_format",
    "load_sonar_file",
    "parse_geotiff",
    "parse_png_npy_with_json",
    "parse_xtf",
    "resample_sonar_frame",
    "adaptive_lee_filter",
    "bilateral_filter_sonar",
    "detect_and_correct_dropouts",
    "preprocess_sonar_frame",
    "compute_acoustic_shadow_height",
    "compute_haralick_texture",
    "compute_principal_axis_orientation",
    "extract_physics_features",
    "SonarPipeline",
]
