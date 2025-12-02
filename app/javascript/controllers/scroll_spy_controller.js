import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "step"]
  static classes = ["active"]

  connect() {
    this.observer = new IntersectionObserver(this.handleIntersection.bind(this), {
      root: null,
      rootMargin: "-40% 0px -40% 0px", // Trigger when element is in the middle 20% of viewport
      threshold: 0
    })

    this.stepTargets.forEach(step => {
      this.observer.observe(step)
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const stepIndex = entry.target.dataset.stepIndex
        this.updateImage(stepIndex)
        this.highlightStep(entry.target)
      }
    })
  }

  updateImage(index) {
    const imageUrl = this.stepTargets.find(step => step.dataset.stepIndex === index).dataset.imageUrl

    // Simple fade transition
    this.imageTarget.style.opacity = 0

    setTimeout(() => {
      this.imageTarget.src = imageUrl
      this.imageTarget.style.opacity = 1
    }, 200) // Match transition duration
  }

  highlightStep(activeStep) {
    this.stepTargets.forEach(step => {
      if (step === activeStep) {
        step.classList.add(...this.activeClasses)
        step.classList.remove("opacity-40", "scale-95")
      } else {
        step.classList.remove(...this.activeClasses)
        step.classList.add("opacity-40", "scale-95")
      }
    })
  }
}
