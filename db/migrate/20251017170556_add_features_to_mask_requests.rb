class AddFeaturesToMaskRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :features, :text
    add_column :mask_requests, :feature_prompt, :text
  end
end
