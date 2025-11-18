// app/javascript/controllers/tabs_controller.js

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  // Define targets for the tab buttons and content panels
  static targets = ['tab', 'panel'];

  connect() {
    this.showInitialTab();
  }

  showInitialTab() {
    // Determine which tab to show initially (e.g., the first one, or based on URL)
    this.panelTargets.forEach((panel, index) => {
      // Show the first panel by default
      if (index === 0) {
        this.setActive(this.tabTargets[index], panel);
      } else {
        this.setInactive(this.tabTargets[index], panel);
      }
    });
  }

  // Action triggered when a tab button is clicked
  changeTab(event) {
    event.preventDefault();

    // Get the index of the clicked tab
    const selectedTab = event.currentTarget;
    const index = this.tabTargets.indexOf(selectedTab);

    this.panelTargets.forEach((panel, i) => {
      if (i === index) {
        this.setActive(this.tabTargets[i], panel);
      } else {
        this.setInactive(this.tabTargets[i], panel);
      }
    });
  }

  setActive(tab, panel) {
    // Style the active tab button
    tab.classList.remove(
      'text-[--color-text-dark]',
      'hover:text-[--color-text-primary]',
      'border-[--color-neutral-300]'
    );
    tab.classList.add('text-[--color-text-primary]', 'border-[--color-primary]');

    // Show the content panel
    panel.classList.remove('hidden');
  }

  setInactive(tab, panel) {
    // Style the inactive tab button
    tab.classList.remove('text-[--color-text-primary]', 'border-[--color-primary]');
    tab.classList.add('text-[--color-text-dark]', 'hover:text-[--color-text-primary]', 'border-[--color-neutral-300]');

    // Hide the content panel
    panel.classList.add('hidden');
  }
}
