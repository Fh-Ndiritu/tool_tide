import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="paypal"
export default class extends Controller {
  static values = {
    clientId: String
  }

  connect() {
    if (window.paypal) {
      this.renderButtons()
    } else {
      this.loadScript()
    }
  }

  loadScript() {
    const script = document.createElement("script")
    script.src = `https://www.paypal.com/sdk/js?client-id=${this.clientIdValue}&currency=USD&components=buttons&enable-funding=venmo,paylater,card`
    script.async = true
    script.onload = () => this.renderButtons()
    document.head.appendChild(script)
  }

  renderButtons() {
    window.paypal.Buttons({
      style: {
        layout: 'vertical',
        color: 'gold',
        shape: 'rect',
        height: 45,
        tagline: false
      },
      createOrder: (data, actions) => {
        return fetch("/payment_transactions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
          }
        })
        .then(response => {
          if (!response.ok) {
            return response.json().then(err => { throw err; });
          }
          return response.json();
        })
        .then(order => {
          console.log("PayPal Order:", order);
          if (!order.id) {
            throw new Error("Order ID missing from response");
          }
          return order.id;
        })
        .catch(error => {
          console.error("Error creating order:", error);
          alert("Failed to initiate payment. Please try again.");
        });
      },
      onApprove: async (data, actions) => {
        try {
          const response = await fetch("/payment_transactions/capture", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
            },
            body: JSON.stringify({
              order_id: data.orderID
            })
          });

          const orderData = await response.json();
          console.log("Payment Details:", orderData);

          // Three cases to handle:
          //   (1) Recoverable INSTRUMENT_DECLINED -> call actions.restart()
          //   (2) Other non-recoverable errors -> Show a failure message
          //   (3) Successful transaction -> Show confirmation or thank you message

          const errorDetail = orderData?.details?.[0];

          if (errorDetail?.issue === "INSTRUMENT_DECLINED") {
            // (1) Recoverable INSTRUMENT_DECLINED -> call actions.restart()
            // recoverable state, per https://developer.paypal.com/docs/checkout/standard/customize/handle-funding-failures/
            return actions.restart();
          } else if (errorDetail) {
            // (2) Other non-recoverable errors -> Show a failure message
            throw new Error(`${errorDetail.description} (${orderData.debug_id})`);
          } else if (!orderData.purchase_units) {
            throw new Error(JSON.stringify(orderData));
          } else {
            // (3) Successful transaction -> Show confirmation or redirect
            const transaction =
              orderData?.purchase_units?.[0]?.payments?.captures?.[0] ||
              orderData?.purchase_units?.[0]?.payments?.authorizations?.[0];

            console.log("Capture result", orderData, JSON.stringify(orderData, null, 2));

            // Redirect to credits page on success
            window.location.href = "/credits";
          }
        } catch (error) {
          console.error(error);
          alert(`Sorry, your transaction could not be processed.\n\n${error.message}`);
        }
      }
    }).render(this.element)
  }
}
