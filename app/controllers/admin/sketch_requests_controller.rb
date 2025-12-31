class Admin::SketchRequestsController < Admin::BaseController
  include ActionView::RecordIdentifier
  before_action :set_sketch_request, only: [ :show, :edit, :toggle_display, :destroy ]

  def index
    @sketch_requests = if params[:day].present?
      SketchRequest.complete.where(updated_at: params[:day].to_i.days.ago.all_day)
    elsif params[:id]
      SketchRequest.complete.by_user(params[:id])
    elsif params[:admin]
      SketchRequest.complete.by_admin
    elsif params[:visibility]
      SketchRequest.complete.by_visibility(params[:visibility])
    else
      SketchRequest.complete.where(updated_at: Time.zone.today.all_day)
    end
  end

  def show
  end

  def edit
  end

  def destroy
    if @sketch_request.user.admin?
      @sketch_request.destroy
      redirect_to admin_sketch_requests_path, notice: "Sketch request destroyed."
    else
      redirect_to admin_sketch_requests_path, alert: "You can only destroy admin requests."
    end
  end

  def toggle_display
    if @sketch_request.everyone?
      @sketch_request.personal!
    else
      @sketch_request.everyone!
    end
    @sketch_request.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(@sketch_request), partial: "admin/sketch_requests/sketch_request", locals: { sketch_request: @sketch_request })
      end
      format.html { redirect_to admin_sketch_requests_path, status: :see_other }
    end
  end

  private

  def set_sketch_request
    @sketch_request = SketchRequest.find(params[:id])
  end
end
