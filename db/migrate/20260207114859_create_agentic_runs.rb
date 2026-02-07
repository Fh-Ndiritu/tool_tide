class CreateAgenticRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agentic_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :status, default: 0
      t.json :logs, default: []
      t.string :job_id

      t.timestamps
    end
  end
end
