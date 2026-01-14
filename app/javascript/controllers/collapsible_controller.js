import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "icon"]
  static classes = ["hidden", "rotate"]

  toggle(event) {
    if (event) event.preventDefault()

    this.panelTarget.classList.toggle(this.hiddenClass)

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180")
    }
  }
}
