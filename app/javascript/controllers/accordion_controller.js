// app/javascript/controllers/accordion_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['content', 'icon'];

  connect() {
    this.isOpen = true; // Initial state for each accordion item
  }

  toggle() {
    this.isOpen = !this.isOpen;
    this.contentTarget.classList.toggle('hidden', !this.isOpen);
    this.iconTarget.classList.toggle('rotate-180', this.isOpen); // Rotates the arrow
  }
}
