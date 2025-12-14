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
        BlogGeneratorService.perform(@blog.id)
        redirect_to admin_blogs_path, notice: "Blog for #{@blog.location_name} is being generated."
      else
        render :new
      end
    rescue => e
      flash[:alert] = "Generation failed: #{e.message}"
      @blog.destroy if @blog.persisted?
      render :new
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
