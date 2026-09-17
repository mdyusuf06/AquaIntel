"""
AquaIntel Sonar Pipeline — End-to-End Orchestrator
Problem Statement 26057 | Team Brainwave | SIH 2026

Orchestrates Step 0 (Ingestion & Georeferencing), Step 1 (Preprocessing & Motion Dropout
Correction), and Step 2 (Physics-Based Feature Extraction) into a cohesive, offline-first
pipeline ready for edge deployment.
"""

from __future__ import annotations
import json
import logging
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import numpy as np

from sonar_pipeline.ingestion import load_sonar_file
from sonar_pipeline.physics import extract_physics_features
from sonar_pipeline.preprocessing import preprocess_sonar_frame
from sonar_pipeline.schemas import (
    PipelineConfig,
    PipelineResult,
    SonarFrame,
    SonarObjectFeature,
)

logger = logging.getLogger(__name__)


class SonarPipeline:
    """
    Main pipeline orchestrator for AquaIntel Part 1.
    
    Transforms raw side-scan sonar files (XTF, GeoTIFF, PNG/NPY+JSON) into clean,
    georeferenced, physics-measured feature records.
    """

    def __init__(self, config: Optional[PipelineConfig] = None):
        """
        Initializes the sonar pipeline with user configuration or default parameters.
        
        Args:
            config: Optional PipelineConfig.
        """
        self.config = config or PipelineConfig()
        logger.info(
            f"Initialized AquaIntel SonarPipeline with resolution={self.config.target_resolution_m_per_px}m/px, "
            f"denoise_method={self.config.denoise_method}"
        )

    def ingest(
        self,
        file_path: Union[str, Path],
        json_sidecar_path: Optional[Union[str, Path]] = None,
    ) -> SonarFrame:
        """
        Step 0: Ingests raw file, parses acoustic metadata, and resamples to metric resolution.
        
        Args:
            file_path: Path to raw sonar file.
            json_sidecar_path: Optional path to JSON sidecar.
            
        Returns:
            SonarFrame.
        """
        return load_sonar_file(
            file_path=file_path,
            json_sidecar_path=json_sidecar_path,
            target_resolution_m_per_px=self.config.target_resolution_m_per_px,
            target_crs=self.config.target_crs,
        )

    def preprocess(self, frame: SonarFrame) -> SonarFrame:
        """
        Step 1: Scans/corrects motion dropouts and applies adaptive speckle denoising.
        
        Args:
            frame: Ingested SonarFrame.
            
        Returns:
            Preprocessed SonarFrame.
        """
        return preprocess_sonar_frame(frame, self.config)

    def extract_features(self, frame: SonarFrame) -> List[SonarObjectFeature]:
        """
        Step 2: Detects highlight-shadow pairs and computes acoustic geometry metrics.
        
        Args:
            frame: Preprocessed SonarFrame.
            
        Returns:
            List of SonarObjectFeature records.
        """
        return extract_physics_features(frame, self.config)

    def process(
        self,
        file_path: Union[str, Path],
        json_sidecar_path: Optional[Union[str, Path]] = None,
    ) -> PipelineResult:
        """
        Executes end-to-end processing: Ingestion -> Preprocessing -> Physics Feature Extraction.
        
        Args:
            file_path: Path to raw sonar file.
            json_sidecar_path: Optional path to JSON sidecar.
            
        Returns:
            PipelineResult containing preprocessed frame, extracted features, and provenance.
        """
        start_time = time.perf_counter()
        provenance: List[str] = []

        path_obj = Path(file_path)
        provenance.append(f"Ingested file: {path_obj.name}")

        # Step 0: Ingestion
        t0 = time.perf_counter()
        frame = self.ingest(file_path, json_sidecar_path)
        t_ingest = time.perf_counter() - t0
        provenance.append(
            f"Step 0 Ingestion: shape={frame.intensity.shape}, "
            f"H_tow={frame.metadata.h_tow_m:.2f}m, SlantRange={frame.metadata.slant_range_max_m:.2f}m ({t_ingest:.3f}s)"
        )

        # Step 1: Preprocessing
        t1 = time.perf_counter()
        preprocessed_frame = self.preprocess(frame)
        t_prep = time.perf_counter() - t1

        num_interp = sum(1 for s in preprocessed_frame.dropout_spans if s.action == "interpolated")
        num_masked = sum(1 for s in preprocessed_frame.dropout_spans if s.action == "masked_non_surveyable")
        provenance.append(
            f"Step 1 Preprocessing: Denoised ({self.config.denoise_method}), "
            f"Dropouts (interpolated={num_interp}, masked={num_masked}) ({t_prep:.3f}s)"
        )

        # Step 2: Physics Feature Extraction
        t2 = time.perf_counter()
        features = self.extract_features(preprocessed_frame)
        t_feat = time.perf_counter() - t2
        provenance.append(
            f"Step 2 Physics: Extracted {len(features)} acoustic shadow object records ({t_feat:.3f}s)"
        )

        total_time = time.perf_counter() - start_time
        provenance.append(f"Pipeline execution completed in {total_time:.3f}s")

        return PipelineResult(
            frame=preprocessed_frame,
            features=features,
            num_objects_detected=len(features),
            num_dropouts_interpolated=num_interp,
            num_dropouts_masked=num_masked,
            execution_time_s=round(total_time, 4),
            provenance_log=provenance,
        )

    def export_features_json(
        self,
        features: List[SonarObjectFeature],
        output_path: Union[str, Path],
    ) -> None:
        """
        Exports extracted object feature records to a JSON file for downstream retrieval stages.
        
        Args:
            features: List of SonarObjectFeature records.
            output_path: Path to destination JSON file.
        """
        out_data = [feat.model_dump() for feat in features]
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(out_data, f, indent=2)
        logger.info(f"Exported {len(features)} feature records to {output_path}")
