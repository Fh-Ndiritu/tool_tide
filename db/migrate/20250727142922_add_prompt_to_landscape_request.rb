# frozen_string_literal: true

class AddPromptToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :prompt, :text
  end
end
