class LandscapeRequest < ApplicationRecord
  validates_presence_of :preset, :image_engine, :prompt

  belongs_to :landscape
  has_many_attached :modified_images

  has_many :active_storage_attachments, class_name: "ActiveStorage::Attachment", as: :record

  enum :image_engine, [ :bria, :google ], suffix: :processor
  delegate :ip_address, to: :landscape
end
