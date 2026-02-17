module Agora
  class DraftResponse < ApplicationRecord
    include AgoraTable

    belongs_to :opportunity, class_name: "Agora::Opportunity", foreign_key: "agora_opportunity_id"

    validates :content, presence: true
  end
end
