class CreateAgoraTables < ActiveRecord::Migration[8.0]
  def change
    create_table :agora_trends do |t|
      t.string :period, null: false
      t.json :content, default: {}
      t.json :source_metadata, default: {}
      t.timestamps
    end
    add_index :agora_trends, :period

    create_table :agora_posts do |t|
      t.string :author_agent_id, null: false
      t.string :title, null: false
      t.text :body
      t.integer :revision_number, default: 1
      t.string :status, default: 'draft'
      t.timestamps
    end
    add_index :agora_posts, :author_agent_id
    add_index :agora_posts, :status

    create_table :agora_comments do |t|
      t.references :post, null: false, foreign_key: { to_table: :agora_posts }
      t.string :author_agent_id, null: false
      t.text :body
      t.string :comment_type, default: 'general'
      t.timestamps
    end
    add_index :agora_comments, :author_agent_id

    create_table :agora_votes do |t|
      t.references :votable, polymorphic: true, null: false
      t.string :voter_id, null: false
      t.integer :weight, default: 1
      t.integer :direction, default: 0
      t.timestamps
    end
    add_index :agora_votes, [ :votable_type, :votable_id, :voter_id ], unique: true, name: 'index_agora_votes_uniqueness'

    create_table :agora_brand_contexts do |t|
      t.string :key, null: false
      t.text :raw_content
      t.datetime :last_crawled_at
      t.timestamps
    end
    add_index :agora_brand_contexts, :key, unique: true
  end
end
