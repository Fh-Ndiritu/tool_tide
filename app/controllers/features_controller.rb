class FeaturesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]
  before_action :set_feature, only: %i[ show edit update destroy ]
  include ActionView::RecordIdentifier

  def index
    # Note: Features are already loaded in IssuesController#index for the dashboard context.
    # This action remains for direct routing/scoping if needed later.
    @features = Feature.all
  end

  def show
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@feature, :content),
          partial: "features/feature_card_content",
          locals: { feature: @feature }
        )
      end
    end
  end

  def new
    @feature = Feature.new
  end

  def edit
  end

  def create
    @feature = Feature.new(feature_params)

    respond_to do |format|
      if @feature.save
        # Assuming we want to broadcast new features to the roadmap list like issues
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("features", partial: "features/feature_card", locals: { feature: @feature }) }

        format.html { redirect_to @feature, notice: "Feature was successfully created." }
        format.json { render :show, status: :created, location: @feature }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @feature.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @feature.update(feature_params)

        format.turbo_stream do
          if @feature.archived? || @feature.released?
            render turbo_stream: turbo_stream.remove(@feature)
          else
            # If successfully updated, replace the form (dom_id(@feature, :content))
            # with the updated card content, or the whole card if it's a status change
            render turbo_stream: turbo_stream.replace(
              @feature, # Replace the whole card to handle status changes/re-sorting/styling
              partial: "features/feature_card",
              locals: { feature: @feature }
            )
          end
        end

        format.html { redirect_to @feature, notice: "Feature was successfully updated.", status: :see_other }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@feature, :content),
            partial: "features/form_inline",
            locals: { feature: @feature }
          ), status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @feature.destroy!

    respond_to do |format|
      format.html { redirect_to features_path, notice: "Feature was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_feature
      @feature = Feature.find(params[:id])
    end

    def feature_params
      # Standardized to use require/permit for strong parameters
      params.require(:feature).permit(:title, :description, :progress, :delivery_date)
    end
end
