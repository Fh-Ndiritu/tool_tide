class AddDesignToAgenticRuns < ActiveRecord::Migration[8.0]
  def change
    add_reference :agentic_runs, :design, null: true, foreign_key: true
  end
end
