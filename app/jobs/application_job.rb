# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
  protected

  def broadcast_system_status(message)
    Turbo::StreamsChannel.broadcast_update_to(
      "agora_system_status",
      target: "agora_system_status",
      html: "<span id='agora_system_status' class='text-xs text-indigo-400 font-mono animate-pulse'>#{message}</span>"
    )
  end
end
