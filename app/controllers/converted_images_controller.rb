# app/controllers/converted_images_controller.rb
# frozen_string_literal: true

class ConvertedImagesController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    # Retrieve the paths from flash. Flash only lasts for one redirect.
    @converted_file_paths = flash[:converted_file_paths] || []

    # If you need persistence beyond one redirect, you'd save these paths
    # to a database record (e.g., a "ConversionBatch" model) and retrieve them here.
  end

  def download
    # SANITIZE INPUT: Extract only the filename to prevent directory traversal
    requested_filename = params[:filename]
    # Construct the full, safe path to the temporary file
    # Security Note: File.basename(params[:filename]) is used to sanitize user input
    # and prevent path traversal, ensuring files are only served from 'tmp/conversions'.
    file_path = Rails.root.join('tmp', 'conversions', File.basename(requested_filename))

    if File.exist?(file_path) && File.readable?(file_path)
      # Determine content type for the browser
      mime_type = ImageFormatHelper.mime_type_for(File.extname(file_path).delete('.')) || 'application/octet-stream'

      # Brakeman suppress: SendFile, confidence: Weak, reason: "False positive. User input is sanitized with File.basename to prevent path traversal, ensuring access is strictly within 'tmp/conversions' directory."
      send_file file_path,
                filename: File.basename(file_path),
                type: mime_type,
                disposition: 'attachment' # 'attachment' prompts download, 'inline' tries to display in browser
    else
      redirect_to converted_images_path, alert: 'The requested file was not found or is no longer available.'
    end
  end
end
