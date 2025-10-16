class Admin::TagsController < ApplicationController
  before_action :set_tag, only: :create
  before_action :set_tagging, only: :create

  def create
    respond_to do |format|
      if @tagging.save
        success_path = determine_redirect_path(@record, to: :index)
        format.html { redirect_to success_path, notice: "Tag was successfully created." }
      else
        failure_path = determine_redirect_path(@record, to: :edit)
        flash[:alert] = @tagging.errors.full_messages.join(", ")
        format.html { redirect_to failure_path }
      end
    rescue StandardError => e
      Rails.logger.error("Failed to create tag: #{e.message}")
      flash[:alert] = "An unexpected error occurred: #{e.message}"

      error_path = determine_redirect_path(@record, to: :edit)
      format.html { redirect_to error_path }
    end
  end

  private

  def determine_redirect_path(record, to:)
    resource_prefix = [ :admin ]

    case record.class.to_s
    when "MaskRequest"
      if to == :index
        main_app.url_for(resource_prefix + [ :mask_requests ])
      else
        main_app.url_for(resource_prefix + [ :edit, record ])
      end
    when "TextRequest"
      if to == :index
        main_app.url_for(resource_prefix + [ :text_requests ])
      else
        main_app.url_for(resource_prefix + [ :edit, record ])
      end
    else
      admin_root_path
    end
  end

  def set_tagging
    @record = if params.dig(:tag, :mask_request_id)
      MaskRequest.find_by(id: params.dig(:tag, :mask_request_id))
    elsif params.dig(:tag, :text_request_id)
      TextRequest.find_by(id: params.dig(:tag, :text_request_id))
    end

    unless @record
      raise ActiveRecord::RecordNotFound, "MaskRequest or TextRequest ID not found."
    end

    @tagging = @record.generation_taggings.find_or_initialize_by(tag: @tag)
  end

  def tag_params
    params.require(:tag).permit(:tag_class, :title)
  end

  def set_tag
    @tag = Tag.find_or_create_by!(tag_params)
  end
end
