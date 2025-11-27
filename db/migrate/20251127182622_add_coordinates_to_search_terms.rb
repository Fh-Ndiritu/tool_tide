class AddCoordinatesToSearchTerms < ActiveRecord::Migration[8.0]
  def change
    add_column :search_terms, :latitude, :float
    add_column :search_terms, :longitude, :float
  end
end
