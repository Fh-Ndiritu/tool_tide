import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "canvasWrapper", "sidebarLayers", "toolsPanel", "promptInput",
    "variationSlider", "variationCount", "emptyState", "resultList",
    "presetMenu", "presetInput", "presetLabel", "costDisplay",
    "presetSection", "customSection", "presetModeBtn", "customModeBtn",
    "maskInput", "form", "sidebarLayer"
  ];

  static outlets = ["konva-canvas"];

  static values = {
    projectId: Number,
    activeLayerId: Number,
    creditCost: { type: Number, default: 8 }
  };

  connect() {
    console.log("Unified Dashboard Connected");
    this.updateUIState();
    this.updateCost();
    this.highlightActiveLayer();

    // Close dropdown when clicking outside
    document.addEventListener("click", this.closeDropdownOutside.bind(this));

    // Initialize Mode
    this.currentMode = "preset";
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

  // Mode Toggling
  setMode(event) {
    const mode = event.currentTarget.dataset.mode;
    this.currentMode = mode;

    if (mode === "preset") {
      this.presetSectionTarget.classList.remove("hidden");
      this.customSectionTarget.classList.add("hidden");

      this.presetModeBtnTarget.classList.add("bg-white", "text-black", "shadow");
      this.presetModeBtnTarget.classList.remove("text-gray-500");

      this.customModeBtnTarget.classList.remove("bg-white", "text-black", "shadow");
      this.customModeBtnTarget.classList.add("text-gray-500");

      // Clear custom prompt
      if(this.hasPromptInputTarget) this.promptInputTarget.value = "";
    } else {
      this.presetSectionTarget.classList.add("hidden");
      this.customSectionTarget.classList.remove("hidden");

      this.customModeBtnTarget.classList.add("bg-white", "text-black", "shadow");
      this.customModeBtnTarget.classList.remove("text-gray-500");

      this.presetModeBtnTarget.classList.remove("bg-white", "text-black", "shadow");
      this.presetModeBtnTarget.classList.add("text-gray-500");

      // Clear preset
      if(this.hasPresetInputTarget) this.presetInputTarget.value = "";
    }
  }

  prepareSubmission(event) {
    // 1. Get Mask Data
    if (this.hasKonvaCanvasOutlet) {
      console.log("Fetching mask data from Konva Outlet...");
      const maskData = this.konvaCanvasOutlet.getMaskDataURL();
      if (maskData) {
        console.log("Mask data found, setting hidden input.");
        this.maskInputTarget.value = maskData;
      } else {
        console.log("No mask data returned.");
        this.maskInputTarget.value = "";
      }
    } else {
      console.warn("Konva Canvas Outlet not found.");
    }

    // 2. Validate inputs based on mode
    if (this.currentMode === "preset" && !this.presetInputTarget.value) {
      event.preventDefault();
      alert("Please select a style preset.");
    } else if (this.currentMode === "custom") {
       // Check textarea inside customSection
       const textarea = this.customSectionTarget.querySelector("textarea");
       if (textarea && !textarea.value.trim()) {
         event.preventDefault();
         alert("Please enter a prompt.");
       }
    }

    // Form submits automatically after this unless prevented
    console.log("Form submitting...");
  }

  selectLayer(event) {
    const { id, imageUrl } = event.params;
    console.log(`Selecting layer: ${id}, URL: ${imageUrl}`);

    this.activeLayerIdValue = id;

    if (imageUrl && this.hasKonvaCanvasOutlet) {
      this.konvaCanvasOutlet.imageUrlValue = imageUrl;
    }
  }

  activeLayerIdValueChanged() {
    this.highlightActiveLayer();
  }

  highlightActiveLayer() {
    const activeId = this.activeLayerIdValue;
    if (!activeId) return;

    this.sidebarLayerTargets.forEach(el => {
      const layerId = parseInt(el.dataset.unifiedDashboardLayerIdParam);
      if (layerId === activeId) {
        el.classList.add("ring-2", "ring-green-500", "bg-[#444]");
      } else {
        el.classList.remove("ring-2", "ring-green-500", "bg-[#444]");
      }
    });
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
