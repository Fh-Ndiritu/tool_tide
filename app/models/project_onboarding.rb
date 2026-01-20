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
end
