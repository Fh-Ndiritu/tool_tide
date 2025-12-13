class Audio < ApplicationRecord
  has_one_attached :audio_file


  validates :content, presence: true
  validates :single_speaker, inclusion: { in: [ true, false ] }

  after_save_commit :generate_audio, if: :saved_change_to_content?

  default_scope { order(created_at: :desc) }

  private

  def generate_audio
    GeminiTts.new(self).perform
  end
end


# [
#   {
#     "style_prompt": "Read in a very tense, dramatic, and urgent tone.",
#     "turns": [
#       { "speaker": "Ndunge", "text": "The signal is fading! We have less than sixty seconds to initiate the sequence, or the entire fleet is lost." },
#       { "speaker": "Karuri", "text": "I see it, but the access codes are corrupted. I'm routing through the secondary matrix now, stand by!" },
#       { "speaker": "Ndunge", "text": "Thirty seconds, Karuri! Do whatever it takes!" }
#     ]
#   },
#   {
#     "style_prompt": "Read in a calm, informative, and authoritative documentary narrator voice.",
#     "turns": [
#       { "speaker": "Huria", "text": "The battle raged for three more cycles, a desperate final stand against insurmountable odds." },
#       { "speaker": "Huria", "text": "Despite the heroic efforts, the corrupted sequence began its final countdown, sealing their fate." }
#     ]
#   },
#   {
#     "style_prompt": "Read in a low, sorrowful, and reflective tone.",
#     "turns": [
#       { "speaker": "Karuri", "text": "It's done. I couldn't override it in time." },
#       { "speaker": "Ndunge", "text": "It wasn't your fault, Karuri. We fought until the last moment." }
#     ]
#   }
# ]
