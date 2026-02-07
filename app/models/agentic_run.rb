class AgenticRun < ApplicationRecord
  belongs_to :project
  belongs_to :design, optional: true

  enum :status, {
    pending: 0,
    running: 10,
    paused: 20,
    completed: 30,
    failed: 40,
    cancelled: 50
  }

  after_commit -> {
    broadcast_replace_to [ project, :sketch_run ], target: "sketch_run_status", partial: "projects/tools/sketch_run_status", locals: { run: self }
  }
end
