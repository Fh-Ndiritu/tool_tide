import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "canvasWrapper", "sidebarLayers", "toolsPanel", "promptInput",
    "variationSlider", "variationCount", "emptyState", "resultList",
    "presetMenu", "presetInput", "presetLabel", "costDisplay"
  ];

  static values = {
    projectId: Number,
    activeLayerId: Number,
    creditCost: { type: Number, default: 8 }
  };

  connect() {
    console.log("Unified Dashboard Connected");
    this.updateUIState();
    this.updateCost();
    
    // Close dropdown when clicking outside
    document.addEventListener("click", this.closeDropdownOutside.bind(this));
  }

  disconnect() {
    document.removeEventListener("click", this.closeDropdownOutside.bind(this));
  }

  updateUIState() {
    // Check if we have layers, if not show empty state
    const layers = this.sidebarLayersTarget.children;
    if (layers.length === 0) {
      if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.remove("hidden");
      if (this.hasCanvasWrapperTarget) this.canvasWrapperTarget.classList.add("hidden");
    } else {
      if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.add("hidden");
      if (this.hasCanvasWrapperTarget) this.canvasWrapperTarget.classList.remove("hidden");
    }
  }

  updateVariationCount(event) {
    this.variationCountTarget.textContent = event.target.value;
    this.updateCost();
  }
  
  updateCost() {
    if (this.hasVariationSliderTarget && this.hasCostDisplayTarget) {
      const count = parseInt(this.variationSliderTarget.value) || 1;
      const cost = count * this.creditCostValue;
      this.costDisplayTarget.textContent = cost;
    }
  }

  updateTitle(event) {
    const newTitle = event.target.value;
    const projectId = this.projectIdValue;

    fetch(`/projects/${projectId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ project: { title: newTitle } })
    })
    .then(response => {
      if (response.ok) {
        console.log("Title updated successfully");
      } else {
        console.error("Failed to update title");
      }
    })
    .catch(error => console.error("Error updating title:", error));
  }

  // Preset Dropdown Logic
  togglePresetMenu(event) {
    event.stopPropagation();
    this.presetMenuTarget.classList.toggle("hidden");
  }

  selectPreset(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const button = event.currentTarget;
    const value = button.dataset.value;
    const label = button.dataset.label;

    if (this.hasPresetInputTarget) this.presetInputTarget.value = value;
    if (this.hasPresetLabelTarget) this.presetLabelTarget.textContent = label;
    
    this.presetMenuTarget.classList.add("hidden");
  }

  closeDropdownOutside(event) {
    if (this.hasPresetMenuTarget && !this.presetMenuTarget.classList.contains("hidden")) {
      if (!this.presetMenuTarget.contains(event.target)) {
        this.presetMenuTarget.classList.add("hidden");
      }
    }
  }
}
