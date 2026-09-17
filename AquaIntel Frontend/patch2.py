import re

with open('../AquaIntel Backend/main.py', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Auto-create survey
old_survey = '''        survey = database.get_survey(survey_id) if survey_id else None
        base_lat = survey["origin_lat"] if survey else 0.0
        base_lon = survey["origin_lon"] if survey else 0.0'''

new_survey = '''        survey = database.get_survey(survey_id) if survey_id else None
        if survey_id and survey is None:
            from datetime import datetime
            database.start_survey(survey_id, 0.0, 0.0, datetime.now().isoformat())
            survey = database.get_survey(survey_id)
            
        base_lat = survey["origin_lat"] if survey else 0.0
        base_lon = survey["origin_lon"] if survey else 0.0'''

code = code.replace(old_survey, new_survey)

# 2. Add log after save_detection
old_save = '''                database.save_detection(
                    detection_id=item.id,
                    survey_id=survey_id,
                    lat=obj_lat,
                    lon=obj_lon,
                    object_type=item.object_type,
                    risk_score=score,
                    confidence=item.confidence,
                    impact_type=impact_profile["impact_type"]
                )'''

new_save = '''                database.save_detection(
                    detection_id=item.id,
                    survey_id=survey_id,
                    lat=obj_lat,
                    lon=obj_lon,
                    object_type=item.object_type,
                    risk_score=score,
                    confidence=item.confidence,
                    impact_type=impact_profile["impact_type"]
                )
                logger.info(f"Saved detection {item.id} to survey {survey_id}")'''

code = code.replace(old_save, new_save)

# 3. Add item.id to results and survey_id to response
old_results = '''            results.append({
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

        return {"status": "success", "detections": results}'''

new_results = '''            results.append({
                "id": item.id,
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

        return {"status": "success", "survey_id": survey_id, "detections": results}'''

code = code.replace(old_results, new_results)

with open('../AquaIntel Backend/main.py', 'w', encoding='utf-8') as f:
    f.write(code)

print("Backend patched successfully")
