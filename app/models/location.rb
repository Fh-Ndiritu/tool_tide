class Location < ApplicationRecord
  include SlugRatable

  before_validation :generate_slug, on: [ :create, :update ]

  def unique_intro_content
    "Explore the best of local design in <b>#{name}</b>! We feature <b>#{project_count}</b> unique, community-sourced design ideas from creators right here in #{name}. See how local style is shaping homes and public spaces. <b>Be part of the local movement!</b> Share your own #{name}-inspired project."
  end

  def seo_description
    "Explore local, community-sourced design ideas from creators right here in #{name}. See how regional style is shaping homes and submit your own local project!"
  end

  def seo_title
    "Local #{title} Design Community & Project Ideas | Hadaa AI"
  end

  def related_locations
    start_id = (id-5).clamp(0, id)
    last_id = (id+5).clamp(id, self.class.last.id)
    self.class.where(id: start_id..last_id).excluding(self)
  end

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
