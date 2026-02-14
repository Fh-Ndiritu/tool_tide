class DropBlogsAudiosAndOrphans < ActiveRecord::Migration[8.0]
  def up
    drop_table :blogs
    drop_table :blog_locations
    drop_table :audios
    drop_table :video_clips
    drop_table :vlogs
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
