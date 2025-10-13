# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  Tag.destroy_all
  EVENTS.each do |name|
    tag = Tag.create!(tag_class: :event, title: name)
    TextRequest.joins(:user).where(user: { admin: true }).limit(50).sample(2).each do |text_request|
      text_request.generation_taggings.create!(tag:)
    end

    MaskRequest.joins(canva: :user).where(user: { admin: true }).limit(50).sample(2).each do |mask_request|
      mask_request.generation_taggings.create!(tag:)
    end
  end

end
