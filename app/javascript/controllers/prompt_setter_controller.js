import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['prompt', 'form', 'submit'];

  static values = { prompt: String };

  connect() {
    this.toggleSubmit()
  }

  input() {
    this.toggleSubmit()
  }

  toggleSubmit() {
    if (!this.hasSubmitTarget || !this.hasPromptTarget) return

    const hasText = this.promptTarget.value.trim().length > 0
    this.submitTarget.disabled = !hasText

    if (hasText) {
      this.submitTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      this.promptTarget.classList.remove('ring-pulse')
    } else {
      this.submitTarget.classList.add('opacity-50', 'cursor-not-allowed')
      this.promptTarget.classList.add('ring-pulse')
    }
  }

  set(event) {
    event.preventDefault();
    const promptText = event.currentTarget.dataset.promptSetterPromptValue;
    this.promptTarget.value = promptText;
    this.toggleSubmit()
  }

  setAndClickGenerate(event) {
    event.preventDefault();

    const promptText = event.currentTarget.dataset.promptSetterPromptValue;

    this.promptTarget.value = promptText;
    this.toggleSubmit()
    // Small delay to ensure UI updates before submit
    setTimeout(() => {
      this.submitTarget.click()
    }, 50)
  }
}
