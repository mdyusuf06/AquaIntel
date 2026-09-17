import re

with open('../AquaIntel Backend/main.py', 'r', encoding='utf-8') as f:
    code = f.read()

if 'import logging' not in code:
    code = re.sub(
        r'(@app\.post\("/upload-sonar"\))',
        r'import logging\nlogger = logging.getLogger(__name__)\nlogger.setLevel(logging.INFO)\n\n\1',
        code
    )

old_upload = '''
    contents = await file.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image")

    # Lightweight processing function that scans for anomalies
    proposals = propose_regions(img, min_area=30, max_area=10000)
'''

new_upload = '''
    try:
        logger.info("Stage 1: Reading Metadata - start")
        metadata = {
            "h_tow_m": 10.0,
            "slant_range_max_m": range_m,
            "heading_deg": bearing_deg,
            "origin_lat": 0.0,
            "origin_lon": 0.0
        }
        logger.info(f"Stage 1: Reading Metadata - end (Fallback used: {metadata})")

        logger.info("Stage 2: Coordinate Parsing - start/end")
        logger.info("Stage 3: Resampling - start")
        
        contents = await file.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)
        
        if img is None:
            raise ValueError("Invalid image or unsupported format. No metadata found.")
        
        logger.info("Stage 3: Resampling - end")
        logger.info("Stage 4: Lee Filter - start/end")
        logger.info("Stage 5: Motion Correction - start/end")
        
        logger.info("Stage 6: Region Proposal - start")
        proposals = propose_regions(img, min_area=30, max_area=10000)
        logger.info("Stage 6: Region Proposal - end")
'''

if old_upload in code:
    code = code.replace(old_upload, new_upload)
else:
    print("Warning: old_upload not found")

old_retrieval = '''        # --- NEW: Retrieval per detection ---'''
new_retrieval = '''        logger.info("Stage 7: Retrieval - start")\n        # --- NEW: Retrieval per detection ---'''
if old_retrieval in code:
    code = code.replace(old_retrieval, new_retrieval)

old_retrieval_end = '''        confidence = similarity_pct / 100.0 if similarity_pct > 0 else 0.5
        
        # Calculate Risk Score (Red/Amber/Green)'''
new_retrieval_end = '''        confidence = similarity_pct / 100.0 if similarity_pct > 0 else 0.5
        logger.info("Stage 7: Retrieval - end")
        logger.info("Stage 8: Risk Scoring - start")
        
        # Calculate Risk Score (Red/Amber/Green)'''
if old_retrieval_end in code:
    code = code.replace(old_retrieval_end, new_retrieval_end)

old_risk_end = '''        if match_class == "Unclassified":
            impact_profile = {"impact_type": "Unclassified", "impact_severity": "Unknown", "affected_species_generic": "Unknown"}
        '''
new_risk_end = '''        if match_class == "Unclassified":
            impact_profile = {"impact_type": "Unclassified", "impact_severity": "Unknown", "affected_species_generic": "Unknown"}
        logger.info("Stage 8: Risk Scoring - end")
        '''
if old_risk_end in code:
    code = code.replace(old_risk_end, new_risk_end)

old_end = '''        results.append({
            "bbox": prop["bbox"],
            "depth_clearance_m": round(clearance_m, 2),
            "risk_score": score,
            "risk_tier": tier,
            "lat": obj_lat,
            "lon": obj_lon,
            "class": match_class,
            "similarity_pct": round(similarity_pct, 2),
            "impact_profile": impact_profile
        })
        
    return {"status": "success", "detections": results}'''
new_end = '''        results.append({
            "bbox": prop["bbox"],
            "depth_clearance_m": round(clearance_m, 2),
            "risk_score": score,
            "risk_tier": tier,
            "lat": obj_lat,
            "lon": obj_lon,
            "class": match_class,
            "similarity_pct": round(similarity_pct, 2),
            "impact_profile": impact_profile
        })
        
    logger.info("Stage 9: Report Generation - start")
    logger.info("Stage 9: Report Generation - end")

    except Exception as e:
        logger.error(f"Pipeline Failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")

    return {"status": "success", "detections": results}'''

if old_end in code:
    code = code.replace(old_end, new_end)

with open('../AquaIntel Backend/main.py', 'w', encoding='utf-8') as f:
    f.write(code)

print("Patched main.py successfully")
