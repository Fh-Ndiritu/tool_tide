class AddContentToAgoraOpportunities < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_opportunities, :content, :text
  end
end
