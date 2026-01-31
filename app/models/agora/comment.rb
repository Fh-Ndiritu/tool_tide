module Agora
  class Comment < ApplicationRecord
    include AgoraTable
    belongs_to :post, class_name: "Agora::Post", touch: true
    has_many :votes, as: :votable, dependent: :destroy

    validates :author_agent_id, presence: true
    validates :body, presence: true

    def update_net_score!
      score = votes.sum("direction * CASE WHEN voter_type_str = 'Human' THEN 2 ELSE 1 END")
      update_column(:net_score, score)
    end
  end
end
