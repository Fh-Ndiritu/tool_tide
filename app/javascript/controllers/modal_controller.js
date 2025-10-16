// app/javascript/controllers/modal_controller.js
import { Controller } from '@hotwired/stimulus';

export default class ModalController extends Controller {
  static targets = ['container'];

  connect() {
    this.show();
  }

  show() {
    this.element.classList.remove('hidden');
    document.body.classList.add('overflow-hidden');
  }

  hide() {
    this.element.classList.add('hidden');
    document.body.classList.remove('overflow-hidden');

    const frame = document.getElementById(this.element.getAttribute('data-modal-frame-id') || 'modal');
    if (frame) {
      frame.innerHTML = '';
    }
  }

  close(event) {
    if (event) event.preventDefault();
    this.hide();
  }

  closeWithKeyboard(event) {
    if (event.key === 'Escape') {
      this.hide();
    }
  }

  closeBackground(event) {
    if (event.target === this.element) {
      this.hide();
    }
  }

  disconnect() {
    document.body.classList.remove('overflow-hidden');
  }
}
