import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="revision-slider"
export default class extends Controller {
  static targets = ["slider", "currentLabel", "info"]

  connect() {
    this.showRevisionInfo(this.sliderTarget.value)
  }

  slide(event) {
    const revisionNumber = event.target.value
    this.currentLabelTarget.textContent = `Rev ${revisionNumber}`
    this.showRevisionInfo(revisionNumber)
  }

  showRevisionInfo(revisionNumber) {
    // Hide all revision info divs
    this.infoTarget.querySelectorAll("[data-revision]").forEach(el => {
      el.classList.add("hidden")
    })

    // Show the selected revision info
    const selected = this.infoTarget.querySelector(`[data-revision="${revisionNumber}"]`)
    if (selected) {
      selected.classList.remove("hidden")
    }
  }
}
