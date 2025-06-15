#!/bin/bash

# Define the destination formats
DESTINATION_IMAGE_FORMATS=(
  "jpeg"
  "png"
  "webp"
  "avif"
  "heic"
  "heif"
  "tiff"
  "bmp"
  "gif"
  "svg"  # Will likely fail for raster input with vips
  "ico"  # May require specific options for multi-image icons, using magick here
  "psd"  # Will likely create a flattened PSD, using magick here for better compatibility
  "jp2"
  "hdr"
  "exr"
  "tga"
  "pcx"
  "pnm"
  "ppm"
  "pgm"
  "pbm"
  "xbm"
  "xpm"
)

INPUT_IMAGE="test_input.jpg"
OUTPUT_DIR="test_outputs"

echo "--- Starting Image Conversion Tests ---"
echo "Ensuring test environment is clean..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 1. Generate a simple JPEG input image using ImageMagick
echo "Generating input image: $INPUT_IMAGE"
magick -size 200x150 gradient:red-blue "$INPUT_IMAGE"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to generate input image. ImageMagick might not be working correctly."
  exit 1
fi
echo "Input image generated successfully."

echo ""
echo "--- Testing conversions with VIPS (primary) and ImageMagick (fallback/specific formats) ---"
echo ""

for FORMAT in "${DESTINATION_IMAGE_FORMATS[@]}"; do
  OUTPUT_FILE="$OUTPUT_DIR/output.$FORMAT"
  echo "Attempting to convert $INPUT_IMAGE to $FORMAT ($OUTPUT_FILE)..."
  SUCCESS=false
  TOOL_USED="vips"

  # Special handling for formats where Vips is known to struggle or Magick is better
  if [[ "$FORMAT" == "svg" || "$FORMAT" == "ico" || "$FORMAT" == "psd" || "$FORMAT" == "hdr" || "$FORMAT" == "exr" ]]; then
    TOOL_USED="magick"
    magick "$INPUT_IMAGE" "$OUTPUT_FILE" 2>/dev/null
  else
    # Attempt with vips first
    vips copy "$INPUT_IMAGE" "$OUTPUT_FILE" 2>/dev/null
  fi

  if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo "  [SUCCESS] $FORMAT conversion succeeded ($TOOL_USED)."
    SUCCESS=true
  else
    echo "  [FAIL] $FORMAT conversion failed with $TOOL_USED. Attempting with magick as fallback (if not already used)..."
    # If vips failed, and we haven't tried magick yet, try magick
    if [[ "$TOOL_USED" == "vips" ]]; then
        TOOL_USED="magick-fallback"
        magick "$INPUT_IMAGE" "$OUTPUT_FILE" 2>/dev/null
        if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
            echo "  [SUCCESS] $FORMAT conversion succeeded with magick fallback."
            SUCCESS=true
        else
            echo "  [FAIL] $FORMAT conversion failed with magick fallback."
        fi
    fi
  fi

  if ! $SUCCESS; then
    echo "  Note: Some formats like SVG require vectorization tools or specific input."
    echo "  Note: Some formats like ICO/PSD/HDR/EXR might require specific image properties or options for full functionality."
  fi
  echo ""
done

echo "--- Cleaning up test files ---"
rm -rf "$INPUT_IMAGE" "$OUTPUT_DIR"
echo "Cleanup complete."
echo "--- Image Conversion Tests Finished ---"
