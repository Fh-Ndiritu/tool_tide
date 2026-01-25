import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="flash"
export default class extends Controller {
  static targets = ["message"]

  // Track which elements we've already processed
  processedElements = new WeakSet()

  connect() {
    // Handle any messages that exist when controller connects
    this.messageTargets.forEach(element => {
      this.initializeMessage(element)
    })
  }

  // Called automatically when a new message target is added dynamically
  messageTargetConnected(element) {
    this.initializeMessage(element)
  }

  initializeMessage(element) {
    // Prevent double-processing
    if (this.processedElements.has(element)) return
    this.processedElements.add(element)

    // Schedule auto-dismiss after 4 seconds
    setTimeout(() => {
      this.removeMessage(element)
    }, 4000)
  }

  // Action called by the close button
  dismiss(event) {
    event.preventDefault()
    event.stopPropagation()

    const message = event.currentTarget.closest('[data-flash-target="message"]')
    if (message) {
      this.removeMessage(message)
    }
  }

  removeMessage(element) {
    if (!element || !element.parentNode) return

    // Add fade-out animation class
    element.classList.add('fade-out')

    // Remove after animation completes
    setTimeout(() => {
      if (element.parentNode) {
        element.remove()
      }
      this.checkEmpty()
    }, 500)
  }

  checkEmpty() {
    // Hide container if no messages left
    if (this.messageTargets.length === 0) {
      this.element.style.display = 'none'
    }
  }
}
