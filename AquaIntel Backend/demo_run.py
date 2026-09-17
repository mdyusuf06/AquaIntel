"""
AquaIntel Sonar Pipeline — Quickstart Demo Script
Problem Statement 26057 | Team Brainwave | SIH 2026

Runs an end-to-end demonstration:
1. Synthesizes a realistic side-scan sonar waterfall with an acoustic anomaly.
2. Executes Step 0 Ingestion -> Step 1 Preprocessing -> Step 2 Physics Extraction.
3. Prints the recovered physical metrics (true height, shadow length, slant range, Haralick texture).
4. Exports structured features to 'output_features.json'.
"""

import json
from pathlib import Path
import cv2
import numpy as np

from sonar_pipeline import PipelineConfig, SonarPipeline


def main():
    print("=" * 70)
    print("   AquaIntel - Sonar Pipeline End-to-End Demonstration")
    print("=" * 70)

    demo_dir = Path("demo_output")
    demo_dir.mkdir(exist_ok=True)

    # 1. Synthesize a side-scan sonar survey line (200 pings x 400 range bins)
    print("\n[+] Synthesizing side-scan sonar waterfall image...")
    res_m = 0.05  # 0.05 m/pixel metric resolution
    h_tow_m = 10.0  # 10m tow altitude above seafloor
    
    # Seafloor background intensity + speckle
    intensity = np.ones((200, 400), dtype=np.float32) * 110.0
    speckle = np.random.uniform(0.85, 1.15, size=(200, 400)).astype(np.float32)
    intensity = intensity * speckle

    # Injected Underwater Debris Object (Starboard side at col 300; Nadir is col 200)
    # Slant range R = (300 - 200) * 0.05 = 5.0m
    # Highlight: rows 70:86, cols 300:306 -> Bright reflection (245.0)
    intensity[70:86, 300:306] = 245.0
    # Acoustic Shadow: rows 70:86, cols 306:346 (length = 40 px * 0.05 = 2.0m) -> Dark shadow (5.0)
    intensity[70:86, 306:346] = 5.0
    # Expected Physics Height: Height = H_tow * (L_shadow / R) = 10.0 * (2.0 / 5.0) = 4.0 meters

    # Motion Dropout Anomaly:
    # 2-row short dropout at rows 20:22 (linear 1D interpolated)
    intensity[20:22, :] = 0.0
    # 5-row severe dropout at rows 140:145 (masked as non-surveyable)
    intensity[140:145, :] = 0.0

    img_path = demo_dir / "synthetic_sonar_survey.png"
    json_path = demo_dir / "synthetic_sonar_survey.json"

    cv2.imwrite(str(img_path), np.clip(intensity, 0, 255).astype(np.uint8))
    meta_dict = {
        "h_tow_m": h_tow_m,
        "slant_range_max_m": 20.0,
        "origin_lon": 500000.0,
        "origin_lat": 5600000.0,
        "heading_deg": 90.0,
        "source_resolution_x_m_per_px": 0.05,
        "source_resolution_y_m_per_px": 0.05,
        "target_resolution_m_per_px": 0.05,
        "crs": "EPSG:32630",
        "sensor_name": "AquaIntel-Towfish-Sim",
    }
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(meta_dict, f, indent=2)

    print(f"    Saved raw sonar image to: {img_path}")
    print(f"    Saved metadata sidecar to: {json_path}")

    # 2. Configure and execute pipeline
    print("\n[+] Initializing SonarPipeline...")
    cfg = PipelineConfig(
        target_resolution_m_per_px=0.05,
        denoise_method="lee",
        lee_window_size=7,
        dropout_max_interp_rows=3,
        shadow_thresh_percentile=15.0,
        highlight_thresh_percentile=85.0,
        min_shadow_area_px=15,
        min_highlight_area_px=10,
    )
    pipeline = SonarPipeline(config=cfg)

    print("[+] Processing sonar survey file end-to-end...")
    result = pipeline.process(file_path=img_path, json_sidecar_path=json_path)

    # 3. Print Results
    print("\n" + "=" * 70)
    print("   PIPELINE EXECUTION SUMMARY")
    print("=" * 70)
    print(f"Execution Time:          {result.execution_time_s:.3f} seconds")
    print(f"Preprocessed Frame Size: {result.frame.intensity.shape[0]} pings x {result.frame.intensity.shape[1]} range bins")
    print(f"Short Dropouts Repaired: {result.num_dropouts_interpolated} span(s) (1D linear interpolated)")
    print(f"Severe Dropouts Masked:  {result.num_dropouts_masked} span(s) (marked non-surveyable)")
    print(f"Objects Detected:        {result.num_objects_detected}")

    print("\n[+] Extracted Physical Feature Records:")
    for obj in result.features:
        print(f"\n  --- Object ID: {obj.object_id} ---")
        print(f"  * Slant Range (R):        {obj.slant_range_m:.2f} m")
        print(f"  * Acoustic Shadow Length: {obj.shadow_length_m:.2f} m")
        print(f"  * Computed True Height:   {obj.computed_height_m:.2f} m  [Expected: ~4.00 m]")
        print(f"  * Shadow Area:            {obj.shadow_area_m2:.3f} m^2")
        print(f"  * Highlight Area:         {obj.highlight_area_m2:.3f} m^2")
        print(f"  * Highlight/Shadow Ratio: {obj.highlight_to_shadow_ratio:.3f}")
        print(f"  * Principal Orientation:  {obj.principal_axis_orientation_deg:.1f} deg")
        print(f"  * Georeferenced Origin:   {obj.center_geo}")
        print(f"  * Haralick Contrast:      {obj.haralick_features.contrast:.4f}")
        print(f"  * Haralick Homogeneity:   {obj.haralick_features.homogeneity:.4f}")
        print(f"  * Physics Sanity Valid:   {obj.is_valid_physics}")
        print(f"  * Detection Confidence:   {obj.confidence:.2f}")

    # 4. Export JSON
    out_json = demo_dir / "extracted_features.json"
    pipeline.export_features_json(result.features, out_json)
    print(f"\n[+] Exported feature records to: {out_json}")
    print("\nAudit Provenance Log:")
    for log_entry in result.provenance_log:
        print(f"  - {log_entry}")
    print("\nDemo completed successfully!")


if __name__ == "__main__":
    main()
