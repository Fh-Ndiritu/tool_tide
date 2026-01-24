import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    default: String
  }

  connect() {
    this.updateCost()
  }

  updateCost() {
    const selectedInput = this.inputTargets.find(input => input.checked)
    const selectedModel = selectedInput ? selectedInput.value : this.defaultValue

    // Dispatch event for variations controller to pick up
    // We dispatch with bubbles: true so parent controller catches it
    // Using a custom event name to be explicit
    this.dispatch("change", { detail: { model: selectedModel }, bubbles: true })
  }
}
