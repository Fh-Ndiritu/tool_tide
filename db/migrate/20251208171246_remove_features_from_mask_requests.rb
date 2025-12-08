class RemoveFeaturesFromMaskRequests < ActiveRecord::Migration[8.0]
  def change
    remove_column :mask_requests, :features, :text
    remove_column :mask_requests, :feature_prompt, :text
  end
end
