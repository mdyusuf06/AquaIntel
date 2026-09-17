"""
AquaIntel - Step 4: ROI Embedding & Vector Index Management
===========================================================
Extracts deep features from ROI image crops using MobileNetV3-small backbone
(penultimate pooling layer), concatenates physical sonar feature vectors,
and manages FAISS IndexFlatL2 vector search indices for target classification.
"""

import os
from typing import Tuple, List, Optional, Union, Dict, Any
import numpy as np
import cv2
import faiss

import torch
import torch.nn as nn
from torchvision.models import mobilenet_v3_small, MobileNet_V3_Small_Weights


class SonarFeatureExtractor(nn.Module):
    """
    MobileNetV3-small backbone wrapper stripping classification head
    to output raw pooled visual embeddings (576-dim).
    """

    def __init__(self, pretrained: bool = True):
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        base_model = mobilenet_v3_small(weights=weights)

        # Retain feature extractor and global average pooling layer
        self.features = base_model.features
        self.avgpool = base_model.avgpool
        self.eval()

    @torch.no_grad()
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass for image batch.

        Parameters
        ----------
        x : torch.Tensor
            Image tensor of shape (B, 3, H, W) normalized.

        Returns
        -------
        torch.Tensor
            Feature embeddings of shape (B, 576).
        """
        feats = self.features(x)
        pooled = self.avgpool(feats)
        flattened = torch.flatten(pooled, 1)
        return flattened


# Singleton global model instance for performance
_EXTRACTOR_MODEL: Optional[SonarFeatureExtractor] = None


def get_extractor_model() -> SonarFeatureExtractor:
    """Lazy loader for SonarFeatureExtractor model."""
    global _EXTRACTOR_MODEL
    if _EXTRACTOR_MODEL is None:
        _EXTRACTOR_MODEL = SonarFeatureExtractor(pretrained=True)
    return _EXTRACTOR_MODEL


def preprocess_crop(crop: np.ndarray, target_size: Tuple[int, int] = (224, 224)) -> torch.Tensor:
    """
    Preprocess grayscale or RGB ROI crop for MobileNetV3 input.

    Parameters
    ----------
    crop : np.ndarray
        Input image crop (H, W) or (H, W, 3), uint8 or float.
    target_size : Tuple[int, int]
        (Width, Height) for resize.

    Returns
    -------
    torch.Tensor
        Preprocessed image tensor (1, 3, H, W) ready for PyTorch model.
    """
    if crop is None or crop.size == 0:
        raise ValueError("Crop image is empty.")

    # Convert to uint8 grayscale if needed
    if crop.dtype != np.uint8:
        crop = np.clip(crop * 255 if crop.max() <= 1.0 else crop, 0, 255).astype(np.uint8)

    # Make 3-channel RGB
    if len(crop.shape) == 2:
        crop_rgb = cv2.cvtColor(crop, cv2.COLOR_GRAY2RGB)
    elif crop.shape[2] == 1:
        crop_rgb = cv2.cvtColor(crop, cv2.COLOR_GRAY2RGB)
    else:
        crop_rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)

    # Resize image
    resized = cv2.resize(crop_rgb, target_size, interpolation=cv2.INTER_LINEAR)

    # Normalize ImageNet mean/std
    img_float = resized.astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    normalized = (img_float - mean) / std

    # Transpose to (C, H, W) and add batch dimension (1, C, H, W)
    tensor = torch.from_numpy(normalized.transpose(2, 0, 1)).unsqueeze(0).float()
    return tensor


def embed_roi(crop: np.ndarray, physics_vec: Union[np.ndarray, List[float]]) -> np.ndarray:
    """
    Pass cropped ROI through MobileNetV3 backbone (penultimate layer)
    and concatenate with Part 1 physics feature vector.

    Parameters
    ----------
    crop : np.ndarray
        Grayscale or RGB image crop of candidate ROI.
    physics_vec : np.ndarray or List[float]
        Physical feature vector from Part 1:
        [height, shadow_area, highlight_shadow_ratio, axis_orientation, haralick_texture]

    Returns
    -------
    np.ndarray
        Single unified feature vector float32 array of shape (576 + dim(physics_vec),).
    """
    model = get_extractor_model()
    input_tensor = preprocess_crop(crop)

    with torch.no_grad():
        visual_feat = model(input_tensor).squeeze(0).cpu().numpy()  # 576-dim

    physics_arr = np.array(physics_vec, dtype=np.float32).flatten()

    # Concatenate visual and physical feature vectors
    combined_embedding = np.concatenate([visual_feat, physics_arr]).astype(np.float32)

    # L2 Normalization for robust metric similarity
    norm = np.linalg.norm(combined_embedding)
    if norm > 0:
        combined_embedding = combined_embedding / norm

    return combined_embedding


class FAISSIndexManager:
    """
    Helper class to maintain, save, load, and update FAISS IndexFlatL2 indices
    for target (positive) and clutter (negative) vector libraries.
    """

    def __init__(self, dimension: int):
        self.dimension = dimension
        self.positive_index = faiss.IndexFlatL2(dimension)
        self.negative_index = faiss.IndexFlatL2(dimension)

        # Metadata stores for indexed entries
        self.positive_metadata: List[Dict[str, Any]] = []
        self.negative_metadata: List[Dict[str, Any]] = []

    def add_positive(self, vector: np.ndarray, metadata: Optional[Dict[str, Any]] = None):
        """Add sample to positive library (ghost nets, tires, drums, containers)."""
        vec = np.atleast_2d(vector).astype(np.float32)
        if vec.shape[1] != self.dimension:
            raise ValueError(f"Vector dim mismatch. Expected {self.dimension}, got {vec.shape[1]}")
        self.positive_index.add(vec)
        self.positive_metadata.append(metadata or {"label": "positive_target"})

    def add_negative(self, vector: np.ndarray, metadata: Optional[Dict[str, Any]] = None):
        """Add sample to negative library (rocks, ripples, drop-offs, clutter)."""
        vec = np.atleast_2d(vector).astype(np.float32)
        if vec.shape[1] != self.dimension:
            raise ValueError(f"Vector dim mismatch. Expected {self.dimension}, got {vec.shape[1]}")
        self.negative_index.add(vec)
        self.negative_metadata.append(metadata or {"label": "negative_clutter"})

    def save_indices(self, pos_path: str = "pos_index.faiss", neg_path: str = "neg_index.faiss"):
        """Save FAISS indices and metadata to disk."""
        faiss.write_index(self.positive_index, pos_path)
        faiss.write_index(self.negative_index, neg_path)
        import json
        with open(pos_path + ".meta", "w") as f:
            json.dump(self.positive_metadata, f)
        with open(neg_path + ".meta", "w") as f:
            json.dump(self.negative_metadata, f)

    def load_indices(self, pos_path: str = "pos_index.faiss", neg_path: str = "neg_index.faiss"):
        """Load FAISS indices and metadata from disk."""
        import json
        if os.path.exists(pos_path):
            self.positive_index = faiss.read_index(pos_path)
            if os.path.exists(pos_path + ".meta"):
                with open(pos_path + ".meta", "r") as f:
                    self.positive_metadata = json.load(f)
        if os.path.exists(neg_path):
            self.negative_index = faiss.read_index(neg_path)
            if os.path.exists(neg_path + ".meta"):
                with open(neg_path + ".meta", "r") as f:
                    self.negative_metadata = json.load(f)
