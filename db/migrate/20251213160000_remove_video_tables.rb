class RemoveVideoTables < ActiveRecord::Migration[8.0]
  def change
    remove_reference :audios, :narration_scene, index: true, if_exists: true

    drop_table :image_prompts, if_exists: true
    drop_table :narration_scenes, if_exists: true
    drop_table :subchapters, if_exists: true
    drop_table :chapters, if_exists: true
  end
end
