import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "canvasWrapper", "sidebarLayers", "toolsPanel", "promptInput",
    "variationSlider", "variationCount", "emptyState", "resultList",
    "presetMenu", "presetInput", "presetLabel", "costDisplay",
    "presetSection", "customSection", "presetModeBtn", "customModeBtn",
    "maskInput", "form", "sidebarLayer", "generateBtn", "brushSizeDisplay",
    "brushTab", "plantTab", "sketchTab",
    "brushPanel", "plantPanel", "sketchPanel", "zoomLevel",
    "brushRange", "sliderFill", "sliderThumb"
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
    document.addEventListener("click", this.closeDropdownOutside);

    // Initialize Mode
    this.currentMode = "preset";
    this.currentScale = 1;

    // Initialize Tool
    this.setActiveToolUI("brush");
  }

  disconnect() {
    document.removeEventListener("click", this.closeDropdownOutside);
  }

  closeDropdownOutside = (event) => {
    if (this.hasPresetMenuTarget && !this.presetMenuTarget.classList.contains("hidden")) {
      const isClickInside = this.presetDropdownTarget.contains(event.target);
      if (!isClickInside) {
        this.presetMenuTarget.classList.add("hidden");
      }
    }
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
    this.validateGeneration();
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
    this.incrementViews(id);

    if (imageUrl && this.hasKonvaCanvasOutlet) {
      this.konvaCanvasOutlet.imageUrlValue = imageUrl;
    }
  }

  incrementViews(layerId) {
    const projectId = this.projectIdValue;
    fetch(`/projects/${projectId}/layers/${layerId}/view`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => {
      if (response.ok) {
        console.log(`Views incremented for layer ${layerId}`);
        // Optionally update the UI to remove the "New" highlight
        const layerEl = this.sidebarLayerTargets.find(el => parseInt(el.dataset.unifiedDashboardLayerIdParam) === layerId);
        if (layerEl) {
          const dot = layerEl.querySelector(".unviewed-dot");
          if (dot) dot.remove();
        }
      }
    })
    .catch(error => console.error("Error incrementing views:", error));
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
    this.validateGeneration();
  }

  validateGeneration() {
    let isValid = false;
    if (this.currentMode === "preset") {
      isValid = !!this.presetInputTarget.value;
    } else {
      isValid = !!this.promptInputTarget.value.trim();
    }

    if (this.hasGenerateBtnTarget) {
      this.generateBtnTarget.disabled = !isValid;
      if (isValid) {
        this.generateBtnTarget.classList.remove("bg-gray-600", "cursor-not-allowed", "opacity-50");
        this.generateBtnTarget.classList.add("bg-green-500", "hover:bg-green-400", "hover:shadow-[0_0_15px_rgba(34,197,94,0.4)]");
      } else {
        this.generateBtnTarget.classList.add("bg-gray-600", "cursor-not-allowed", "opacity-50");
        this.generateBtnTarget.classList.remove("bg-green-500", "hover:bg-green-400", "hover:shadow-[0_0_15px_rgba(34,197,94,0.4)]");
      }
    }
  }

  updateBrushSizeDisplay(event) {
    if (this.hasBrushSizeDisplayTarget) {
      this.brushSizeDisplayTarget.textContent = `${event.target.value}px`;
    }
  }

  // --- Tool Tabs Logic ---
  switchToolTab(event) {
    const tabName = event.currentTarget.dataset.tab;
    const tabs = ["brush", "plant", "sketch"];

    tabs.forEach(t => {
      const btn = this[`${t}TabTarget`];
      const panel = this[`${t}PanelTarget`];

      if (t === tabName) {
        btn.classList.add("text-white", "border-b-2", "border-green-500");
        btn.classList.remove("text-gray-400", "border-transparent");
        panel.classList.remove("hidden");
      } else {
        btn.classList.remove("text-white", "border-b-2", "border-green-500");
        btn.classList.add("text-gray-400", "border-transparent");
        panel.classList.add("hidden");
      }
    });
  }

  // --- Konva Canvas Delegation ---
  setTool(event) {
    const toolName = event.params.tool;
    if (this.hasKonvaCanvasOutlet) {
      this.konvaCanvasOutlet.setTool({ params: event.params });
    }
    this.setActiveToolUI(toolName);
  }

  setActiveToolUI(toolName) {
    const buttons = this.element.querySelectorAll('[data-action="click->unified-dashboard#setTool"]');

    buttons.forEach(btn => {
      const isTarget = btn.dataset.unifiedDashboardToolParam === toolName;
      const svg = btn.querySelector("svg");

      if (isTarget) {
        btn.classList.add("ring-2", "ring-green-500", "bg-[#444]");
        btn.classList.remove("border-transparent");
        if (svg) {
          svg.classList.remove("text-gray-400");
          svg.classList.add("text-white");
        }
      } else {
        btn.classList.remove("ring-2", "ring-green-500", "bg-[#444]");
        btn.classList.add("border-transparent");
        if (svg) {
          svg.classList.remove("text-white");
          svg.classList.add("text-gray-400");
        }
      }
    });
  }



  // --- Zoom Logic ---
  zoomIn() {
    this.updateZoom(0.1);
  }

  zoomOut() {
    this.updateZoom(-0.1);
  }

  updateZoom(delta) {
    let newScale = this.currentScale + delta;
    // Clamp scale between 0.1 and 3.0
    newScale = Math.min(Math.max(newScale, 0.1), 3.0);

    // Round to 1 decimal place to avoid floating point weirdness
    this.currentScale = Math.round(newScale * 10) / 10;

    this.updateZoomUI();

    if (this.hasKonvaCanvasOutlet) {
      this.konvaCanvasOutlet.setZoom(this.currentScale);
    }
  }

  updateZoomUI() {
    if (this.hasZoomLevelTarget) {
      this.zoomLevelTarget.textContent = `${Math.round(this.currentScale * 100)}%`;
    }
  }

  undo() {
    if (this.hasKonvaCanvasOutlet) this.konvaCanvasOutlet.undo();
  }

  redo() {
    if (this.hasKonvaCanvasOutlet) this.konvaCanvasOutlet.redo();
  }

  clearSelection() {
    if (this.hasKonvaCanvasOutlet) this.konvaCanvasOutlet.clearSelection();
  }

  setBrushSizeFromUI(event) {
    if (this.hasKonvaCanvasOutlet) this.konvaCanvasOutlet.setBrushSizeFromUI(event);
    this.updateBrushSizeDisplay(event);

    // Update Slider Visuals
    const size = parseInt(event.target.value, 10);
    if (this.hasBrushRangeTarget && this.hasSliderFillTarget && this.hasSliderThumbTarget) {
      const min = parseInt(this.brushRangeTarget.min, 10) || 1;
      const max = parseInt(this.brushRangeTarget.max, 10) || 100;

      const pct = (size - min) / (max - min);
      const percent = pct * 100;

      this.sliderFillTarget.style.width = `${percent}%`;
      this.sliderThumbTarget.style.left = `${percent}%`;
    }
  }

  // --- Plant Suggestions ---
  requestPlantSuggestions() {
      // Logic to request plant suggestions
      alert("Requesting plant suggestions... (This would trigger a backend job)");
  }

  // --- Layer Collapsing ---
  toggleLayer(event) {
      event.stopPropagation();
      const layerId = event.currentTarget.dataset.layerId;
      const childrenContainer = document.getElementById(`layer_children_${layerId}`);
      const icon = event.currentTarget.querySelector("svg");

      if (childrenContainer) {
          childrenContainer.classList.toggle("hidden");
          if (childrenContainer.classList.contains("hidden")) {
              icon.classList.remove("rotate-90");
          } else {
              icon.classList.add("rotate-90");
          }
      }
  }
}
