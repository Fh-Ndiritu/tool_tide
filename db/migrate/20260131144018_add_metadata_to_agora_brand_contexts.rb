class AddMetadataToAgoraBrandContexts < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_brand_contexts, :metadata, :json
  end
end
