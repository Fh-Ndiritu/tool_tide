class Admin::TextRequestsController < ApplicationController
  before_action :set_text_request, only: [ :edit, :toggle_display, :destroy ]

  def index
    @text_requests = TextRequest.complete

    @text_requests = @text_requests.by_user(params[:id]) if params[:id].present?
    @text_requests = @text_requests.by_admin if params[:admin].present?
    @text_requests = @text_requests.by_visibility(params[:visibility]) if params[:visibility].present?
    @text_requests = @text_requests.where(trial_generation: true) if params[:trial].present?

    day_offset = params[:day].to_i
    @text_requests = @text_requests.where(updated_at: day_offset.days.ago.all_day)
  end

  def show
    @text_request = TextRequest.find(params[:id])
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
