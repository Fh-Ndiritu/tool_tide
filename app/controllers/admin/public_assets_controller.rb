module Admin
  class PublicAssetsController < BaseController
    def index
      @public_assets = PublicAsset.order(created_at: :desc)
      @public_asset = PublicAsset.new
    end

    def create
      @public_asset = PublicAsset.new(public_asset_params)

      if @public_asset.save
        redirect_to admin_public_assets_path, notice: "Public asset uploaded successfully."
      else
        @public_assets = PublicAsset.order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      @public_asset = PublicAsset.find(params[:id])
      @public_asset.destroy
      redirect_to admin_public_assets_path, notice: "Public asset deleted successfully."
    end

    private

    def public_asset_params
      params.require(:public_asset).permit(:name, :image)
    end
  end
end
