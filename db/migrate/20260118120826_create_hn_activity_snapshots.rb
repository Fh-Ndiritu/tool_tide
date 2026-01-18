class CreateHnActivitySnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :hn_activity_snapshots do |t|
      t.bigint :max_item_id, null: false
      t.integer :items_count, null: false, default: 0
      t.integer :day_of_week
      t.integer :time_bucket
      t.string :uuid

      t.timestamps
    end
    add_index :hn_activity_snapshots, :uuid, unique: true
    add_index :hn_activity_snapshots, [:day_of_week, :time_bucket]
  end
end
