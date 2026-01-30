#!/bin/bash

GALLERY_DIR="/Users/fh/code/playground/tool_tide/app/assets/images/gallery"
cd "$GALLERY_DIR"

echo "Optimizing WebP images in $GALLERY_DIR to 500px width..."

for file in *.webp; do
  [ -e "$file" ] || continue

  echo "Resizing $file..."
  magick "$file" -resize 500x -quality 80 -define webp:lossless=false "tmp_$file"

  if [ $? -eq 0 ]; then
    mv "tmp_$file" "$file"
  else
    echo "Failed to resize $file"
    rm "tmp_$file"
  fi
done

echo "Done."
