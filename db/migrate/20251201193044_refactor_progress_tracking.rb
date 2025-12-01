class RefactorProgressTracking < ActiveRecord::Migration[8.0]
  def change
    # add_column :chapters, :progress, :integer, default: 0
    add_column :subchapters, :progress, :integer, default: 0
  end
end
