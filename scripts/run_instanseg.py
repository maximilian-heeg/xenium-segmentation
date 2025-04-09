#!/usr/bin/env python
import argparse
import os
import tifffile
import numpy as np
from instanseg import InstanSeg
# from instanseg.utils.utils import show_images # Keep commented out for non-interactive script

# Define the expected relative path to the morphology image within the Xenium folder
RELATIVE_IMG_PATH = os.path.join("morphology_focus", "morphology_focus_0000.ome.tif")

# Define constants
PIXEL_SIZE: float = 0.2125  # Pixel size in microns/pixel
MODEL_NAME = "fluorescence_nuclei_and_cells"
NUC_OUTPUT_FILENAME = "instanseg_nuclei_mask.npy"
CELL_OUTPUT_FILENAME = "instanseg_cell_mask.npy"

def run_instanseg_on_xenium(xenium_folder: str):
    """
    Runs InstanSeg segmentation on the morphology focus image from a Xenium run.

    Args:
        xenium_folder: Path to the main Xenium output directory.
    """
    # --- 1. Construct paths ---
    image_path = os.path.join(xenium_folder, RELATIVE_IMG_PATH)
    output_dir = ""
    nuc_output_path = os.path.join(output_dir, NUC_OUTPUT_FILENAME)
    cell_output_path = os.path.join(output_dir, CELL_OUTPUT_FILENAME)

    print(f"[*] Target Xenium folder: {xenium_folder}")
    print(f"[*] Expected image path: {image_path}")

    # --- 2. Check if input file exists ---
    if not os.path.isfile(image_path):
        print(f"[ERROR] Morphology image not found at the expected path: {image_path}")
        print("[ERROR] Please ensure the Xenium folder structure is correct.")
        exit(1)

    print(f"[*] Output directory: {output_dir}")

    # --- 3. Initialize InstanSeg ---
    print(f"[*] Initializing InstanSeg model: '{MODEL_NAME}'...")
    try:
        instanseg_model = InstanSeg(MODEL_NAME, verbosity=1)
    except Exception as e:
        print(f"[ERROR] Failed to initialize InstanSeg model: {e}")
        exit(1)

    # --- 4. Load Image ---
    print(f"[*] Loading image: {os.path.basename(image_path)}...")
    try:
        # Read the first level (highest resolution) of the OME-TIF
        image_array = tifffile.imread(image_path, is_ome=True, level=0, aszarr=False)
        print(f"[*] Image loaded successfully. Shape: {image_array.shape}, dtype: {image_array.dtype}")
        # You might need to preprocess image_array shape depending on InstanSeg requirements
        # e.g., ensure it has a channel dimension if needed.
        # Check documentation for `eval_medium_image` input shape expectations.
    except Exception as e:
        print(f"[ERROR] Failed to read image file: {e}")
        exit(1)

    # --- 5. Run InstanSeg Evaluation ---
    print(f"[*] Running InstanSeg evaluation (pixel size: {PIXEL_SIZE} µm/px)...")
    try:
        # Assuming eval_medium_image can handle the shape from tifffile directly
        # It returns labels and an internal image tensor representation
        labeled_output, _ = instanseg_model.eval_medium_image(image_array, PIXEL_SIZE)
        print(f"[*] InstanSeg evaluation complete. Output shape: {labeled_output.shape}")
    except Exception as e:
        print(f"[ERROR] InstanSeg evaluation failed: {e}")
        exit(1)

    # --- 6. Extract and Save Segmentation Masks ---
    try:
        print(f"[*] Extracting and saving segmentation masks...")
        nuc_mask = labeled_output[0,0]
        cell_mask = labeled_output[0,1]

        # Save the numpy arrays
        np.save(nuc_output_path, np.array(nuc_mask).astype(np.uint32))
        print(f"[*] Nuclei mask saved to: {nuc_output_path}")

        np.save(cell_output_path, np.array(cell_mask).astype(np.uint32))
        print(f"[*] Cell mask saved to: {cell_output_path}")

    except Exception as e:
        print(f"[ERROR] Failed to extract or save segmentation masks: {e}")
        exit(1)


    print("[*] Script finished successfully.")

def main():
    parser = argparse.ArgumentParser(
        description="Run InstanSeg segmentation on the morphology focus image from a Xenium output folder."
    )
    parser.add_argument(
        "xenium_folder",
        type=str,
        help="Path to the main Xenium output directory (containing the 'ranger' subdirectory)."
    )
    args = parser.parse_args()

    run_instanseg_on_xenium(args.xenium_folder)

if __name__ == "__main__":
    main()
