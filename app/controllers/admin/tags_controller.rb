class Admin::TagsController < ApplicationController
  before_action :set_mask_request, only: :create
  before_action :set_tag, only: :create

  def create
    @tagging =  @mask_request.generation_taggings.find_or_initialize_by(tag: @tag)

    respond_to do |format|
      if @tagging.save
        format.html { redirect_to admin_mask_requests_index_path, notice: "Tag was successfully created." }
      else
        flash[:alert] = @tagging.errors.full_messages.join(", ")
        format.html { redirect_to admin_mask_requests_index_path }
      end
    rescue StandardError => e
      Rails.logger.error("Failed to create tag: #{e.message}")
      flash[:alert] = "An unexpected error occurred: #{e.message}"

      format.html { redirect_to admin_mask_requests_index_path }
    end
  end

  private

  def tag_params
    params.expect(tag: [ :tag_class, :title ])
  end

  def set_mask_request
    @mask_request = MaskRequest.find(params.dig(:tag, :mask_request_id))
  end

  def set_tag
    @tag = Tag.find_or_create_by!(tag_params)
  end
end
