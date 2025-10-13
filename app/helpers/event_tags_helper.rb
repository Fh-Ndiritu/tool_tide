module EventTagsHelper
  def unique_intro_content(tag)
    "Join the Hadaa community and explore over <b>#{tag.slug_to_integer}</b> stunning user-generated designs for your #{tag.title} celebration. These projects showcase everything from festive lighting to elegant seasonal flower arrangements. <b>Ready to contribute your own vision?</b> Start designing now and share your project!"
  end

  def related_tags_list(tag)
    Tag.excluding(tag).where(created_at: tag.created_at.., tag_class: tag.tag_class).limit(10)
  end
end
