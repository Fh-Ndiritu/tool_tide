import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static classes = ["hidden", "rotate"]

  connect() {
    // Optional: set initial state based on data attribute?
  }

  toggle(event) {
    if (event) event.preventDefault()
    event.stopPropagation() // Prevent clicking the row

    this.contentTargets.forEach(t => t.classList.toggle(this.hiddenClass))

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle(this.rotateClass)
    }
  }
}
