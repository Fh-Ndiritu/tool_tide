class CreateChapters < ActiveRecord::Migration[8.0]
  def change
    create_table :chapters do |t|
      t.string :title
      t.text :content
      t.string :video_mode
      t.string :status

      t.timestamps
    end
  end
end
