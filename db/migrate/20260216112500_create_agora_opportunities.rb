class CreateAgoraOpportunities < ActiveRecord::Migration[8.0]
  def change
    create_table :agora_opportunities do |t|
      t.string :url, null: false
      t.string :platform
      t.string :title
      t.text :content_snippet
      t.datetime :posted_at
      t.integer :engagement_score, default: 0
      t.string :status, default: "pending"

      t.timestamps
    end
    add_index :agora_opportunities, :url, unique: true

    create_table :agora_draft_responses do |t|
      t.references :agora_opportunity, null: false, foreign_key: true
      t.text :content
      t.string :response_type
      t.text :rationale

      t.timestamps
    end
  end
end
