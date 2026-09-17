"""
AquaIntel - Step 6: Live Learning Feedback API
==============================================
FastAPI service exposing live feedback endpoint POST /api/v1/targets/feedback.
Accepts operator label correction via multipart/form-data with a direct file upload input.
Automatically calculates the 5 physical features from the uploaded image via extract_physics_vector(),
computes the ROI embedding via embed_roi(), and updates positive_index or negative_index dynamically at runtime.
"""

from typing import List, Optional, Literal
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, status
from pydantic import BaseModel, Field
import numpy as np
import cv2

from embedding import embed_roi, FAISSIndexManager
from physics_extractor import extract_physics_vector

# Instantiate shared FAISS index manager (576 MobileNet + 5 Physics = 581 dim)
EMBEDDING_DIM = 581
index_manager = FAISSIndexManager(dimension=EMBEDDING_DIM)

router = APIRouter(tags=["feedback"])

class FeedbackResponse(BaseModel):
    status: str
    label_added: str
    target_category: Optional[str]
    computed_physics_vec: List[float] = Field(
        ...,
        description="Automatically computed 5 physical features: [height, shadow_area, hs_ratio, orientation, haralick]"
    )
    positive_index_count: int
    negative_index_count: int
    embedding_dimension: int


@router.get("/health")
def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "positive_targets_count": index_manager.positive_index.ntotal,
        "negative_targets_count": index_manager.negative_index.ntotal
    }


@router.post(
    "/api/v1/targets/feedback",
    response_model=FeedbackResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Operator Live Feedback Correction Endpoint"
)
async def submit_operator_feedback(
    file: UploadFile = File(
        ...,
        description="Upload sonar ROI crop image directly (PNG, JPG, JPEG)"
    ),
    label: Literal["positive", "negative"] = Form(
        ...,
        description="Operator feedback label correction: 'positive' (target) or 'negative' (clutter)"
    ),
    target_category: Optional[str] = Form(
        None,
        description="Optional detailed category (e.g. ghost_net, tire, drum, container, rock, ripple)"
    )
):
    """
    Accepts operator label correction via multipart/form-data file upload in Swagger UI.
    Form Parameters:
    - file: Upload File
    - label: 'positive' or 'negative'
    - target_category: Optional category string

    The 5 sonar physics features are automatically calculated from the image on the backend.
    """
    # 1. Validate file format
    filename = file.filename.lower() if file.filename else ""
    if not (filename.endswith(".png") or filename.endswith(".jpg") or filename.endswith(".jpeg") or "image" in (file.content_type or "")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Supported formats: PNG, JPG, JPEG."
        )

    # 2. Read image file contents directly into OpenCV grayscale array
    try:
        contents = await file.read()
        if len(contents) == 0:
            raise ValueError("Uploaded file is empty.")
        if len(contents) > 5 * 1024 * 1024:
            raise ValueError("Uploaded image file exceeds 5MB limit.")

        np_arr = np.frombuffer(contents, np.uint8)
        crop_img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)

        if crop_img is None or crop_img.size == 0:
            raise ValueError("Failed to decode image from uploaded file.")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error reading image file: {str(e)}"
        )

    # 3. Automatically calculate 5 physics features from crop image
    physics_list = extract_physics_vector(crop_img)

    # 4. Extract unified embedding (MobileNetV3 + Physics Vector)
    try:
        physics_arr = np.array(physics_list, dtype=np.float32)
        feat_vec = embed_roi(crop_img, physics_arr)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating ROI embedding: {str(e)}"
        )

    # 5. Dynamic runtime update to positive or negative FAISS index
    category_val = target_category if (target_category and target_category.strip()) else None

    meta = {
        "category": category_val or label,
        "physics": physics_list
    }

    if label == "positive":
        index_manager.add_positive(feat_vec, metadata=meta)
    elif label == "negative":
        index_manager.add_negative(feat_vec, metadata=meta)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid label: {label}. Must be 'positive' or 'negative'."
        )

    return FeedbackResponse(
        status="success",
        label_added=label,
        target_category=category_val,
        computed_physics_vec=physics_list,
        positive_index_count=index_manager.positive_index.ntotal,
        negative_index_count=index_manager.negative_index.ntotal,
        embedding_dimension=int(feat_vec.shape[0])
    )
