class SearchTerm < ApplicationRecord
  belongs_to :user, optional: true
end
