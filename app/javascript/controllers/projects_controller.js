import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["brushSizeControl", "brushSizeDisplay", "brushRange", "fill", "track", "thumb", "scaleDisplay", "resetZoomBtn", "stylePresetInput", "promptInput", "variationsCount", "variationsInput", "costDisplay", "aiAssistToggle", "aiAssistLabel", "toolsPanel", "toolsToggleIcon"]
  static values = {
    generationUrl: String,
    imageCost: Number
  }

  connect() {
    console.log("Projects controller connected")
    this.updateUndoRedoButtonStates() // Initial state

    // Listen for events from Konva
    this.element.addEventListener('konva:mask-history-changed', this.updateUndoRedoButtonStates.bind(this))
    this.element.addEventListener('project-canvas:transform-changed', this.updateScaleDisplay.bind(this))

    // Initialize UI
    this.initializeBrushSize()
    this.updateCost()
  }

  incrementVariations(event) {
    if (event) event.preventDefault()
    let current = parseInt(this.variationsInputTarget.value, 10) || 1
    if (current < 4) {
      current++
      this.updateVariationsUI(current)
    }
  }

  decrementVariations(event) {
    if (event) event.preventDefault()
    let current = parseInt(this.variationsInputTarget.value, 10) || 1
    if (current > 1) {
      current--
      this.updateVariationsUI(current)
    }
  }

  updateVariationsUI(count) {
    if (this.hasVariationsInputTarget) this.variationsInputTarget.value = count
    if (this.hasVariationsCountTarget) this.variationsCountTarget.textContent = count
    this.updateCost()
  }

  updateCost() {
    if (!this.hasCostDisplayTarget || !this.hasVariationsInputTarget) return

    const count = parseInt(this.variationsInputTarget.value, 10) || 1
    const cost = count * (this.imageCostValue || 8) // Fallback to 8 if value not set yet

    this.costDisplayTarget.textContent = `${cost} credits`
  }

  toggleAiAssistLabel() {
    if (this.hasAiAssistToggleTarget && this.hasAiAssistLabelTarget) {
      this.aiAssistLabelTarget.textContent = this.aiAssistToggleTarget.checked ? "AI Assist On" : "AI Assist Off"
    }
  }

  toggleTools() {
    if (this.hasToolsPanelTarget) {
      this.toolsPanelTarget.classList.toggle("hidden")
    }
    if (this.hasToolsToggleIconTarget) {
      this.toolsToggleIconTarget.classList.toggle("rotate-180")
    }
  }

  initializeBrushSize() {
      if (this.hasBrushRangeTarget) {
          const initialSize = parseInt(this.brushRangeTarget.value, 10) || 60
          this.setBrushSize(initialSize)
      }
  }

  setActiveLayer(event) {
    // Remove active state from all layers
    this.element.querySelectorAll('a[data-action="click->projects#setActiveLayer"]').forEach(el => {
      el.classList.remove("border-blue-500", "bg-gray-600")
      el.classList.add("border-transparent", "bg-gray-700")
    })

    // Add active state to clicked layer
    const layerLink = event.currentTarget
    layerLink.classList.remove("border-transparent", "bg-gray-700")
    layerLink.classList.add("border-blue-500", "bg-gray-600")
  }

  // --- Project Canvas Delegation ---

  get projectCanvasController() {
    const canvasElement = document.querySelector('[data-controller="project-canvas"]')
    if (canvasElement) {
      return this.application.getControllerForElementAndIdentifier(canvasElement, "project-canvas")
    }
    return null
  }

  setBrushTool(event) {
    // Update UI for Brush Button
    this._updateToolUI("brush", event.currentTarget)

    const controller = this.projectCanvasController
    if (controller) {
      controller.setTool({ params: { tool: 'brush' } })
    }
  }

  setEraserTool(event) {
    // Update UI for Eraser Button
    this._updateToolUI("eraser", event.currentTarget)

    const controller = this.projectCanvasController
    if (controller) {
      controller.setTool({ params: { tool: 'eraser' } })
    }
  }

  _updateToolUI(tool, button) {
    // Basic toggle logic for the button group (assuming 2 buttons: Brush, Eraser)
    // This relies on the buttons being siblings or identifiable.
    // For now, simpler: toggle classes on the clicked button vs its siblings.

    const parent = button.parentElement
    if (parent) {
      parent.querySelectorAll('button').forEach(btn => {
         btn.classList.remove('bg-gray-600', 'text-white', 'border-blue-500', 'border')
         btn.classList.add('text-gray-400', 'hover:bg-gray-600')
      })
      button.classList.remove('text-gray-400', 'hover:bg-gray-600')
      button.classList.add('bg-gray-600', 'text-white', 'border', 'border-blue-500')
    }
  }

  updateBrushSize(event) {
    const size = parseInt(event.target.value, 10);
    this.setBrushSize(size);

    const controller = this.projectCanvasController
    if (controller) {
       controller.brushSizeValue = size
       // Force update if needed, though value change usually triggers it
       controller.brushSizeValueChanged()
    }
  }

  setBrushSize(size) {
    // Update Custom Slider UI (reused logic from mask_request_controller)
    if (!this.hasBrushRangeTarget) return;

    const min = parseInt(this.brushRangeTarget.min, 10);
    const max = parseInt(this.brushRangeTarget.max, 10);
    const fillPercentage = (size - min) / (max - min);

    const fillWidth = `${fillPercentage * 100}%`;
    const trackLeft = `${fillPercentage * 100}%`;
    const trackWidth = `${(1 - fillPercentage) * 100}%`;

    // Thumb positioning logic
    const baseThumbSize = 20;
    const maxThumbSize = 40;
    const thumbSize = baseThumbSize + (fillPercentage * (maxThumbSize - baseThumbSize));
    const thumbLeft = `${fillPercentage * 100}%`;

    if (this.hasFillTarget) this.fillTarget.style.width = fillWidth;
    if (this.hasTrackTarget) {
      this.trackTarget.style.left = trackLeft;
      this.trackTarget.style.width = trackWidth;
    }
    if (this.hasThumbTarget) {
      this.thumbTarget.style.left = thumbLeft;
      this.thumbTarget.style.setProperty('--thumb-size', `${thumbSize}px`);
    }
    if (this.hasBrushSizeDisplayTarget) {
      this.brushSizeDisplayTarget.textContent = `${size}PX`;
    }
  }

  undo() {
    const controller = this.projectCanvasController
    if (controller) controller.undo()
  }

  redo() {
    const controller = this.projectCanvasController
    if (controller) controller.redo()
  }

  clear() {
    if (confirm("Clear all selections?")) {
      const controller = this.projectCanvasController
      if (controller) controller.clearSelection()
    }
  }

  toggleZoom() {
    const controller = this.projectCanvasController
    if (controller) controller.toggleZoom()
  }

  zoomIn() {
    const controller = this.projectCanvasController
    if (controller) controller.zoomIn()
  }

  zoomOut() {
    const controller = this.projectCanvasController
    if (controller) controller.zoomOut()
  }

  resetZoom() {
    const controller = this.projectCanvasController
    if (controller) controller.resetZoom()
  }

  setPanTool(event) {
    this._updateToolUI("pan", event.currentTarget)
    const controller = this.projectCanvasController
    if (controller) controller.setTool({ params: { tool: 'pan' } })
  }

  updateScaleDisplay(event) {
    // Also updates reset button visibility
    const { scale, isReset } = event.detail;

    if (this.hasScaleDisplayTarget) {
      const percentage = Math.round(scale * 100);
      this.scaleDisplayTarget.textContent = `${percentage}%`;
    }

    if (this.hasResetZoomBtnTarget) {
      if (isReset) {
        this.resetZoomBtnTarget.classList.add('hidden');
      } else {
        this.resetZoomBtnTarget.classList.remove('hidden');
      }
    }
  }

  updateUndoRedoButtonStates(event) {
     const controller = this.projectCanvasController
     // Can update buttons here if we implement targets for them
  }

  async generate(event) {
    if (event) event.preventDefault()

    const controller = this.projectCanvasController
    if (!controller) {
      console.error("No canvas controller found")
      return
    }

    const maskData = controller.getMaskDataURL()
    const parentLayerId = controller.layerIdValue

    if (!parentLayerId) {
      alert("No parent layer selected.")
      return
    }

    const formData = new FormData()
    formData.append("mask_data", maskData)
    formData.append("parent_layer_id", parentLayerId)

    // Determine Mode via Tabs (Basic check: see which input has value or is visible)
    // Or just grab both and let backend prioritize.
    // Presets:
    if (this.hasStylePresetInputTarget) {
      const selectedPreset = this.stylePresetInputTargets.find(input => input.checked)
      if (selectedPreset) {
        formData.append("preset", selectedPreset.value)
      }
    }

    // Prompt:
    if (this.hasPromptInputTarget && this.promptInputTarget.value.trim().length > 0) {
      formData.append("prompt", this.promptInputTarget.value)
    }

    // AI Assist:
    if (this.hasAiAssistToggleTarget) {
      formData.append("ai_assist", this.aiAssistToggleTarget.checked)
    }

    // Variations
    if (this.hasVariationsInputTarget) {
      formData.append("variations", this.variationsInputTarget.value)
    }

    // Provide a default 'generated' type or let backend handle
    formData.append("layer_type", "generated")

    // Disable button state to prevent double submit
    const button = event.currentTarget
    const originalText = button.innerText
    button.disabled = true
    button.innerText = "Generating..."

    try {
      const response = await fetch(this.generationUrlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: formData
      })

      if (response.ok) {
        // Success: Turbo Stream will update the UI
        console.log("Generation started successfully")
        // Clear selection on success?
        controller.clearSelection()
      } else {
        console.error("Generation failed", response)
        alert("Generation failed. Please try again.")
      }
    } catch (error) {
      console.error("Network error during generation", error)
      alert("Network error. Please try again.")
    } finally {
      button.disabled = false
      button.innerText = originalText
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').getAttribute('content')
  }
}
