# frozen_string_literal: true

class AddLocalizedPromptToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :localized_prompt, :text
  end
end
