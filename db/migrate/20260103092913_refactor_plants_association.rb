class RefactorPlantsAssociation < ActiveRecord::Migration[8.0]
  def up
    # 1. Clear old data as per user instruction (new structure requires clean slate for simplicty)
    execute "DELETE FROM mask_request_plants"
    execute "DELETE FROM plants"

    # 2. Drop the join table
    drop_table :mask_request_plants

    # 3. Add foreign key to plants
    add_reference :plants, :mask_request, null: false, foreign_key: true
  end

  def down
    # Irreversible migration if we consider data loss, but structually:
    remove_reference :plants, :mask_request

    create_table :mask_request_plants do |t|
      t.references :mask_request, null: false, foreign_key: true
      t.references :plant, null: false, foreign_key: true
      t.integer :quantity
      t.timestamps
    end
  end
end
