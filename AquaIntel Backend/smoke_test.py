# -*- coding: utf-8 -*-
import sys, numpy as np

def run_smoke_test():
    print('AquaIntel Pipeline Smoke Test')
    print('=' * 50)
    try:
        from sonar_pipeline.schemas import SonarMetadata, SonarFrame, PipelineConfig
        from sonar_pipeline.preprocessing import preprocess_sonar_frame
        from sonar_pipeline.physics import extract_physics_features
        rng = np.random.default_rng(42)
        intensity = rng.uniform(30, 100, (200, 400)).astype(np.float32)
        intensity[90:110, 160:175] = 220.0
        intensity[90:110, 175:200] = 10.0
        valid_mask = np.ones((200, 400), dtype=bool)
        meta = SonarMetadata(h_tow_m=12.0, slant_range_max_m=50.0, origin_lon=12.568, origin_lat=55.676, heading_deg=90.0, source_resolution_x_m_per_px=0.05, source_resolution_y_m_per_px=0.05, target_resolution_m_per_px=0.05)
        frame = SonarFrame(intensity=intensity, valid_mask=valid_mask, metadata=meta)
        print(f'[STEP 0] SonarFrame: {frame.intensity.shape}')
        cfg = PipelineConfig()
        pp_frame = preprocess_sonar_frame(frame, cfg)
        print(f'[STEP 1] Preprocessed: {pp_frame.intensity.shape}, dropouts={len(pp_frame.dropout_spans)}')
        features = extract_physics_features(pp_frame, cfg)
        print(f'[STEP 2] Features: {len(features)} objects')
        for f in features:
            print(f'  {f.object_id}: height={f.computed_height_m:.3f}m shadow={f.shadow_length_m:.3f}m conf={f.confidence:.3f}')
        from physics_extractor import extract_physics_vector, extract_physics_vector_from_frame
        crop = intensity[90:110, 160:200].astype(np.float32)
        vec = extract_physics_vector(crop)
        print(f'[BRIDGE] crop 5-vec: {[round(v,4) for v in vec]}')
        vec2 = extract_physics_vector_from_frame(pp_frame)
        print(f'[BRIDGE] frame 5-vec: {[round(v,4) for v in vec2]}')
        print('[PASS] All tests passed!')
        return True
    except Exception as e:
        import traceback; traceback.print_exc()
        return False

if __name__ == '__main__':
    sys.exit(0 if run_smoke_test() else 1)
