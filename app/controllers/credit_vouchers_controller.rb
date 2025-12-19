class CreditVouchersController < ApplicationController
  before_action :authenticate_user!

  def redeem
    voucher = CreditVoucher.find_by(token: params[:token])

    if voucher.nil?
      redirect_to root_path, alert: "Invalid voucher code."
      return
    end

    if voucher.user_id != current_user.id
      redirect_to root_path, alert: "This voucher belongs to another account."
      return
    end

    if voucher.redeem!
      flash[:voucher_redeemed] = true
      flash[:voucher_amount] = voucher.amount
      redirect_to root_path
    else
      redirect_to root_path, alert: "This voucher has already been redeemed."
    end
  end
end
