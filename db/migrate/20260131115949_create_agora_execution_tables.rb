class CreateAgoraExecutionTables < ActiveRecord::Migration[8.0]
  def change
    create_table :agora_executions do |t|
      t.references :post, null: false, foreign_key: { to_table: :agora_posts }
      t.string :platform
      t.json :metrics, default: {} # spend, impressions, ctr, cpc, roas
      t.text :admin_notes
      t.datetime :executed_at

      t.timestamps
    end

    create_table :agora_learned_patterns do |t|
      t.string :pattern_type # 'success', 'failure'
      t.string :context_tag # 'tiktok_hook', 'fb_copy', 'general'
      t.text :content # The learned insight
      t.float :confidence, default: 0.0
      t.references :source_execution, null: true, foreign_key: { to_table: :agora_executions }

      t.timestamps
    end

    add_index :agora_learned_patterns, [ :pattern_type, :confidence ]
  end
end
