class AddAnalysisToSketchRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :sketch_requests, :analysis, :text
    add_column :sketch_requests, :recommended_angle, :string
  end
end
