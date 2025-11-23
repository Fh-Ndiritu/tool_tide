# frozen_string_literal: true

module Paypal
  include PaypalServerSdk
  class CreateOrder
    include Dry::Monads[:result]

    def initialize(transaction)
      @transaction = transaction
    end

    def self.perform(transaction)
      new(transaction).perform
    end


    def perform
      collect = {
        "body" => OrderRequest.new(
        intent: CheckoutPaymentIntent::CAPTURE,
        purchase_units: [
          PurchaseUnitRequest.new(
            amount: AmountWithBreakdown.new(
                currency_code: "USD",
                value: sprintf("%.2f", @transaction.amount)
              ),
              reference_id: @transaction.uuid,
              description: "Hadaa Credits",
              custom_id: @transaction.id,
            )
          ]
        ),
        "prefer" => "return=representation"
      }
      response = PaypalClient.orders.create_order(collect)

      if response.data.status == "CREATED"
        Success(response.data)
      else
        Failure("Failed to create PayPal order: #{response.data.status}")
      end
    rescue StandardError => e
      Failure("PayPal CreateOrder failed: #{e.message}")
    end
  end
end


# collect = {
#   'body' => OrderRequest.new(
#     intent: CheckoutPaymentIntent::CAPTURE,
#     purchase_units: [
#       PurchaseUnitRequest.new(
#         amount: AmountWithBreakdown.new(
#           currency_code: 'USD',
#           value: '230.00',
#           breakdown: AmountBreakdown.new(
#             item_total: Money.new(
#               currency_code: 'USD',
#               value: '220.00'
#             ),
#             shipping: Money.new(
#               currency_code: 'USD',
#               value: '10.00'
#             )
#           )
#         ),
#         invoice_id: '90210',
#         items: [
#           Item.new(
#             name: 'T-Shirt',
#             unit_amount: Money.new(
#               currency_code: 'USD',
#               value: '20.00'
#             ),
#             quantity: '1',
#             description: 'Super Fresh Shirt',
#             sku: 'sku01',
#             url: 'https://example.com/url-to-the-item-being-purchased-1',
#             category: ItemCategory::PHYSICAL_GOODS,
#             image_url: 'https://example.com/static/images/items/1/tshirt_green.jpg',
#             upc: UniversalProductCode.new(
#               type: UpcType::UPC_A,
#               code: '123456789012'
#             )
#           ),
#           Item.new(
#             name: 'Shoes',
#             unit_amount: Money.new(
#               currency_code: 'USD',
#               value: '100.00'
#             ),
#             quantity: '2',
#             description: 'Running, Size 10.5',
#             sku: 'sku02',
#             url: 'https://example.com/url-to-the-item-being-purchased-2',
#             category: ItemCategory::PHYSICAL_GOODS,
#             image_url: 'https://example.com/static/images/items/1/shoes_running.jpg',
#             upc: UniversalProductCode.new(
#               type: UpcType::UPC_A,
#               code: '987654321012'
#             )
#           )
#         ]
#       )
#     ],
#     payment_source: PaymentSource.new(
#       paypal: PaypalWallet.new(
#         experience_context: PaypalWalletExperienceContext.new(
#           shipping_preference: 'GET_FROM_FILE',
#           return_url: 'https://example.com/returnUrl',
#           cancel_url: 'https://example.com/cancelUrl',
#           landing_page: PaypalExperienceLandingPage::LOGIN,
#           user_action: PaypalExperienceUserAction::PAY_NOW,
#           payment_method_preference: PayeePaymentMethodPreference::IMMEDIATE_PAYMENT_REQUIRED
#         )
#       )
#     )
#   )
# }
