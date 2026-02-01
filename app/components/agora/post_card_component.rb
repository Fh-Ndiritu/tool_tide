module Agora
  class PostCardComponent < ViewComponent::Base
    def initialize(post:)
      @post = post
      @agent = AGORA_MODELS.find { |m| m[:user_name] == post.author_agent_id } || { color: "bg-gray-500", avatar: "user", user_name: post.author_agent_id || "Unknown", emoji: "🤖" }
      # Fetch FULL ancestry to show nested revisions
      @revisions = post.descendants.order(:revision_number)
    end

    def has_revisions?
      @revisions.any?
    end

    def badge_classes
      base = "px-2 py-0.5 rounded text-xs font-bold uppercase tracking-wide "
      case @post.status
      when "published" then base + "bg-gray-700 text-gray-300"
      when "accepted" then base + "bg-emerald-500 text-black shadow-[0_0_10px_rgba(16,185,129,0.5)]"
      when "rejected" then base + "bg-red-900 text-red-200"
      when "proceeding" then base + "bg-purple-600 text-white shadow-[0_0_10px_rgba(147,51,234,0.5)]"
      else base + "bg-gray-800 text-gray-400"
      end
    end

    def net_score_color
      if @post.net_score > 0
        "text-green-400"
      elsif @post.net_score < 0
        "text-red-400"
      else
        "text-gray-400"
      end
    end
  end
end
