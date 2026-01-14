import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["inputs", "tools"]

  onInputsClicked(event) {
    const panel = this.inputsTarget.querySelector('[data-collapsible-target="panel"]')

    // If it's already open, prevent closing (strict radio behavior)
    if (panel && !panel.classList.contains("hidden")) {
      event.preventDefault()
      event.stopImmediatePropagation()
    } else {
      // If closing (opening inputs), collapse tools
      this.collapse(this.toolsTarget)
    }
  }

  onToolsClicked(event) {
    const panel = this.toolsTarget.querySelector('[data-collapsible-target="panel"]')

    // If it's already open, prevent closing
    if (panel && !panel.classList.contains("hidden")) {
      event.preventDefault()
      event.stopImmediatePropagation()
    } else {
      // If opening tools, collapse inputs
      this.collapse(this.inputsTarget)
    }
  }

  collapse(wrapper) {
    const panel = wrapper.querySelector('[data-collapsible-target="panel"]')

    // If it's visible (not hidden), click the toggle to close it
    if (panel && !panel.classList.contains("hidden")) {
      const toggleBtn = wrapper.querySelector('[data-action*="collapsible#toggle"]')
      if (toggleBtn) {
        toggleBtn.click()
      }
    }
  }
}
