import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Scroll into view when the element is connected (added to DOM)
    this.element.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }
}
