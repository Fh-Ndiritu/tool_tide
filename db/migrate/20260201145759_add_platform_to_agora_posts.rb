class AddPlatformToAgoraPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_posts, :platform, :string
  end
end
