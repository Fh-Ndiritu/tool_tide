module Agora
  class LLMClient
    def self.client_for(agent_config)
      if agent_config[:provider] == :vertex
        Agora::VertexAIClient.new(
          model_name: agent_config[:model_name],
          publisher: agent_config[:publisher] || "google",
          location: agent_config[:location]
        )
      else
        CustomRubyLLM.context(model: agent_config[:model_name])
      end
    end
  end
end
