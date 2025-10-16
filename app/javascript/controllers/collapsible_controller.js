// app/javascript/controllers/collapsible_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['content', 'text', 'icon'];

  connect() {
    this.isExpanded = false;
    this.updateToggleState();
  }

  toggle() {
    this.isExpanded = !this.isExpanded;
    this.updateToggleState();
  }

  updateToggleState() {
    const content = this.contentTarget;
    const icon = this.iconTarget;
    const text = this.textTarget;

    if (this.isExpanded) {
      // EXPAND
      content.style.maxHeight = content.scrollHeight + 'px';
      icon.classList.add('rotate-180');
      text.textContent = 'Hide Editing Guide';
    } else {
      // COLLAPSE
      content.style.maxHeight = '0';
      icon.classList.remove('rotate-180');
      text.textContent = 'View Editing Guide';
    }
  }
}
