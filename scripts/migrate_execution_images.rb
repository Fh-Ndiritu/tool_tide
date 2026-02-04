# frozen_string_literal: true

# Usage: bin/rails runner scripts/migrate_execution_images.rb

puts "🚀 Starting migration of Execution images..."

count = 0
errors = 0

Agora::Execution.find_each do |execution|
  # Access the old attachment directly via ActiveStorage API if possible,
  # or rely on the fact that we just changed the model definition.
  # Since we changed `has_one_attached :image` to `has_many_attached :images`,
  # `execution.image` might no longer work via the association helper.

  # However, the underlying ActiveStorage::Attachment record still exists with name="image".
  # We need to update the `name` column from "image" to "images".

  attachments = ActiveStorage::Attachment.where(record_type: "Agora::Execution", record_id: execution.id, name: "image")

  if attachments.any?
    attachments.each do |attachment|
      begin
        attachment.update!(name: "images")
        print "."
        count += 1
      rescue => e
        puts "\n❌ Failed to migrate execution #{execution.id}: #{e.message}"
        errors += 1
      end
    end
  end
end

puts "\n\n✅ Migration Complete!"
puts "Moved #{count} attachments."
puts "Errors: #{errors}"
