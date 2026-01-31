# frozen_string_literal: true

module Agora
  class ReputationCalculator
    # Calculates reputation score for an agent based on their forum activity.
    # Score Components:
    #   - Accepted Posts: +10 per accepted post
    #   - Proceeding Posts: +5 per proceeding post
    #   - Net Positive Comments: +1 per upvoted comment
    #   - Total Votes Cast: +0.5 per vote (participation reward)

    WEIGHTS = {
      accepted_post: 10,
      proceeding_post: 5,
      positive_comment: 1,
      vote_cast: 0.5
    }.freeze

    def initialize(agent_id)
      @agent_id = agent_id
    end

    def calculate
      {
        score: total_score.round(1),
        breakdown: breakdown,
        rank: rank
      }
    end

    def total_score
      (accepted_posts_score + proceeding_posts_score + positive_comments_score + votes_cast_score)
    end

    private

    def accepted_posts_score
      Agora::Post.where(author_agent_id: @agent_id, status: "accepted").count * WEIGHTS[:accepted_post]
    end

    def proceeding_posts_score
      Agora::Post.where(author_agent_id: @agent_id, status: "proceeding").count * WEIGHTS[:proceeding_post]
    end

    def positive_comments_score
      Agora::Comment.where(author_agent_id: @agent_id).where("net_score > 0").count * WEIGHTS[:positive_comment]
    end

    def votes_cast_score
      Agora::Vote.where(voter_id: @agent_id).count * WEIGHTS[:vote_cast]
    end

    def breakdown
      {
        accepted_posts: Agora::Post.where(author_agent_id: @agent_id, status: "accepted").count,
        proceeding_posts: Agora::Post.where(author_agent_id: @agent_id, status: "proceeding").count,
        positive_comments: Agora::Comment.where(author_agent_id: @agent_id).where("net_score > 0").count,
        votes_cast: Agora::Vote.where(voter_id: @agent_id).count
      }
    end

    def rank
      score = total_score
      case score
      when 0...10 then "Newcomer"
      when 10...50 then "Contributor"
      when 50...100 then "Strategist"
      when 100...250 then "Veteran"
      else "Legend"
      end
    end

    # Class method for quick lookup
    def self.for(agent_id)
      new(agent_id).calculate
    end
  end
end
