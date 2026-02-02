import { Controller } from "@hotwired/stimulus"

// Disables a button for a specified duration after click to prevent rage clicking
export default class extends Controller {
  static values = { duration: { type: Number, default: 10000 } }

  connect() {
    // Find the submit button inside the form (button_to generates a form)
    this.button = this.element.querySelector('input[type="submit"], button[type="submit"]') || this.element
  }

  disable(event) {
    const button = this.button
    const originalText = button.value || button.textContent

    // Disable immediately
    button.disabled = true
    button.classList.add('opacity-50', 'cursor-not-allowed')

    // Countdown display
    let remaining = Math.floor(this.durationValue / 1000)
    const updateText = () => {
      if (button.tagName === 'INPUT') {
        button.value = `⏳ Wait ${remaining}s...`
      } else {
        button.textContent = `⏳ Wait ${remaining}s...`
      }
    }
    updateText()

    const interval = setInterval(() => {
      remaining--
      if (remaining > 0) {
        updateText()
      } else {
        clearInterval(interval)
        button.disabled = false
        button.classList.remove('opacity-50', 'cursor-not-allowed')
        if (button.tagName === 'INPUT') {
          button.value = originalText
        } else {
          button.textContent = originalText
        }
      }
    }, 1000)
  }
}
