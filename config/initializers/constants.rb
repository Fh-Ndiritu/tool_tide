# frozen_string_literal: true

# Define canonical formats and their MIME types
CANONICAL_IMAGE_FORMATS = {
  "jpeg" => "image/jpeg",
  "png" => "image/png",
  "webp" => "image/webp",
  "avif" => "image/avif",
  "heic" => "image/heic",
  "heif" => "image/heif",
  "tiff" => "image/tiff",
  "bmp" => "image/bmp",
  "gif" => "image/gif",
  "svg" => "image/svg+xml",
  "ico" => "image/x-icon",
  "psd" => "image/vnd.adobe.photoshop",
  "raw" => "image/x-raw", # Note: raw is generic, specific raw types might be handled differently
  "dng" => "image/dng",
  "cr2" => "image/x-canon-raw",
  "nef" => "image/x-nikon-raw",
  "arw" => "image/x-sony-raw",
  "jp2" => "image/jp2",
  "hdr" => "image/vnd.radiance",
  "exr" => "image/x-exr",
  "tga" => "image/x-tga",
  "pcx" => "image/x-pcx",
  "pnm" => "image/x-portable-anymap",
  "ppm" => "image/x-portable-pixmap",
  "pgm" => "image/x-portable-graymap",
  "pbm" => "image/x-portable-bitmap",
  "xbm" => "image/x-xbitmap",
  "xpm" => "image/x-xpixmap"
}.freeze

# Map all possible input strings (aliases and main names) to their canonical name
FORMAT_ALIASES_MAP = {
  "jpeg" => "jpeg",
  "jpg" => "jpeg", # Alias points to canonical "jpeg"
  "png" => "png",
  "webp" => "webp",
  "avif" => "avif",
  "heic" => "heic",
  "heif" => "heif",
  "tiff" => "tiff",
  "tif" => "tiff", # Alias points to canonical "tiff"
  "bmp" => "bmp",
  "gif" => "gif",
  "svg" => "svg",
  "ico" => "ico",
  "pdf" => "pdf",
  "psd" => "psd",
  "raw" => "raw",
  "dng" => "dng",
  "cr2" => "cr2",
  "nef" => "nef",
  "arw" => "arw",
  "jp2" => "jp2",
  "jpf" => "jp2", # Alias points to canonical "jp2"
  "jpx" => "jp2", # Alias points to canonical "jp2"
  "hdr" => "hdr",
  "exr" => "exr",
  "tga" => "tga",
  "pcx" => "pcx",
  "pnm" => "pnm",
  "ppm" => "ppm",
  "pgm" => "pgm",
  "pbm" => "pbm",
  "xbm" => "xbm",
  "xpm" => "xpm"
}.freeze


IMAGE_EXTRACTION_FORMATS = {
  "jpeg" => "image/jpeg",
  "png" => "image/png",
  "webp" => "image/webp",
  "avif" => "image/avif",
  "heic" => "image/heic",
  "heif" => "image/heif",
  "tiff" => "image/tiff",
  "bmp" => "image/bmp",
  "gif" => "image/gif",
  "svg" => "image/svg+xml"
}

DESTINATION_IMAGE_FORMATS = [
  "jpeg",
  "png",
  "webp",
  "avif",
  "heic",
  "heif",
  "tiff",
  "bmp",
  "gif",
  "svg",
  "ico",
  "psd",
  "jp2",
  "hdr",
  "exr",
  "tga",
  "pcx",
  "pnm",
  "ppm",
  "pgm",
  "pbm",
  "xbm",
  "xpm"
].freeze
