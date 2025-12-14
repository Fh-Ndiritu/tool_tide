class BlogOrchestratorJob < ApplicationJob
  # TODO: Move all admin background jobs to low priority queue
  queue_as :low_priority

  def perform
    location = BlogLocation.order(Arel.sql("last_processed_at ASC NULLS FIRST")).first

    return unless location

    Rails.logger.info "BlogOrchestratorJob: Processing location #{location.city}, #{location.country}"

    targets = []

    # Add City (Scoped with State/Country for uniqueness), State, Country
    if location.city.present?
      city_target = [ location.city, location.state, location.country ].compact.join(", ")
      targets << city_target
    end

    if location.state.present?
      state_target = [ location.state, location.country ].compact.join(", ")
      targets << state_target
    end

    targets << location.country if location.country.present?

    # Add Regions/Counties
    if location.major_counties.present?
      regions = location.major_counties.split(",").map(&:strip)
      scoped_regions = regions.map do |region|
        [ region, location.state, location.country ].compact.join(", ")
      end
      targets.concat(scoped_regions)
    end

    targets.uniq!

    targets.each do |target_name|
      # Check if a blog for this location already exists (case insensitive)
      # We check location_name directly.
      next if Blog.where("LOWER(location_name) = ?", target_name.downcase).exists?

      Rails.logger.info "BlogOrchestratorJob: Creating blog for #{target_name}"

      blog = Blog.create!(
        location_name: target_name,
        # We assume other fields are populated by the generator or have defaults?
        # Blog model only validates location_name presence.
        # But we might need to set 'published: false' or similar if columns exist.
        # Based on BlogGeneratorService, it updates title/content later.
      )

      # Trigger generation
      BlogGenerationJob.perform_later(blog.id)
    end

    # 3. Update rotation timestamp
    location.update!(last_processed_at: Time.current)

    # 4. Reschedule for 2 days later
    # We use self.class to enqueue the same job class
    self.class.set(wait: 8.hours).perform_later
  end
end
