class AddTrialGenerationToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :trial_generation, :boolean, default: false
  end
end
