import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "tools", "toggleText"]
  static classes = ["expanded"]

  connect() {
    this.expanded = false
  }

  toggle(event) {
    if (event) event.preventDefault()

    this.expanded = !this.expanded
    this.updateUI()
  }

  collapsePresets(event) {
    if (this.expanded) {
      this.expanded = false
      this.updateUI()
    }
  }

  updateUI() {
    // Toggle list height
    if (this.expanded) {
        this.listTarget.classList.remove("max-h-60")
        this.listTarget.classList.add("max-h-[80vh]") // Expanded height

        // Collapse tools if they exist
        if (this.hasToolsTarget) {
            // Find the collapsible controller instance if possible, or just click the toggle button
            // Assuming the tools target is the container of the collapsible controller
            const collapsibleBtn = this.toolsTarget.querySelector('[data-action*="collapsible#toggle"]')
            const panel = this.toolsTarget.querySelector('[data-collapsible-target="panel"]')

            // If panel is open (not hidden), close it
            if (panel && !panel.classList.contains("hidden")) {
                if (collapsibleBtn) collapsibleBtn.click()
            }
        }

        if (this.hasToggleTextTarget) {
            this.toggleTextTarget.textContent = "Show Less"
        }
    } else {
        this.listTarget.classList.add("max-h-60")
        this.listTarget.classList.remove("max-h-[80vh]")

        if (this.hasToggleTextTarget) {
            this.toggleTextTarget.textContent = "Show All"
        }
    }
  }
}
