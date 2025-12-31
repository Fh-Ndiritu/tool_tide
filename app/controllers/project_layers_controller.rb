class ProjectLayersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def create
    @layer = @project.layers.build(layer_params)
    @layer.layer_type = :original if @project.layers.none?
    @layer.layer_type ||= :mask # Default to mask if not original

    if @layer.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("sidebar_layers", partial: "project_layers/layer", locals: { layer: @layer }),
            turbo_stream.replace("empty_state", partial: "projects/empty_state", locals: { project: @project, hidden: true }),
            turbo_stream.replace("canvas_wrapper", partial: "projects/canvas_wrapper", locals: { initial_layer: @layer, hidden: false })
          ]
        end
        format.html { redirect_to project_path(@project) }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_path(@project), alert: "Failed to create layer." }
      end
    end
  end

  def generate
    prompt = params[:prompt]
    preset = params[:preset]
    variations = params[:variations].to_i
    cost = GOOGLE_IMAGE_COST # Global constant
    total_cost = cost * variations

    # Credit Check
    if current_user.pro_engine_credits < total_cost
      return respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("sidebar_layers", "<div class='text-red-500 p-2'>Insufficient credits</div>") }
      end
    end

    # Determine Transformation Type
    transformation_type = if preset.present?
                           :preset
    elsif prompt.present?
                           :prompt
    else
                           :none
    end

    ActiveRecord::Base.transaction do
      # Deduct Credits
      current_user.charge_pro_cost!(total_cost)

      # Create First Layer (with Mask if present)
      parent_layer_id = params[:parent_layer_id]

      first_layer = @project.layers.create!(
        layer_type: :generation,
        transformation_type: transformation_type,
        prompt: prompt,
        preset: preset,
        parent_layer_id: parent_layer_id,
        status: :pending
      )

      if params[:mask_data].present?
        decoded_data = Base64.decode64(params[:mask_data].split(",")[1])
        first_layer.mask.attach(
          io: StringIO.new(decoded_data),
          filename: "mask.png",
          content_type: "image/png"
        )
      end

      generated_layers = [ first_layer ]

      # Create Variations using dup
      (variations - 1).times do
        # dup creates a shallow copy, but we need to ensure it's saved in the same transaction
        new_layer = first_layer.dup
        new_layer.save!

        # Attach the same mask blob to the variant if it exists
        if first_layer.mask.attached?
          new_layer.mask.attach(first_layer.mask.blob)
        end

        generated_layers << new_layer
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("sidebar_layers", partial: "project_layers/layer", collection: generated_layers)
        end
      end
    end
  end

  def view
    @layer = @project.layers.find(params[:id])
    @layer.increment_views!
    head :ok
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def layer_params
    params.require(:project_layer).permit(:image, :layer_type, :parent_layer_id, :prompt, :preset)
  end
end
