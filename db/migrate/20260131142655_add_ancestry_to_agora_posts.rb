class AddAncestryToAgoraPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_posts, :ancestry, :string
    add_index :agora_posts, :ancestry
  end
end
