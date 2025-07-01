import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="navbar"
export default class extends Controller {
  static targets = ['navigationLinks'];
  toggleMenu() {
    this.navigationLinksTarget.classList.toggle('hidden');
  }
}
