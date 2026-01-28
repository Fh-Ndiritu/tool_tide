import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progressBar", "stepDisplay"]

  connect() {
    if (this.hasStepTarget) {
      this.showStep(this.currentStep)
    }
  }

  disconnect() {
    if (this.advanceTimeout) clearTimeout(this.advanceTimeout)
  }

  showStep(index) {
    this.stepTargets.forEach((el, i) => {
      el.classList.toggle("hidden", i !== index)
    })
    this.updateProgress(index)
  }

  get currentStep() {
    if (!this.roleSelected) return 0
    if (!this.intentSelected) return 1
    return 2
  }

  get roleSelected() {
    return this.element.querySelector('input[name="onboarding_response[role]"]:checked') !== null
  }

  get intentSelected() {
    return this.element.querySelector('input[name="onboarding_response[intent]"]:checked') !== null
  }

  select(event) {
    const card = event.currentTarget
    const input = card.querySelector('input[type="radio"]')
    input.checked = true

    // Highlight selected card
    const stepContainer = card.closest('[data-step]')
    stepContainer.querySelectorAll('.selectable-card').forEach(c => c.classList.remove('selected'))
    card.classList.add('selected')

    // Auto-advance
    if (this.advanceTimeout) clearTimeout(this.advanceTimeout)
    this.advanceTimeout = setTimeout(() => {
      this.nextStep()
    }, 400)
  }

  nextStep() {
    const steps = this.stepTargets
    const currentIdx = steps.findIndex(s => !s.classList.contains('hidden'))

    if (currentIdx === -1) return

    if (currentIdx < steps.length - 1) {
      steps[currentIdx].classList.add('hidden')
      steps[currentIdx + 1].classList.remove('hidden')
      this.updateProgress(currentIdx + 1)
    } else {
      // Last step, update progress to 100% and submit form
      this.updateProgress(steps.length)
      const form = this.element.querySelector('form') || this.element

      setTimeout(() => {
        if (form.requestSubmit) {
          form.requestSubmit()
        } else {
          form.submit()
        }
      }, 300)
    }
  }

  updateProgress(stepIdx) {
    // stepIdx is 0-based.
    // If stepIdx = 0 (Step 1), we want 33% (1/3).
    // If stepIdx = 2 (Step 3), we want 100% (3/3).
    // When finishing, stepIdx passed is length (3), so 4/3 -> cap at 100%.
    const currentStep = stepIdx + 1
    const totalSteps = this.stepTargets.length
    const progress = Math.min((currentStep / totalSteps) * 100, 100)

    this.progressBarTarget.style.width = `${progress}%`

    // Update all step displays (mobile & desktop)
    const displayStep = Math.min(stepIdx + 1, this.stepTargets.length)
    this.stepDisplayTargets.forEach(el => {
      el.textContent = displayStep
    })
  }


}
