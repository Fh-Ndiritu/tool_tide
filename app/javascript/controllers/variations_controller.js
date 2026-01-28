import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "input", "cost"]
  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: 4 },
    proCost: { type: Number, default: 8 },
    standardCost: { type: Number, default: 4 }
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
      const perImageCost = this.resolvePerImageCost()
      const totalCost = count * perImageCost
      this.costTarget.textContent = `${totalCost} credits`
    }
  }

  resolvePerImageCost() {
    // Look for checked radio button within this controller's element
    const checkedModel = this.element.querySelector('input[type="radio"]:checked')

    // Check value against known aliases (matching what is in constants.rb/views)
    if (checkedModel && checkedModel.value === "standard_mode") {
      return this.standardCostValue
    }

    // Default to Pro cost (pro_mode or fallback)
    return this.proCostValue
  }
}
