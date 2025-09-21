import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="loader"
export default class extends Controller {
  static targets = ['loader'];
  showLoader() {
    this.loaderTarget.classList.toggle('hidden');
  }
}
