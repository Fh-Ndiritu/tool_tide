import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['prompt', 'form', 'submit'];

  static values = { prompt: String };

  setAndClickGenerate(event) {
    event.preventDefault();

    const promptText = event.currentTarget.dataset.promptSetterPromptValue;

    this.promptTarget.value = promptText;
  }
}
