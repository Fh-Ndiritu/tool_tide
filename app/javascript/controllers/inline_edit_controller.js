import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "form", "input"]

  connect() {
    // console.log("Inline edit controller connected")
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.viewTarget.classList.toggle("hidden")
    this.formTarget.classList.toggle("hidden")

    if (!this.formTarget.classList.contains("hidden")) {
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  submitOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.formTarget.requestSubmit()
    } else if (event.key === "Escape") {
       this.toggle()
    }
  }
}
