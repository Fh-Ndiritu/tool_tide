import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['checkmark'];

  toggle(event) {
    if (event.currentTarget.checked) {
      this.checkmarkTarget.classList.remove('hidden');
    } else {
      this.checkmarkTarget.classList.add('hidden');
    }
  }
}
