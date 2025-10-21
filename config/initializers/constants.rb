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
  "raw" => "image/x-raw", # NOTE: raw is generic, specific raw types might be handled differently
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
}.freeze

DESTINATION_IMAGE_FORMATS = %w[
  jpeg
  png
  webp
  avif
  heic
  heif
  tiff
  bmp
  gif
  ico
  psd
  jp2
  hdr
  exr
  pcx
  pnm
  ppm
  pgm
  pbm
  xbm
  xpm
].freeze

LANDSCAPE_PRESETS = {
  "cottage" => "Charming vibe",
  "zen" => "Serene and calm",
  "desert" => "Resilient and hardy",
  "mediterranean" => "Fragrant and relaxed",
  "tropical" => "Vibrant and lush",
  "modern" => "Clean minimalist"
}.freeze

EVENTS = [
  "Spring Blooms",
  "Summer BBQ Season",
  "Fall Harvest",
  "Halloween",
  "Thanksgiving",
  "Christmas",
  "New Years Celebration",
  "Winter Wonderland",
  "Easter",
  "Mother's Day",
  "Earth Day",
  "Diwali (Festival of Lights)",
  "Lunar New Year (Spring Festival)",
  "Holi (Festival of Colors)",
  "Harbin Ice and Snow Festival",
  "Lantern Festival (Yuan Xiao Jie)"
]

SEASONS = [ "Summer", "Winter", "Autumn", "Spring" ]

PROMPTS = YAML.load_file(Rails.root.join("config/prompts.yml"))

# currency credits
PRO_CREDITS_PER_USD = 20

GOOGLE_IMAGE_COST = 8
LOCALIZED_PLANT_COST = 2
DEFAULT_IMAGE_COUNT = 3
DEFAULT_USD_PURCHASE_AMOUNT = BigDecimal(10)
CREDITS_INFO = "$#{DEFAULT_USD_PURCHASE_AMOUNT.to_i} for #{(DEFAULT_USD_PURCHASE_AMOUNT * PRO_CREDITS_PER_USD).to_i} credits".freeze
