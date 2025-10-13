class GenerationTagging < ApplicationRecord
  belongs_to :tag
  belongs_to :generation, polymorphic: true
end
