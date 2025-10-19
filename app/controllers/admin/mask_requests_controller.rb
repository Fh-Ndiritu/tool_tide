class Admin::MaskRequestsController < ApplicationController
  include ActionView::RecordIdentifier
  def index
    @mask_requests = if params[:day].present?
      MaskRequest.complete.where(updated_at: params[:day].to_i.days.ago.all_day)
    elsif params[:id]
      MaskRequest.complete.joins(:canva).where(canva: { user_id: params[:id] })
    elsif params[:admin]
      MaskRequest.complete.joins(canva: :user).where(user: { admin: true })
    elsif params[:visibility]
      MaskRequest.complete.where(visibility: params[:visibility])
    else
      MaskRequest.complete.where(updated_at: Time.zone.today.all_day)
    end
  end

  def edit
  end

  def toggle_display
    @mask_request = MaskRequest.find(params[:id])
    if @mask_request.everyone?
      @mask_request.personal!
    else
        @mask_request.everyone!
    end
    @mask_request.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(@mask_request), partial: "admin/mask_requests/mask_request", locals: { mask_request: @mask_request })
      end
    end
  end
end
