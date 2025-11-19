// app/javascript/controllers/tabs_controller.js

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  // Add the adminFeatureButton target for conditional display in the header
  static targets = ['tab', 'panel', 'adminFeatureButton'];

  connect() {
    this.showInitialTab();
  }

  showInitialTab() {
    // Show the first tab (index 0) on connect
    this.tabTargets.forEach((tab, index) => {
      // Find the issue button which is the default
      const issueButton = this.element.querySelector('a[href="/issues/new"]');

      if (index === 0) {
        this.updateStyles(tab, this.panelTargets[index], true);

        // Ensure issue button is visible and admin button is hidden on initial load
        if (issueButton) issueButton.classList.remove('hidden');
        if (this.hasAdminFeatureButtonTarget) this.adminFeatureButtonTarget.classList.add('hidden');
      } else {
        this.updateStyles(tab, this.panelTargets[index], false);
      }
    });
  }

  // Action triggered when a tab button is clicked
  changeTab(event) {
    event.preventDefault();

    const selectedTab = event.currentTarget;
    const selectedIndex = this.tabTargets.indexOf(selectedTab);

    // Find the issue button (default action)
    const issueButton = this.element.querySelector('a[href="/issues/new"]');

    this.tabTargets.forEach((tab, index) => {
      const isSelected = index === selectedIndex;
      this.updateStyles(tab, this.panelTargets[index], isSelected);
    });

    // Handle the Action Button swap
    const isFeaturesTab = selectedIndex === 1;

    if (issueButton) {
      issueButton.classList.toggle('hidden', isFeaturesTab);
    }

    if (this.hasAdminFeatureButtonTarget) {
      this.adminFeatureButtonTarget.classList.toggle('hidden', !isFeaturesTab);
    }
  }

  // Consolidated method to apply active/inactive styles and visibility
  updateStyles(tab, panel, isActive) {
    if (isActive) {
      // Set Active Styles using concise Tailwind names
      tab.classList.remove('text-neutral-500', 'border-neutral-300');
      tab.classList.add('text-primary', 'border-primary');

      // Show the content panel
      panel.classList.remove('hidden');
    } else {
      // Set Inactive Styles using concise Tailwind names
      tab.classList.remove('text-primary', 'border-primary');
      tab.classList.add('text-neutral-500', 'border-neutral-300');

      // Hide the content panel
      panel.classList.add('hidden');
    }
  }
}
