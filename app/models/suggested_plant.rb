# frozen_string_literal: true

class SuggestedPlant < ApplicationRecord
  belongs_to :landscape_request
end
