#!/bin/bash

REDESIGN_DIR="/Users/fh/code/playground/tool_tide/app/assets/images/redesign_exterior"
cd "$REDESIGN_DIR"

echo "Optimizing images in $REDESIGN_DIR to 700px width..."

for file in *.png; do
  [ -e "$file" ] || continue
  filename="${file%.*}"
  new_name="${filename}.webp"

  echo "Processing $file -> $new_name"

  # Resize to 700px width, auto height, quality 80
  magick "$file" -resize 700x -quality 80 -define webp:lossless=false "$new_name"

  if [ $? -eq 0 ]; then
    rm "$file"
    echo "Removed original $file"
  else
    echo "Failed to convert $file"
  fi
done

echo "Done."
