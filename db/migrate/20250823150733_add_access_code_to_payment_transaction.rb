# frozen_string_literal: true

class AddAccessCodeToPaymentTransaction < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :access_code, :string
    add_column :payment_transactions, :authorization_url, :string
  end
end
