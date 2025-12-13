class Admin::TextRequestsController < ApplicationController
  before_action :set_text_request, only: [ :edit, :toggle_display, :destroy ]

  def index
     @text_requests = if params[:day].present?
      TextRequest.complete.where(updated_at: params[:day].to_i.days.ago.all_day)
     elsif params[:id]
      TextRequest.complete.by_user(params[:id])
     elsif params[:admin]
      TextRequest.complete.by_admin
     elsif params[:visibility]
      TextRequest.complete.by_visibility(params[:visibility])
     else
      TextRequest.complete.where(updated_at: Time.zone.today.all_day)
     end
  end

  def edit
  end

  def destroy
    if @text_request.user.admin?
      @text_request.destroy
      redirect_to admin_text_requests_path, notice: "Text request destroyed."
    else
      redirect_to admin_text_requests_path, alert: "You can only destroy admin requests."
    end
  end

  def toggle_display
    if @text_request.everyone?
      @text_request.personal!
    else
        @text_request.everyone!
    end
    @text_request.reload

   redirect_to admin_text_requests_path, status: :see_other
  end

  private

  def set_text_request
    @text_request = TextRequest.find(params[:id])
  end
end
