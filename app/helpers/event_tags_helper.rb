module EventTagsHelper
  def unique_intro_content(tag)
    project_count = tag.project_count

    case tag.tag_class
    when "event"
      "Join the Hadaa community and explore over <b>#{project_count}</b> stunning user-generated designs for your #{tag.title} celebration. These projects showcase everything from festive lighting to elegant seasonal flower arrangements. <b>Ready to contribute your own vision?</b> Start designing now and share your project!"

    when "season"
      # FIXED: Markdown (**) replaced with HTML (<b>)
      "Discover the latest trends for <b>#{tag.title}</b>! Browse <b>#{project_count}</b> curated design projects, perfect for capturing the spirit of the season. Find inspiration for cozy indoor décor, seasonal color palettes, and outdoor transformations. <b>Don't just decorate—design.</b> Upload your favorite #{tag.title} project today!"
    else
      # General fallback content
      "Welcome to the Hadaa design hub! Explore <b>#{project_count}</b> incredible projects and designs shared by our vibrant community. Find inspiration across all categories, and don't forget to contribute your own creative vision!"
    end
  end
end
