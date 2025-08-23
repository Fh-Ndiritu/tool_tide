# frozen_string_literal: true

# Define canonical formats and their MIME types
CANONICAL_IMAGE_FORMATS = {
  'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'avif' => 'image/avif',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  'tiff' => 'image/tiff',
  'bmp' => 'image/bmp',
  'gif' => 'image/gif',
  'svg' => 'image/svg+xml',
  'ico' => 'image/x-icon',
  'psd' => 'image/vnd.adobe.photoshop',
  'raw' => 'image/x-raw', # Note: raw is generic, specific raw types might be handled differently
  'dng' => 'image/dng',
  'cr2' => 'image/x-canon-raw',
  'nef' => 'image/x-nikon-raw',
  'arw' => 'image/x-sony-raw',
  'jp2' => 'image/jp2',
  'hdr' => 'image/vnd.radiance',
  'exr' => 'image/x-exr',
  'tga' => 'image/x-tga',
  'pcx' => 'image/x-pcx',
  'pnm' => 'image/x-portable-anymap',
  'ppm' => 'image/x-portable-pixmap',
  'pgm' => 'image/x-portable-graymap',
  'pbm' => 'image/x-portable-bitmap',
  'xbm' => 'image/x-xbitmap',
  'xpm' => 'image/x-xpixmap'
}.freeze

# Map all possible input strings (aliases and main names) to their canonical name
FORMAT_ALIASES_MAP = {
  'jpeg' => 'jpeg',
  'jpg' => 'jpeg', # Alias points to canonical "jpeg"
  'png' => 'png',
  'webp' => 'webp',
  'avif' => 'avif',
  'heic' => 'heic',
  'heif' => 'heif',
  'tiff' => 'tiff',
  'tif' => 'tiff', # Alias points to canonical "tiff"
  'bmp' => 'bmp',
  'gif' => 'gif',
  'svg' => 'svg',
  'ico' => 'ico',
  'pdf' => 'pdf',
  'psd' => 'psd',
  'raw' => 'raw',
  'dng' => 'dng',
  'cr2' => 'cr2',
  'nef' => 'nef',
  'arw' => 'arw',
  'jp2' => 'jp2',
  'jpf' => 'jp2', # Alias points to canonical "jp2"
  'jpx' => 'jp2', # Alias points to canonical "jp2"
  'hdr' => 'hdr',
  'exr' => 'exr',
  'tga' => 'tga',
  'pcx' => 'pcx',
  'pnm' => 'pnm',
  'ppm' => 'ppm',
  'pgm' => 'pgm',
  'pbm' => 'pbm',
  'xbm' => 'xbm',
  'xpm' => 'xpm'
}.freeze


IMAGE_EXTRACTION_FORMATS = {
  'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'avif' => 'image/avif',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  'tiff' => 'image/tiff',
  'bmp' => 'image/bmp',
  'gif' => 'image/gif',
  'svg' => 'image/svg+xml'
}

IMAGE_LANDSCAPE_FORMATS = {
  'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'avif' => 'image/avif',
  'heic' => 'image/heic',
  'heif' => 'image/heif'
}

DESTINATION_IMAGE_FORMATS = [
  'jpeg',
  'png',
  'webp',
  'avif',
  'heic',
  'heif',
  'tiff',
  'bmp',
  'gif',
  'ico',
  'psd',
  'jp2',
  'hdr',
  'exr',
  'pcx',
  'pnm',
  'ppm',
  'pgm',
  'pbm',
  'xbm',
  'xpm'
].freeze

LANDSCAPE_PRESETS = {
  'zen' => 'Serene and calm',
  'cottage' => 'Charming abundance',
  'desert' => 'Resilient and hardy',
  'mediterranean' => 'Fragrant and relaxed',
  'tropical' => 'Vibrant and lush',
  'modern' => 'Clean minimalist'
}


PROMPTS = YAML.load_file(Rails.root.join('config', 'prompts.yml'))

SUGGESTED_PLANTS_SCHEMA = {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string',  description: 'English name of the plant' },
          description: { type: 'string', description: 'An adjective rich sentence that mentions the colors, looks and name of flower.' }
        },
        required: [ 'name', 'description' ]
      },

      required: [ 'name', 'description' ]
}

LOCALIZED_PROMPT_SCHEMA = {
  type: 'object',
    properties: {
      updated_prompt: { type: 'string',  description: 'The updated prompt with the new flowers and the concise adjectives of how they look' }
    },

  required: [ 'updated_prompt' ]
}
