class WelcomeFollowUpJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # Determine activity type
    # If mobile user -> :mobile_project_studio
    # If desktop user:
    #   Priority: Projects -> Smart Fix -> Autofix -> None
    #   We check if they have created any requests of these types

    activity_type = if user.last_sign_in_device_type == "mobile"
      :mobile_project_studio
    elsif !user.projects.exists?
      :desktop_no_projects
    elsif !user.projects.joins(:project_layers).merge(ProjectLayer.style_preset).exists?
      :desktop_style
    elsif !user.projects.joins(:project_layers).merge(ProjectLayer.smart_fix).exists?
      :desktop_smart_fix
    elsif !user.projects.joins(:project_layers).merge(ProjectLayer.autofix).exists? && !user.projects.joins(:project_layers).where.not(project_layers: { auto_fix_id: nil }).exists?
      :desktop_autofix
    else
      :none
    end

    UserMailer.with(user: user, activity_type: activity_type).welcome_follow_up_email.deliver_now
  end
end
