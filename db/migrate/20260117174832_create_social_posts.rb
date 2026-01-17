class CreateSocialPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :social_posts do |t|
      t.text :content
      t.text :prompt
      t.integer :status, default: 0
      t.string :platform, default: 'facebook'
      t.datetime :published_at
      t.decimal :performance_score
      t.json :performance_metrics
      t.json :tags, default: []

      t.timestamps
    end
  end
end
