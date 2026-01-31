class AddNetScoreToAgoraTables < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_posts, :net_score, :integer, default: 0
    add_column :agora_comments, :net_score, :integer, default: 0
  end
end
