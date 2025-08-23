class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :landscapes, dependent: :destroy
  has_many :landscape_requests, through: :landscapes
  has_many :payment_transactions, dependent: :nullify


  def state_address
    return '' unless address.present?

    "#{address['state']}, #{address['country']}"
  end
end
