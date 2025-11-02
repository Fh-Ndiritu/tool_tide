class CreateAudios < ActiveRecord::Migration[8.0]
  def change
    create_table :audios do |t|
      t.json :content
      t.json :style_prompt

      t.timestamps
    end
  end
end
