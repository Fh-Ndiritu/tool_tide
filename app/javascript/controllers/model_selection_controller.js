import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    defaultModel: String
  }

  connect() {
    console.log('====== MODEL SELECTION CONTROLLER CONNECTED ======')
    console.log('Default Model Value:', this.defaultModelValue)

    // Check if any radio is already checked (from server-side render)
    const alreadyChecked = this.element.querySelector('input[type="radio"]:checked')
    console.log('Already Checked Radio:', alreadyChecked)

    // Log all radios
    const allRadios = this.element.querySelectorAll('input[type="radio"]')
    console.log('All Radios:', allRadios)
    allRadios.forEach(r => console.log(`  - Value: ${r.value}, Checked: ${r.checked}, Disabled: ${r.disabled}`))

    // If no radio is checked, check the one matching the default value
    if (!alreadyChecked && this.hasDefaultModelValue) {
      console.log('No radio checked, setting default...')
      const defaultRadio = this.element.querySelector(`input[type="radio"][value="${this.defaultModelValue}"]`)
      console.log('Default Radio Found:', defaultRadio)
      if (defaultRadio) {
        defaultRadio.checked = true
        console.log('Set defaultRadio.checked = true')
      }
    }

    // Apply visual highlighting to the checked radio
    this.updateHighlight()
    this.updateCost()
  }

  updateHighlight() {
    // Find all radio inputs and their visual divs
    const radios = this.element.querySelectorAll('input[type="radio"]')

    radios.forEach(radio => {
      const visualDiv = radio.nextElementSibling // The div sibling
      if (visualDiv) {
        if (radio.checked) {
          // Add highlight classes
          visualDiv.classList.add('bg-gray-600', 'text-white', 'shadow-sm')
          visualDiv.classList.remove('text-gray-400')
        } else {
          // Remove highlight classes
          visualDiv.classList.remove('bg-gray-600', 'text-white', 'shadow-sm')
          visualDiv.classList.add('text-gray-400')
        }
      }
    })
  }

  updateCost() {
    // Update visual highlighting first
    this.updateHighlight()

    const selectedInput = this.inputTargets.find(input => input.checked)
    const selectedModel = selectedInput ? selectedInput.value : this.defaultModelValue

    // Dispatch event for variations controller to pick up
    this.dispatch("change", { detail: { model: selectedModel, mode: selectedModel }, bubbles: true })
  }
}
