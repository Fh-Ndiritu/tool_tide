# app/channels/landscape_channel.rb
class LandscapeChannel < ApplicationCable::Channel
  def subscribed
    # Check if a landscape_id is provided in the parameters
    # and use it to create a unique stream name.
    # If landscape_id is missing, you might want to reject the subscription or
    # handle it differently.
    if params[:landscape_id].present?
      stream_from "landscape_channel_#{params[:landscape_id]}"
      Rails.logger.info "Subscribed to landscape_channel_#{params[:landscape_id]}"
    else
      reject # Reject subscription if landscape_id is not provided
      Rails.logger.warn "LandscapeChannel subscription rejected: missing landscape_id"
    end
  end

  def unsubscribed
    Rails.logger.info "Unsubscribed from landscape_channel"
  end

  # You can define actions that the client can call on this channel
  # For example, to receive client messages specific to this landscape
  def receive(data)
    # Process incoming data from the client for this specific landscape
    Rails.logger.info "Received data for landscape_channel_#{params[:landscape_id]}: #{data.inspect}"
    # Example: If clients can send messages, you might process them here
    # and then broadcast back to this specific stream:
    # ActionCable.server.broadcast("landscape_channel_#{params[:landscape_id]}", { message: "Processed: #{data['text']}" })
  end
end
