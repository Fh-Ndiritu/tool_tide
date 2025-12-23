class PublicAssetsController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  def show
    @public_asset = PublicAsset.find_by!(uuid: params[:uuid])
    # render layout: "public" # Use a minimal layout if available, or application layout
  rescue ActiveRecord::RecordNotFound
    render plain: "Asset not found", status: :not_found
  end
end
