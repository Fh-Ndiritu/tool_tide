class ProjectLayersController < ApplicationController
  before_action :set_project
  before_action :set_design, only: [ :create ]
  before_action :set_project_layer, only: %i[show update retry_generation cancel_generation]

  def show
    @project_layer.mark_as_viewed!
    @project_layer.design.update(current_project_layer: @project_layer)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project, design_id: @project_layer.design_id) }
    end
  end

  def create
    parent_layer = @design.project_layers.find_by(id: params[:parent_layer_id]) || @design.project_layers.roots.first

    variations_count = (params[:variations].presence || 1).to_i.clamp(1, 4)

    ActiveRecord::Base.transaction do
      variations_count.times do |i|
        # Use explicit generation_type from frontend, fallback to style_preset logic as safety
        generation_type = params[:generation_type].presence || :style_preset

        layer = @design.project_layers.build(
          project: @project,
          parent: parent_layer,
          layer_type: "generated",
          generation_type: generation_type,
          auto_fix_id: params[:auto_fix_id],
          prompt: params[:prompt],
          preset: params[:preset],
          ai_assist: params[:ai_assist] == "true",
          progress: :preparing,
          model: params[:model]
        )

        if layer.save
          if params[:mask_data].present?
             decoded_data = Base64.decode64(params[:mask_data].split(",")[1])
             layer.mask.attach(
               io: StringIO.new(decoded_data),
               filename: "mask.png",
               content_type: "image/png"
             )
          end

          ProjectGenerationJob.perform_later(layer.id)
        else
          # Collect error from first failing layer and return
          error_message = layer.errors.full_messages.to_sentence
          flash.now[:alert] = error_message

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash"), status: :unprocessable_content
            }
            format.html { redirect_to project_path(@project, design_id: @design.id), alert: error_message }
          end
          raise ActiveRecord::Rollback
        end
      end

      # Mark AutoFix as applied if provided
      if params[:auto_fix_id].present?
        auto_fix = AutoFix.find_by(id: params[:auto_fix_id])
        auto_fix&.applied!
      end
    end

    # Guard against double render if validation failed inside transaction
    return if performed?

    # Force active layer to remain on parent (to prevent jumping to new incomplete layer)
    @design.update(current_project_layer: parent_layer) if parent_layer

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to project_path(@project, design_id: @design.id), notice: "#{variations_count} variations starting." }
    end
  rescue StandardError => e
    Rails.logger.error("Layer Create Error: #{e.message}")
    flash.now[:alert] = "An unexpected error occurred: #{e.message}"
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash"), status: :unprocessable_content
      }
      format.html { redirect_to project_path(@project, design_id: @design.id), alert: "An unexpected error occurred." }
    end
  end

  def update
    if @project_layer.update(project_layer_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@project_layer) }
        format.html { redirect_to project_path(@project, design_id: @project_layer.design_id) }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html { render :show, status: :unprocessable_content }
      end
    end
  end

  def retry_generation
    if current_user.can_afford_generation?(@project_layer.model)
      @project_layer.update(progress: :preparing, user_msg: nil, error_msg: nil)
      ProjectGenerationJob.perform_later(@project_layer.id)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@project_layer) }
        format.html { redirect_to project_path(@project, design_id: @project_layer.design_id), notice: "Retrying generation..." }
      end
    else
      msg = "Insufficient credits. <a href='#{low_credits_path(return_to: project_path(@project))}' class='underline font-bold' data-turbo-frame='_top'>Top up now</a>"
      flash.now[:alert] = msg.html_safe

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash") }
        format.html { redirect_to project_path(@project, design_id: @project_layer.design_id), alert: "Insufficient credits." }
      end
    end
  end

  def cancel_generation
    user = @project_layer.project.user
    refunded = false
    cancelled = false

    # Atomic lock to prevent race condition with ProjectGenerationJob
    @project_layer.with_lock do
      if [ "preparing", "processing" ].include?(@project_layer.progress)
        # 1. Update status to failed immediately
        @project_layer.update!(
          progress: :failed,
          user_msg: "Cancelled by user.",
          error_msg: "Cancelled by user request."
        )
        cancelled = true

        # 2. Kill any queued/scheduled Solid Queue jobs for this layer
        cancel_queued_jobs(@project_layer.id)

        # 3. Refund logic (nested lock on user)
        cost = if @project_layer.generation_type == "upscale"
                 GOOGLE_UPSCALE_COST
        else
                 MODEL_COST_MAP[@project_layer.model] || GOOGLE_PRO_IMAGE_COST
        end

        user.with_lock do
          has_been_charged = CreditSpending.exists?(
            user: user,
            trackable: @project_layer,
            transaction_type: :spend
          )

          if has_been_charged
            user.pro_engine_credits += cost
            user.save!
            CreditSpending.create!(
              user: user,
              amount: cost,
              transaction_type: :refund,
              trackable: @project_layer
            )
            refunded = true
          end
        end
      else
        flash.now[:alert] = "Cannot cancel a layer that is already #{@project_layer.progress}."
      end
    end

    if cancelled
      flash.now[:notice] = refunded ? "Generation cancelled and credits refunded." : "Generation cancelled."
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace(@project_layer),
          turbo_stream.update("user_credits_count", partial: "projects/credits_count", locals: { user: user.reload })
        ]
      }
      format.html { redirect_to project_path(@project, design_id: @project_layer.design_id) }
    end
  end

  private

  def set_project
    # Handle both nested and flat if necessary, but routes are nested
    if params[:project_id]
      @project = current_user.projects.find(params[:project_id])
    elsif @project_layer
      @project = @project_layer.project
    end
  end

  def set_design
    @design = @project.designs.find(params[:design_id])
  end

  def set_project_layer
    @project_layer = ProjectLayer.image_variants.find(params[:id])
  end

  def project_layer_params
    params.require(:project_layer).permit(:prompt, :preset, :transformation_type, :model)
  end

  def cancel_queued_jobs(layer_id)
    # Find and discard any Solid Queue jobs for ProjectGenerationJob with this layer_id
    # Jobs store arguments as JSON, so we search for the layer_id in the arguments column
    SolidQueue::Job.where(class_name: "ProjectGenerationJob")
                   .where("arguments LIKE ?", "%#{layer_id}%")
                   .find_each do |job|
      Rails.logger.info("Cancelling queued job #{job.id} for layer #{layer_id}")
      job.destroy
    end
  rescue StandardError => e
    Rails.logger.error("Failed to cancel queued jobs for layer #{layer_id}: #{e.message}")
    # Don't raise - cancellation should still proceed even if job cleanup fails
  end
end
