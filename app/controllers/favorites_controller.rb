class FavoritesController < AppController
  before_action :authenticate_user!

  # POST /favorites (Action: Like or Dislike)
  def create
    @favoritable = find_favoritable
    type_of_vote = params[:vote_type] == "dislike" ? false : true # true for 'like', false for 'dislike'

    if @favoritable
      # Find or initialize a favorite record
      @favorite = current_user.favorites.find_or_initialize_by(favoritable: @favoritable)

      # Set the liked status and save
      @favorite.liked = type_of_vote
      @favorite.save!

      respond_to do |format|
        format.html { redirect_back fallback_location: root_path }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "favorite_#{@favorite.favoritable.to_global_id.to_param}",
            partial: "favorites/favorite_button",
            locals: { favoritable: @favorite.favoritable, favorite: @favorite }
          )
        end
      end
    else
      redirect_back fallback_location: root_path, alert: "Could not find item to favorite."
    end
  end

  # DELETE /favorites/:id (Action: Remove vote entirely)
  def destroy
    @favorite = current_user.favorites.find(params[:id])
    @favoritable = @favorite.favoritable
    @favorite.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "favorite_#{@favoritable.to_global_id.to_param}",
          partial: "favorites/favorite_button",
          locals: { favoritable: @favoritable, favorite: nil } # Pass nil to show neutral state
        )
      end
    end
  end

  def index
    @favorites = current_user.favorites.liked.includes(:favoritable).order(created_at: :desc)
  end

  private

  def find_favoritable
    params[:favoritable_type].constantize.find(params[:favoritable_id])
  rescue NameError, ActiveRecord::RecordNotFound
    nil
  end
end
