import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "leftArrow", "rightArrow", "leftMask", "rightMask"]

  connect() {
    this.updateArrows()
    this.containerTarget.addEventListener("scroll", () => this.updateArrows())
    window.addEventListener("resize", () => this.updateArrows())

    // Smooth scroll to active if present
    const active = this.containerTarget.querySelector(".active-design-tab")
    if (active) {
      setTimeout(() => {
        active.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "center" })
      }, 100)
    }
  }

  disconnect() {
    window.removeEventListener("resize", () => this.updateArrows())
  }

  scrollLeft() {
    this.containerTarget.scrollBy({ left: -200, behavior: "smooth" })
  }

  scrollRight() {
    this.containerTarget.scrollBy({ left: 200, behavior: "smooth" })
  }

  updateArrows() {
    const { scrollLeft, scrollWidth, clientWidth } = this.containerTarget

    // Left side state
    const showLeft = scrollLeft > 10
    if (this.hasLeftArrowTarget) {
      this.leftArrowTarget.style.opacity = showLeft ? "1" : "0"
      this.leftArrowTarget.style.pointerEvents = showLeft ? "auto" : "none"
    }
    if (this.hasLeftMaskTarget) {
      this.leftMaskTarget.style.opacity = showLeft ? "1" : "0"
    }

    // Right side state
    const remaining = scrollWidth - clientWidth - scrollLeft
    const showRight = remaining > 10

    if (this.hasRightArrowTarget) {
      this.rightArrowTarget.style.opacity = showRight ? "1" : "0"
      this.rightArrowTarget.style.pointerEvents = showRight ? "auto" : "none"
    }
    if (this.hasRightMaskTarget) {
      this.rightMaskTarget.style.opacity = showRight ? "1" : "0"
    }
  }
}
