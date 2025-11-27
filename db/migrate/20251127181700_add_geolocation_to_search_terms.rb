class AddGeolocationToSearchTerms < ActiveRecord::Migration[8.0]
  def change
    add_column :search_terms, :ip_address, :string
    add_column :search_terms, :city, :string
    add_column :search_terms, :country, :string
  end
end
