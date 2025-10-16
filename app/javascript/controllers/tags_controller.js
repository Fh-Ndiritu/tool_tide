// app/javascript/controllers/tag_form_controller.js

import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="tag-form"
export default class extends Controller {
  static targets = ['tagClass', 'titleGroup', 'titleInput'];
  static values = { tagClassOutlet: String };

  connect() {
    this.updateTagType();
  }

  updateTagType() {
    const selectedClass = this.tagClassTarget.value;

    if (selectedClass) {
      // 1. Show the title group
      this.titleGroupTarget.classList.remove('hidden');

      // 2. Set a dynamic placeholder based on the tag class
      let placeholderText = `Enter the ${selectedClass.toLowerCase()}`;

      switch (selectedClass) {
        case 'event':
          placeholderText = 'e.g., Christmas, Halloween, World Cup';
          break;
        case 'season':
          placeholderText = 'e.g., Summer 2024, Winter, Spring';
          break;
        case 'location':
          placeholderText = 'e.g., Central Park, Kyoto, My Office';
          break;
      }
      this.titleInputTarget.placeholder = placeholderText;
    } else {
      // Hide the title group if no tag class is selected
      this.titleGroupTarget.classList.add('hidden');
    }
  }
}
