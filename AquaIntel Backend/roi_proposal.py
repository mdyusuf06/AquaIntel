"""
AquaIntel - Step 3: ROI Proposal Engine
========================================
Extracts regions of interest (ROI) from preprocessed sonar pixel arrays
using classical computer vision techniques: MSER (Maximally Stable Extremal Regions)
combined with Adaptive Thresholding to detect highlight-shadow anomalies.
"""

from typing import List, Tuple, Dict, Any, Optional
import cv2
import numpy as np


def propose_regions(
    image: np.ndarray,
    min_area: int = 30,
    max_area: int = 50000,
    delta: int = 3,
    adaptive_block_size: int = 25,
    adaptive_C: int = 4,
    morph_kernel_size: int = 3
) -> List[Dict[str, Any]]:
    """
    Detect candidate anomaly regions (ROI) in sonar images using MSER and Adaptive Thresholding.

    Parameters
    ----------
    image : np.ndarray
        Grayscale input sonar image, uint8 or float32 normalized to [0, 255].
    min_area : int
        Minimum contour area filter for candidates.
    max_area : int
        Maximum contour area filter for candidates.
    delta : int
        MSER delta parameter comparing pixel values.
    adaptive_block_size : int
        Block size for Gaussian adaptive thresholding.
    adaptive_C : int
        Constant subtracted from mean in adaptive thresholding.
    morph_kernel_size : int
        Kernel size for morphological operations to merge highlight/shadow proposals.

    Returns
    -------
    List[Dict[str, Any]]
        List of detected region dictionaries:
        [
            {
                "bbox": (x, y, w, h),
                "mask": binary_mask (uint8 array of crop shape),
                "crop": image crop (uint8 array),
                "area": int,
                "center": (cx, cy)
            },
            ...
        ]
    """
    if image is None or image.size == 0:
        raise ValueError("Input image is empty or invalid.")

    # Ensure grayscale 8-bit image
    if image.dtype != np.uint8:
        if image.max() <= 1.0:
            img_gray = (image * 255).astype(np.uint8)
        else:
            img_gray = np.clip(image, 0, 255).astype(np.uint8)
    else:
        img_gray = image.copy()

    if len(img_gray.shape) == 3:
        img_gray = cv2.cvtColor(img_gray, cv2.COLOR_BGR2GRAY)

    h_img, w_img = img_gray.shape

    # 1. MSER Detection for Extremal Regions (Highlight & Shadow detection)
    mser = cv2.MSER_create(
        delta=delta,
        min_area=min_area,
        max_area=max_area
    )
    mser_regions, _ = mser.detectRegions(img_gray)

    mser_mask = np.zeros((h_img, w_img), dtype=np.uint8)
    for p in mser_regions:
        pts = np.array(p, dtype=np.int32)
        cv2.fillPoly(mser_mask, [pts], 255)

    # 2. Acoustic Highlight & Shadow Thresholding
    # Calculate local baseline mean & std to locate extreme acoustic highlights and dark shadows
    blur = cv2.GaussianBlur(img_gray, (5, 5), 0)
    mean_val, std_val = np.mean(blur), np.std(blur)

    # Highlights: bright return signals
    _, highlight_mask = cv2.threshold(
        blur, int(mean_val + 1.2 * std_val), 255, cv2.THRESH_BINARY
    )

    # Shadows: dark acoustic attenuation regions behind objects
    _, shadow_mask = cv2.threshold(
        blur, int(max(0, mean_val - 1.2 * std_val)), 255, cv2.THRESH_BINARY_INV
    )

    # 3. Fuse MSER, Highlight, and Shadow proposals
    combined_binary = cv2.bitwise_or(mser_mask, highlight_mask)
    combined_binary = cv2.bitwise_or(combined_binary, shadow_mask)

    # Clean mask using Morphological Closing and Opening
    kernel = cv2.getStructuringElement(
        cv2.MORPH_RECT, (morph_kernel_size, morph_kernel_size)
    )
    combined_binary = cv2.morphologyEx(combined_binary, cv2.MORPH_CLOSE, kernel)
    combined_binary = cv2.morphologyEx(combined_binary, cv2.MORPH_OPEN, kernel)

    # 4. Contour Extraction & Candidate Bounding Box / Mask Generation
    contours, _ = cv2.findContours(
        combined_binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    proposals: List[Dict[str, Any]] = []

    for cnt in contours:
        area = cv2.contourArea(cnt)
        if min_area <= area <= max_area:
            x, y, w, h = cv2.boundingRect(cnt)

            # Ensure valid dimensions
            x = max(0, x)
            y = max(0, y)
            w = min(w_img - x, w)
            h = min(h_img - y, h)

            if w <= 0 or h <= 0:
                continue

            # Extract binary mask for the ROI crop
            mask_full = np.zeros((h_img, w_img), dtype=np.uint8)
            cv2.drawContours(mask_full, [cnt], -1, 255, -1)
            crop_mask = mask_full[y : y + h, x : x + w]

            # Extract grayscale image crop
            crop_img = img_gray[y : y + h, x : x + w]

            # Calculate centroid
            M = cv2.moments(cnt)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
            else:
                cx, cy = x + w // 2, y + h // 2

            proposals.append({
                "bbox": (int(x), int(y), int(w), int(h)),
                "mask": crop_mask,
                "crop": crop_img,
                "area": float(area),
                "center": (cx, cy)
            })

    return proposals
