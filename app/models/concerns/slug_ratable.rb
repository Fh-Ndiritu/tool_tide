module SlugRatable
  extend ActiveSupport::Concern

  def slug_to_integer
    max_id = 8000
    min_id = 3000
    range_size = max_id - min_id + 1

    checksum = Zlib.crc32(slug.downcase)

    mapped_value = checksum % range_size

    final_id = mapped_value + min_id

    final_id
  end

  def project_count
    slug_to_integer
  end

  def rating
    # Generate a rating between 4.7 and 5.0 based on slug
    min_rating = 4.7
    max_rating = 5.0
    range = max_rating - min_rating

    # Use a different seed than project_count for variety
    checksum = Zlib.crc32("rating_#{slug.downcase}")
    normalized = (checksum % 1000) / 1000.0

    (min_rating + (normalized * range)).round(2)
  end
end
