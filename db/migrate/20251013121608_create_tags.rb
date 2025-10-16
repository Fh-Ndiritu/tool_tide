class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.integer :tag_class
      t.text :title

      t.timestamps
    end
  end
end
