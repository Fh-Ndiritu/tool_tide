# frozen_string_literal: true

# Eager load Agora services to ensure they're available in console and jobs
require_dependency "agora/llm_client" if defined?(Rails) && Rails.env.development?
require_dependency "agora/vertex_ai_client" if defined?(Rails) && Rails.env.development?
