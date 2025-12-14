class Blog < ApplicationRecord
  validates :location_name, presence: true
  validates :slug, uniqueness: true, allow_nil: true

  def to_param
    return nil unless slug
    slug.split("/").last
  end
end
