class LandscapingGuidesController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  def show
    # Find blog by slug matching the route parameter
    slug = "landscaping-guides/#{params[:slug]}"
    @blog = Blog.find_by!(slug: slug, published: true)

    # Set Meta Tags
    if @blog.metadata.present?
      @page_title = @blog.metadata["title"]
      @page_description = @blog.metadata["description"]
      # keywords = @blog.metadata["primary_keyword"]
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Guide not found."
  end
end
