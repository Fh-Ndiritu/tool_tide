module Marketing
  class PublicAssetsController < MarketingController
    def show
      @public_asset = PublicAsset.find_by!(uuid: params[:uuid])
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Asset not found", status: :not_found
  end
end
