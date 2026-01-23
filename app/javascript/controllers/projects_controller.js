import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

//Used by Projects

export default class extends Controller {
  static targets = ["scaleDisplay", "resetZoomBtn", "stylePresetInput", "promptInput", "variationsInput", "aiAssistToggle", "aiAssistLabel", "autoFixResults", "autoFixItem", "autoFixHeader", "autoFixContent", "autoFixChevron", "autoFixDescriptionInput", "layerLink", "generateButton", "canvasToolbar", "smartFixPanel"]
  static values = {
    generationUrl: String,
    imageCost: Number,
    selectedAutoFixId: Number,
    selectedAutoFixTitle: String,
    selectedAutoFixDescription: String
  }

  connect() {
    console.log("Projects controller connected")
    this.updateUndoRedoButtonStates() // Initial state

    // Listen for events from Konva
    this.element.addEventListener('konva:mask-history-changed', this.updateUndoRedoButtonStates.bind(this))
    this.element.addEventListener('project-canvas:transform-changed', this.updateScaleDisplay.bind(this))

    // Initialize UI
    this.validateInputs()
    this.detectInitialTab()
    this.toggleAiAssist()
  }

  detectInitialTab() {
    // Find active tab by looking for the one with active styling (blue border/text)
    const activeTab = this.element.querySelector('[data-tools-target="tab"].text-blue-400')
    if (activeTab) {
      this.updateToolbarVisibility(activeTab.innerText.trim())
    }
  }

  updateToolbarVisibility(tabName) {
    if (this.hasCanvasToolbarTarget) {
      if (tabName === "AutoFix") {
        this.canvasToolbarTarget.classList.add("hidden")
        // Also hide logic from canvas controller if needed?
        // Usually CSS hidden is enough to prevent interaction.
      } else {
        this.canvasToolbarTarget.classList.remove("hidden")
      }
    }
  }



  updateBrushHint(event) {
    const tabName = event.currentTarget.innerText.trim()
    this.updateToolbarVisibility(tabName)

    const canvasController = this.projectCanvasController
    if (canvasController) {
      canvasController.updateBrushHintVisibility(tabName)
    }
  }

  // --- Helpers ---

  switchTab(tabName) {
    const toolsController = this.toolsController
    if (toolsController) {
      const tabButton = toolsController.tabTargets.find(t => t.innerText.trim() === tabName)
      if (tabButton) tabButton.click()
    }

    this.updateToolbarVisibility(tabName)

    const canvasController = this.projectCanvasController
    if (canvasController) {
      canvasController.updateBrushHintVisibility(tabName)
    }
  }


  validateInputs() {
    // Validate Style Preset Panel
    const stylePanel = this.element.querySelector('input[name="generation_type"][value="style_preset"]')?.closest('[data-tools-target="panel"]')
    if (stylePanel) {
       // Look for the inputs within this specific panel/scope to be safe
       const inputs = stylePanel.querySelectorAll('input[name="style_preset"]')
       const hasSelection = Array.from(inputs).some(r => r.checked)
       const btn = stylePanel.querySelector('[data-projects-target="generateButton"]')
       if (btn) btn.disabled = !hasSelection
    }

    // Validate Smart Fix Panel
    const fixPanel = this.element.querySelector('input[name="generation_type"][value="smart_fix"]')?.closest('[data-tools-target="panel"]')
    if (fixPanel) {
        // Use the target if available or query
        const textarea = fixPanel.querySelector('textarea[data-projects-target="promptInput"]')
        const hasText = textarea && textarea.value.trim().length > 0
        const btn = fixPanel.querySelector('[data-projects-target="generateButton"]')
        if (btn) btn.disabled = !hasText
    }
  }

  toggleAiAssist() {
    if (this.hasAiAssistToggleTarget && this.hasAiAssistLabelTarget) {
      const isOn = this.aiAssistToggleTarget.checked
      this.aiAssistLabelTarget.textContent = isOn ? "AI Assist On" : "AI Assist Off"

      if (isOn) {
        this.aiAssistLabelTarget.classList.remove("text-gray-300")
        this.aiAssistLabelTarget.classList.add("text-green-400", "font-bold")
        if (this.hasSmartFixPanelTarget) {
          this.smartFixPanelTarget.classList.add("bg-green-900/20")
        }
      } else {
        this.aiAssistLabelTarget.classList.add("text-gray-300")
        this.aiAssistLabelTarget.classList.remove("text-green-400", "font-bold")
        if (this.hasSmartFixPanelTarget) {
          this.smartFixPanelTarget.classList.remove("bg-green-900/20")
        }
      }
    }
  }





  setActiveLayer(event) {
    // Remove active state from all layers
    this.layerLinkTargets.forEach(el => {
      el.classList.remove("border-blue-500", "bg-gray-600")
      el.classList.add("border-transparent", "bg-gray-700")
    })

    // Add active state to clicked layer
    const layerLink = event.currentTarget
    layerLink.classList.remove("border-transparent", "bg-gray-700")
    layerLink.classList.add("border-blue-500", "bg-gray-600")
    this.selectedAutoFixIdValue = null

    // Optimistically hide the "Unviewed" indicator (blue dot)
    const unviewedIndicator = layerLink.querySelector('[title="New"]')
    if (unviewedIndicator) {
      unviewedIndicator.classList.add("hidden")
    }

    // Sync active layer ID to canvas controller
    const layerId = parseInt(layerLink.dataset.layerId, 10)
    const controller = this.projectCanvasController
    if (controller && layerId) {
      controller.layerIdValue = layerId
    }

    // NOTE: We no longer auto-switch tabs when clicking layers.
    // Users can use "Reuse Prompt/Style" buttons if they want to replicate a generation.
    // This prevents losing work when a new layer loads and tabs change forcibly.
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
         btn.classList.remove('bg-white', 'text-gray-900', 'shadow-lg', 'ring-1', 'ring-gray-200')
         btn.classList.add('bg-white/5', 'text-gray-400', 'hover:bg-white/10', 'hover:text-white')
      })
      button.classList.remove('bg-white/5', 'text-gray-400', 'hover:bg-white/10', 'hover:text-white')
      button.classList.add('bg-white', 'text-gray-900', 'shadow-lg', 'ring-1', 'ring-gray-200')
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
    const controller = this.projectCanvasController
    if (!controller) return

    const panBtn = event.currentTarget

    if (controller.currentTool === 'pan') {
       // Toggle OFF -> Revert to Brush
       // Note: Brush button is in a different container (toolbar) than Pan button (footer)
       // always switch back to brush regardless of UI state
       controller.setTool({ params: { tool: 'brush' } })

       const brushBtn = document.querySelector('[data-action="projects#setBrushTool"]')
       if (brushBtn) {
         this._updateToolUI("brush", brushBtn)
       }

       // Manually reset Pan button to inactive state
       panBtn.classList.remove('bg-white', 'text-gray-900', 'shadow-lg', 'ring-1', 'ring-gray-200')
       panBtn.classList.add('bg-white/5', 'text-gray-400', 'hover:bg-white/10', 'hover:text-white', 'border-transparent')
    } else {
       // Toggle ON -> Set to Pan
       // We can simply add active classes here, but _updateToolUI might rely on siblings which Pan doesn't check against Toolbar
       panBtn.classList.remove('bg-white/5', 'text-gray-400', 'hover:bg-white/10', 'hover:text-white', 'border-transparent')
       panBtn.classList.add('bg-white', 'text-gray-900', 'shadow-lg', 'ring-1', 'ring-gray-200')

       controller.setTool({ params: { tool: 'pan' } })
    }
  }

  updateScaleDisplay(event) {
    // Also updates reset button visibility
    const { scale, relativeScale, isReset } = event.detail;

    if (this.hasScaleDisplayTarget) {
      const zoomValue = relativeScale || scale;
      const percentage = Math.round(zoomValue * 100);
      this.scaleDisplayTarget.textContent = `${percentage}%`;
    }

    if (this.hasResetZoomBtnTarget) {
      this.resetZoomBtnTargets.forEach(el => {
        if (isReset) {
          el.removeAttribute('data-visible');
          el.classList.add('invisible');
        } else {
          el.setAttribute('data-visible', 'true');
          el.classList.remove('invisible');
        }
      });
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

    // Determine Mode via Tools Tabs
    const toolsController = this.toolsController
    let activeTabName = ""
    if (toolsController) {
      const activeTab = toolsController.tabTargets.find(t => t.classList.contains(...toolsController.activeClasses))
      if (activeTab) activeTabName = activeTab.innerText.trim()
    }

    // Presets Flow:
    if (activeTabName === "Style Presets") {
      if (this.hasStylePresetInputTarget) {
        const selectedPreset = this.stylePresetInputTargets.find(input => input.checked)
        if (selectedPreset) {
          formData.append("preset", selectedPreset.value)
        }
      }
    }

    // SmartFix Flow:
    if (activeTabName === "SmartFix") {
      // Prompt:
      if (this.hasPromptInputTarget && this.promptInputTarget.value.trim().length > 0) {
        formData.append("prompt", this.promptInputTarget.value)
      }

      // AI Assist:
      if (this.hasAiAssistToggleTarget) {
        formData.append("ai_assist", this.aiAssistToggleTarget.checked)
      }
    }

    // Determine Active Panel to scope inputs (Generation Type & Variations)
    let activePanel = null
    if (this.toolsController) {
      activePanel = this.toolsController.panelTargets.find(panel => !panel.classList.contains('hidden'))
    }

    // Variations: Prefer input inside active panel, fallback to generic target
    let variationsInput = null
    if (activePanel) {
        variationsInput = activePanel.querySelector('[data-projects-target="variationsInput"]')
    }

    // If not found in active panel (or no active panel), try the first generic target as fallback
    if (!variationsInput && this.hasVariationsInputTarget) {
        variationsInput = this.variationsInputTarget
    }

    if (variationsInput) {
      formData.append("variations", variationsInput.value)
    }

    // Generation Type
    if (activePanel) {
        const typeInput = activePanel.querySelector('input[name="generation_type"]')
        if (typeInput) {
          formData.append("generation_type", typeInput.value)
        }
    }

    // Fallback if not found (though logic above should cover it)
    if (!formData.has("generation_type")) {
       formData.append("generation_type", "style_preset")
    }

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

      const contentType = response.headers.get("content-type")
      if (contentType && contentType.includes("turbo-stream")) {
           const html = await response.text()
           await Turbo.renderStreamMessage(html)
           this.projectOnboardingController?.startStylePresetsLayerHint()
      } else if (response.ok) {
           console.log("Generation started successfully")
      } else {
        console.error("Generation failed", response)
        alert("Generation failed. Please try again.")
      }
    } catch (error) {
      console.error("Network error during generation", error)
      alert("Network error. Please try again.")
    } finally {
      // 3-second cooldown before re-enabling button to prevent rage clicking
      setTimeout(() => {
        button.disabled = false
        button.innerText = originalText
      }, 3000)
    }
  }

  // --- AutoFix Actions ---

  toggleAutoFix(event) {
    const item = event.currentTarget.closest('[data-projects-target="autoFixItem"]')
    const content = item.querySelector('[data-projects-target="autoFixContent"]')
    const chevron = item.querySelector('[data-projects-target="autoFixChevron"]')

    // Collapse others
    this.autoFixItemTargets.forEach(other => {
      if (other !== item) {
        other.querySelector('[data-projects-target="autoFixContent"]').classList.add("hidden")
        other.querySelector('[data-projects-target="autoFixChevron"]').classList.remove("rotate-180")
        other.classList.remove("border-blue-500", "ring-1", "ring-blue-500/50")
      }
    })

    // Toggle current
    const isHidden = content.classList.toggle("hidden")
    chevron.classList.toggle("rotate-180", !isHidden)
    item.classList.toggle("border-blue-500", !isHidden)
    item.classList.toggle("ring-1", !isHidden)
    item.classList.toggle("ring-blue-500/50", !isHidden)

    if (!isHidden) {
      setTimeout(() => {
        item.scrollIntoView({ behavior: "smooth", block: "nearest" })
      }, 200)
    }
  }

  async performAutoFix(event) {
    if (event) event.preventDefault()

    const item = event.currentTarget.closest('[data-projects-target="autoFixItem"]')
    const descriptionInput = item.querySelector('[data-projects-target="autoFixDescriptionInput"]')
    const variationsInput = item.querySelector('[data-projects-target="variationsInput"]')
    const fixId = event.currentTarget.dataset.autoFixId
    const fixTitle = event.currentTarget.dataset.autoFixTitle

    const controller = this.projectCanvasController
    if (!controller) {
      console.error("No canvas controller found")
      return
    }

    const fixParentLayerId = parseInt(event.currentTarget.dataset.parentLayerId, 10)
    let parentLayerId = controller.layerIdValue

    if (fixParentLayerId && fixParentLayerId !== parentLayerId) {
      // Highlight/Switch to the parent layer
      this._selectLayerById(String(fixParentLayerId))
      parentLayerId = fixParentLayerId
      // Ensure local controller value is updated synchronously if needed,
      // though _selectLayerById triggers a click which updates it.
      // We'll rely on the updated parentLayerId for the request below.
    }

    if (!parentLayerId) {
      alert("No parent layer selected.")
      return
    }

    // Construct the prompt from AutoFix title + (potentially edited) description
    const prompt = `${fixTitle}: ${descriptionInput.value}`

    const formData = new FormData()
    formData.append("parent_layer_id", parentLayerId)
    formData.append("prompt", prompt)
    formData.append("ai_assist", "true")
    formData.append("auto_fix_id", fixId)
    formData.append("layer_type", "generated")
    formData.append("generation_type", "autofix")
    formData.append("variations", variationsInput.value)

    // Disable button
    const button = event.currentTarget
    const originalText = button.innerHTML
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

      const contentType = response.headers.get("content-type")
      if (contentType && contentType.includes("turbo-stream")) {
           const html = await response.text()
           await Turbo.renderStreamMessage(html)
      } else if (response.ok) {
           console.log("AutoFix generation started successfully")
      } else {
        console.error("AutoFix generation failed", response)
        alert("Generation failed. Please try again.")
      }
    } catch (error) {
      console.error("Network error during AutoFix generation", error)
      alert("Network error. Please try again.")
    } finally {
      // 4-second cooldown before re-enabling button to prevent rage clicking
      setTimeout(() => {
        button.disabled = false
        button.innerHTML = originalText
      }, 6000)
    }
  }

  handleDockClick(event) {
    const tabName = event.currentTarget.dataset.tabName
    if (!tabName) return

    const layout = this.layoutController
    const tools = this.toolsController

    if (!layout || !tools) {
        // Fallback if controllers missing
        this.switchTab(tabName)
        return
    }

    // Check availability via DOM for now as layout state might be on element
    const rightSidebar = document.querySelector('[data-layout-target="sidebarRight"]')
    const isExpanded = rightSidebar && rightSidebar.getAttribute("aria-expanded") === "true"

    // Check if Active
    const tabIndex = tools.tabTargets.findIndex(t => t.innerText.trim() === tabName)
    const panel = tools.panelTargets[tabIndex]
    const isActive = panel && !panel.classList.contains("hidden")

    if (isExpanded && isActive) {
        layout.closeRight()
    } else {
        layout.openRight()
        this.switchTab(tabName)
    }
  }

  switchDesign(event) {
    const url = event.target.value
    if (url) {
      window.location.href = url
    }
  }

  // --- Context Specific Actions ---

  selectPresetFromTopBar(event) {
    const preset = event.currentTarget.dataset.preset
    this.layoutController?.openRight()
    this.switchTab("Style Presets")

    if (this.hasStylePresetInputTarget) {
      const input = this.stylePresetInputTargets.find(i => i.value === preset)
      if (input) {
        input.checked = true
        // Trigger any associated logic if needed, but usually just checking is enough for the UI
      }
    }
  }

  reuseStyle(event) {
    const preset = event.currentTarget.dataset.preset
    const parentId = event.currentTarget.dataset.parentId

    // 1. Select Parent Layer
    this._selectLayerById(parentId)

    // 2. Select Tab
    this.layoutController?.openRight()
    this.switchTab("Style Presets")

    // 3. Select Preset
    if (this.hasStylePresetInputTarget) {
      const input = this.stylePresetInputTargets.find(i => i.value === preset)
      if (input) input.checked = true
    }
  }

  reusePrompt(event) {
    const prompt = event.currentTarget.dataset.prompt
    const parentId = event.currentTarget.dataset.parentId

    // 1. Select Parent Layer
    this._selectLayerById(parentId)

    // 2. Select Tab
    this.layoutController?.openRight()
    this.switchTab("SmartFix")

    // 3. Populate Prompt
    if (this.hasPromptInputTarget) {
      this.promptInputTarget.value = prompt
    }

    // 4. Toggle AI Assist ON
    if (this.hasAiAssistToggleTarget) {
      this.aiAssistToggleTarget.checked = true
      this.toggleAiAssistLabel()
    }

    // 5. Validate Inputs to update button state
    this.validateInputs()
  }

  redoFix(event) {
    const fixId = event.currentTarget.dataset.fixId
    const parentId = event.currentTarget.dataset.parentId

    // 1. Select Parent Layer
    this._selectLayerById(parentId)

    // 2. Select Tab
    this.layoutController?.openRight()
    this.switchTab("AutoFix")

    // 3. Highlight/Open Fix (This might need a bit more logic to find the item in the list)
    // We'll rely on the existing toggle logic or data-auto-fix-id attributes
    setTimeout(() => {
      const item = this.autoFixItemTargets.find(el => {
        const btn = el.querySelector('[data-auto-fix-id]')
        return btn && btn.dataset.autoFixId === fixId
      })
      if (item) {
        const header = item.querySelector('[data-action*="toggleAutoFix"]')
        if (header) header.click()
      }
    }, 300) // Small delay to allow Turbo to render the list if it was empty
  }



  get toolsController() {
    const toolsElement = document.querySelector('[data-controller="tools"]')
    if (toolsElement) {
      return this.application.getControllerForElementAndIdentifier(toolsElement, "tools")
    }
    return null
  }

  get layoutController() {
    const layoutElement = document.querySelector('[data-controller~="layout"]')
    if (layoutElement) {
      return this.application.getControllerForElementAndIdentifier(layoutElement, "layout")
    }
    return null
  }

  get projectOnboardingController() {
    const onboardingElement = document.querySelector('[data-controller~="project-onboarding"]')
    if (onboardingElement) {
      return this.application.getControllerForElementAndIdentifier(onboardingElement, "project-onboarding")
    }
    return null
  }

  _selectLayerById(layerId) {
    if (!layerId) return
    const link = this.layerLinkTargets.find(l => l.dataset.layerId === layerId)
    if (link) {
      link.click()
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').getAttribute('content')
  }
}
