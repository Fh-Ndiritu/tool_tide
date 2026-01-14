import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["children", "chevron"]
  static classes = ["hidden", "rotate"]
  static values = { childrenId: String }

  connect() {
    // Synchronize initial state
    this.updateState()
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    const target = this.resolveTarget()
    if (target) {
      target.classList.toggle(this.hiddenClass)
      this.updateState()
    } else {
      console.warn("LayerTreeController: No children target or ID found")
    }
  }

  updateState() {
    const target = this.resolveTarget()
    if (target && this.hasChevronTarget) {
      const isHidden = target.classList.contains(this.hiddenClass)
      // If hidden, no rotation (chevron points right)
      // If visible, rotate 90 (chevron points down)
      this.chevronTarget.classList.toggle(this.rotateClass, !isHidden)
    }
  }

  resolveTarget() {
    if (this.hasChildrenTarget) {
      return this.childrenTarget
    }
    if (this.childrenIdValue) {
      return document.getElementById(this.childrenIdValue)
    }
    return null
  }
}
