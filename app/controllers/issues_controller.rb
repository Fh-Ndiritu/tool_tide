class IssuesController < ApplicationController
  before_action :set_issue, only: %i[ show edit update destroy ]
  include ActionView::RecordIdentifier

  def index
    @issues = Issue.where.not(progress: :archived).includes(:user).order(created_at: :desc)
    @features = Feature.where.not(progress: [ :archived ]).order(progress: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @issue = Issue.new
  end

  def edit
  end

  def create
    @issue = Issue.new(safe_issue_params)
    @issue.user_id = current_user.id

    respond_to do |format|
      if @issue.save
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("issues", partial: "issues/issue_card", locals: { issue: @issue }) }

        format.html { redirect_to issues_path, notice: "Issue was successfully submitted." }
        format.json { render :show, status: :created, location: @issue }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @issue.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @issue.update(restricted_issue_params)

        format.turbo_stream do
          if @issue.archived?
            render turbo_stream: turbo_stream.remove(@issue)
          elsif params[:issue].key?(:title) || params[:issue].key?(:body)
            render turbo_stream: turbo_stream.replace(
              dom_id(@issue, :content),
              partial: "issues/issue_card_content",
              locals: { issue: @issue }
            )
          else
            render turbo_stream: turbo_stream.replace(
              @issue,
              partial: "issues/issue_card",
              locals: { issue: @issue }
            )
          end
        end

        format.html { redirect_to @issue, notice: "Issue was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @issue }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@issue, :content), partial: "issues/form_inline", locals: { issue: @issue }), status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @issue.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @issue.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@issue) }
      format.html { redirect_to issues_path, notice: "Issue was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_issue
      @issue = Issue.find(params[:id])
    end

    def safe_issue_params
      params.require(:issue).permit(:title, :body, :category)
    end

    def restricted_issue_params
      params.require(:issue).permit(:title, :body, :category, :progress, :delivery_date)
    end
end
