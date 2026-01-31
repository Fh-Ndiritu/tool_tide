# frozen_string_literal: true

module AgoraTable
  extend ActiveSupport::Concern

  included do
    self.table_name_prefix = "agora_"
  end
end
