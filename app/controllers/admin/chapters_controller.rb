module Admin
  class ChaptersController < Admin::BaseController
    skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

    def index
      @chapters = Chapter.order(created_at: :desc)
    end

    def show
      @chapter = Chapter.find(params[:id])
      respond_to do |format|
        format.html
        format.json do
          render json: @chapter.as_json(include: :subchapters).merge(
            video_url: @chapter.video.attached? ? rails_blob_url(@chapter.video) : nil,
            status: @chapter.status
          )
        end
      end
    end

    def new
      @chapter = Chapter.new
    end

    def create
      @chapter = Chapter.new(chapter_params)
      @chapter.status = "pending"

      respond_to do |format|
        if @chapter.save
          VideoProductionJob.perform_later(@chapter.id)
          format.html { redirect_to admin_chapter_path(@chapter), notice: "Chapter was successfully created. Video production started." }
          format.json { render json: @chapter, status: :created }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @chapter.errors, status: :unprocessable_entity }
        end
      end
    end

    private

    def chapter_params
      params.require(:chapter).permit(:title, :content, :video_mode)
    end
  end
end
