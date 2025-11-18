class IssuesController < ApplicationController
  before_action :set_issue, only: %i[ show edit update destroy ]

  # GET /issues or /issues.json
  def index
    # We will expand this later to handle filtering/sorting
    # @issues = Issue.where.not(progress: :archived).includes(:user).order(created_at: :desc)
    @issues = Issue.all.includes(:user).order(created_at: :desc)
  end

  # GET /issues/1 or /issues/1.json
  def show
  end

  # GET /issues/new
  def new
    @issue = Issue.new
  end

  # GET /issues/1/edit
  # NOTE: Restrict edit access to admins or the original submitter
  def edit
  end

  # POST /issues or /issues.json (User Submission)
  def create
    # Use the safe_issue_params for user-submitted data (excludes admin fields)
    @issue = Issue.new(safe_issue_params)

    # Automatically set the user_id for the submitted issue
    # Assuming current_user is available after authentication
    @issue.user_id = current_user.id # REMOVE this line if you don't have authentication yet

    respond_to do |format|
      if @issue.save
        # Use Turbo Stream to broadcast the new issue to the index list instantly
        # NOTE: This line requires setting up the stream logic on the index page
        # turbo_stream.prepend("issues", partial: "issues/issue", locals: { issue: @issue })

        format.html { redirect_to @issue, notice: "Issue was successfully submitted." }
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
            # If the issue is archived, remove it from the list
            render turbo_stream: turbo_stream.remove(@issue)
          else
            # Otherwise, replace the card with the updated content (new status, date, etc.)
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
        # If update fails, replace the card with the edit form showing errors (if applicable)
        # This assumes the failure came from an inline form submission (like the admin status form)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@issue, partial: "issues/form", locals: { issue: @issue }), status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @issue.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /issues/1 or /issues/1.json
  def destroy
    @issue.destroy!

    respond_to do |format|
      format.html { redirect_to issues_path, notice: "Issue was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_issue
      # Corrected use of expect
      @issue = Issue.find(params[:id])
    end

    # Parameters allowed for a general user submitting a new issue
    def safe_issue_params
      params.require(:issue).permit(:title, :body, :category)
      # user_id and progress (default: todo) are handled in the controller
    end

    # Parameters allowed for updates (Admin can change status and delivery date)
    def restricted_issue_params
      # Use a conditional permit if you need to enforce roles:
      # If current_user.admin?
      params.require(:issue).permit(:title, :body, :category, :progress, :delivery_date)
      # Else
      # params.require(:issue).permit(:title, :body, :category)
    end
end
