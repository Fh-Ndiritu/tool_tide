import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.clickOutside = this.clickOutside.bind(this)
    window.addEventListener("click", this.clickOutside)
  }

  disconnect() {
    window.removeEventListener("click", this.clickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (event) event.stopPropagation()
    this.menuTarget.classList.add("hidden")
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}
