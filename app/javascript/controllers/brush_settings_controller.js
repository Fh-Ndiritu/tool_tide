import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["range", "display", "track", "fill", "thumb"]
  static values = {
    size: { type: Number, default: 60 }
  }

  connect() {
    this.updateUI(this.sizeValue)
  }

  updateSize(event) {
    const size = parseInt(event.target.value, 10)
    this.sizeValue = size
    this.updateUI(size)
    this.notifyCanvas(size)
  }

  updateUI(size) {
    if (!this.hasRangeTarget) return

    const min = parseInt(this.rangeTarget.min, 10)
    const max = parseInt(this.rangeTarget.max, 10)

    // Ensure size is within bounds
    size = Math.max(min, Math.min(max, size))

    // Sync range input if it wasn't the trigger
    if (this.rangeTarget.value != size) {
        this.rangeTarget.value = size
    }

    const fillPercentage = (size - min) / (max - min)

    const fillWidth = `${fillPercentage * 100}%`
    const trackLeft = `${fillPercentage * 100}%`
    const trackWidth = `${(1 - fillPercentage) * 100}%`

    // Thumb positioning logic
    const baseThumbSize = 20
    const maxThumbSize = 40
    const thumbSize = baseThumbSize + (fillPercentage * (maxThumbSize - baseThumbSize))
    const thumbLeft = `${fillPercentage * 100}%`

    if (this.hasFillTarget) this.fillTarget.style.width = fillWidth
    if (this.hasTrackTarget) {
      this.trackTarget.style.left = trackLeft
      this.trackTarget.style.width = trackWidth
    }
    if (this.hasThumbTarget) {
      this.thumbTarget.style.left = thumbLeft
      this.thumbTarget.style.setProperty('--thumb-size', `${thumbSize}px`)
    }
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = `${size}PX`
    }
  }

  notifyCanvas(size) {
    // Notify the parent project-canvas controller
    // We assume the canvas controller is on a parent element or we dispatch an event
    const event = new CustomEvent("brush-settings:change", {
        bubbles: true,
        detail: { size: size }
    })
    this.element.dispatchEvent(event)

    // Also try to find the controller directly if easier
    const canvasElement = document.querySelector('[data-controller="project-canvas"]')
    if (canvasElement) {
        const controller = this.application.getControllerForElementAndIdentifier(canvasElement, "project-canvas")
        if (controller) {
            controller.brushSizeValue = size
            if (controller.brushSizeValueChanged) controller.brushSizeValueChanged()
        }
    }
  }
}
