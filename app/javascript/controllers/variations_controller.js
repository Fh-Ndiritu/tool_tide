import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "input", "cost"]
  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: 4 },
    imageCost: { type: Number, default: 2 } // Initial default, can be overridden
  }

  connect() {
    this.updateUI()
  }

  increment(event) {
    event.preventDefault()
    let current = parseInt(this.inputTarget.value) || 1
    if (current < this.maxValue) {
      this.inputTarget.value = current + 1
      this.updateUI()
    }
  }

  decrement(event) {
    event.preventDefault()
    let current = parseInt(this.inputTarget.value) || 1
    if (current > this.minValue) {
      this.inputTarget.value = current - 1
      this.updateUI()
    }
  }

  updateUI() {
    const count = parseInt(this.inputTarget.value) || 1
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    if (this.hasCostTarget) {
      const totalCost = count * this.imageCostValue
      this.costTarget.textContent = `${totalCost} credits`
    }
  }
}
