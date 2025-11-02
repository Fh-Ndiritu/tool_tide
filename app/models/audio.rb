class Audio < ApplicationRecord
  has_one_attached :audio_file

  validates :content, presence: true
  validates_presence_of :single_speaker

  after_create_commit :generate_audio

  private

  def generate_audio
    GeminiTts.new(self).perform
  end
end
