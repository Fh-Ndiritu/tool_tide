import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="credits"
export default class extends Controller {
  connect() {}

  purchase() {
    console.log('They need me');
    Turbo.visit('/credits');
  }
}
