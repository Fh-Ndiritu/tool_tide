module Agora
  class BrandContext < ApplicationRecord
    include AgoraTable
    validates :key, presence: true, uniqueness: true
  end
end
