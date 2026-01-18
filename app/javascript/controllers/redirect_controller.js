import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    seconds: { type: Number, default: 10 }
  }

  static targets = ["counter", "countdownRing"]

  connect() {
    if (this.isVisible()) {
      this.startCountdown()
    }

    // Optional: Re-check on resize if we want to auto-trigger if user resizes to mobile
    this.resizeObserver = new ResizeObserver(() => {
     if (this.isVisible() && !this.timer) {
       this.startCountdown()
     }
    })
    this.resizeObserver.observe(document.body)
  }

  disconnect() {
    this.stopCountdown()
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }

  isVisible() {
    // Check if the element is actually visible (display != none)
    // The css handles the media query visibility, so we just check offsetParent or similar
    return window.getComputedStyle(this.element).display !== "none"
  }

  startCountdown() {
    if (this.timer) return;

    this.remaining = this.secondsValue
    this.updateDisplay()

    // Start with a small visual delay so the user sees "10"
    this.timer = setInterval(() => {
      this.remaining--
      this.updateDisplay()

      if (this.remaining <= 0) {
        this.redirect()
      }
    }, 1000)
  }

  stopCountdown() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  updateDisplay() {
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.remaining
    }

    // Update SVG ring if present
    if (this.hasCountdownRingTarget) {
        const radius = this.countdownRingTarget.r.baseVal.value;
        const circumference = radius * 2 * Math.PI;
        const offset = circumference - (this.remaining / this.secondsValue) * circumference;
        this.countdownRingTarget.style.strokeDashoffset = offset;
    }
  }

  redirect() {
    this.stopCountdown()
    window.location.href = this.urlValue
  }

  redirectNow(event) {
      if (event) event.preventDefault()
      this.redirect()
  }
}
