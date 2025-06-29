# frozen_string_literal: true

module ImageFormatHelper
  # Returns the canonical format name for a given input string (case-insensitive),
  # or nil if the format is not recognized.
  def self.canonical_format(input_format)
    FORMAT_ALIASES_MAP[input_format.to_s.downcase]
  end

  # Returns the MIME type for a given input format (main or alias),
  # or nil if the format is not recognized.
  def self.mime_type_for(input_format)
    canonical = canonical_format(input_format)
    CANONICAL_IMAGE_FORMATS[canonical] if canonical
  end

  # Returns an array of all accepted format names (canonical and aliases).
  def self.all_accepted_formats
    FORMAT_ALIASES_MAP.keys
  end

  # Returns an array of only canonical format names.
  def self.canonical_formats_list
    CANONICAL_IMAGE_FORMATS.keys
  end

  def self.extractable_format?(input_format)
    IMAGE_EXTRACTION_FORMATS.values.include?(input_format.to_s.downcase)
  end

  def self.landscape_able_format?(input_format)
    IMAGE_LANDSCAPE_FORMATS.values.include?(input_format.to_s.downcase)
  end
end
