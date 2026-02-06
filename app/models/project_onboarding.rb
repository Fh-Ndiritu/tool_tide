class ProjectOnboarding < ApplicationRecord
  belongs_to :user

  enum :style_presets_status, {
    not_started: 0,
    intro_seen: 10,
    select_seen: 20,
    paint_seen: 30,
    variations_seen: 40,
    generate_seen: 50,
    layer_seen: 60,
    completed: 100
  }, prefix: true

  enum :smart_fix_status, {
    not_started: 0,
    intro_seen: 10,
    completed: 100
  }, prefix: true

  enum :auto_fix_status, {
    not_started: 0,
    intro_seen: 10,
    completed: 100
  }, prefix: true

  def should_show_smart_fix_warning?
    # return true
    return false if smart_fix_warning_seen?

    # Check if user has > 5 smart fix requests and ALL of them used AI assist
    user_layers = ProjectLayer.joins(:project).where(projects: { user_id: user.id })
    smart_fix_count = user_layers.where(generation_type: :smart_fix).count
    return false if smart_fix_count <= 5

    # Check if ALL smart fix requests used AI assist
    # If any smart fix request has ai_assist: false, we don't show the warning
    !user_layers.where(generation_type: :smart_fix, ai_assist: false).exists?
  end
end
