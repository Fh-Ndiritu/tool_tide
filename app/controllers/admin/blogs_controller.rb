module Admin
  class BlogsController < ApplicationController
    before_action :authenticate_user! # Ensure admin check if regular users can access admin namespace, usually logic is in layout or before_action

    def index
      @blogs = Blog.order(created_at: :desc)
    end

    def new
      @blog = Blog.new
    end

    def create
      @blog = Blog.new(blog_params)
      if @blog.save
        BlogGenerationJob.perform_later(@blog.id)
        redirect_to admin_blogs_path, notice: "Blog generation for #{@blog.location_name} has been queued."
      else
        render :new
      end
    end

    def show
      @blog = Blog.find(params[:id])
    end

    private

    def blog_params
      params.require(:blog).permit(:location_name)
    end
  end
end
