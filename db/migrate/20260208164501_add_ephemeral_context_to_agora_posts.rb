class AddEphemeralContextToAgoraPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_posts, :persona_context, :json, default: {}
    add_column :agora_posts, :content_archetype, :string
  end
end
