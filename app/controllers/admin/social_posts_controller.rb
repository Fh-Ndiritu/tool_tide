class Admin::SocialPostsController < Admin::BaseController


    def index
      @social_posts = SocialPost.order(created_at: :desc).limit(50)
    end

    def show
      @social_post = SocialPost.find(params[:id])
    end

    def generate
      SocialMedia::ContentGenerator.perform
      redirect_to admin_social_posts_path, notice: "Generating posts in background..."
    rescue StandardError => e
      redirect_to admin_social_posts_path, alert: "Generation failed: #{e.message}"
    end

    def update
      @social_post = SocialPost.find(params[:id])
      if @social_post.update(social_post_params)
        SocialMedia::PerformanceAnalyzer.perform(@social_post)
        redirect_to admin_social_post_path(@social_post), notice: "Screenshot uploaded. Analyzing..."
      else
        render :show, alert: "Failed to upload."
      end
    end

    private

    def social_post_params
      params.require(:social_post).permit(:performance_screenshot)
    end
  end
