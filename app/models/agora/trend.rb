module Agora
  class Trend < ApplicationRecord
    include AgoraTable
    validates :period, presence: true
  end
end
