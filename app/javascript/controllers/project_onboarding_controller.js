import { Controller } from "@hotwired/stimulus"
import { driver } from "driver.js"

export default class extends Controller {
  static targets = [
    "stylePresetsTab", "smartFixTab", "autoFixTab",
    "presetGrid", "firstPreset", "variations", "generateBtn",
    "layerLink", "originalLayer", "aiAssistToggle", "recommendFixesBtn", "firstFixItem"
  ]

  static values = {
    stylePresetsStatus: String,
    smartFixStatus: String,
    autoFixStatus: String,
    showSmartFixWarning: Boolean
  }

  connect() {
    console.log("Project Onboarding Controller Connected")
    setTimeout(() => this.initOnboarding(), 500) // Delay to ensure layout is ready
  }

  stylePresetsStatusValueChanged() {
    this.initOnboarding()
  }

  smartFixStatusValueChanged() {
    this.initOnboarding()
  }

  autoFixStatusValueChanged() {
    this.initOnboarding()
  }

  initOnboarding() {
    // Determine which tool tour to start based on statuses and current active tab
    // Small delay to allow DOM updates from vanilla JS tab switcher
    setTimeout(() => {
        const activeTab = this.getActiveTabName()
        console.log("InitOnboarding: Active Tab:", activeTab, "Status:", this.stylePresetsStatusValue)

        if (activeTab === "Style Presets") {
             if (this.stylePresetsStatusValue === "not_started" || this.stylePresetsStatusValue === "intro_seen") {
                 this.handleStylePresetsTour()
             } else if (this.stylePresetsStatusValue === "generate_seen") {
                  this.startStylePresetsLayerHint()
             }
        } else if (activeTab === "SmartFix") {
             if (this.smartFixStatusValue !== "completed") {
                 this.handleSmartFixTour()
             } else if (this.showSmartFixWarningValue) {
                 this.handleSmartFixWarning()
             }
        } else if (activeTab === "AutoFix") {
             if (this.autoFixStatusValue !== "completed") {
                 this.handleAutoFixTour()
             }
        }
    }, 100)
  }

  getActiveTabName() {
    // Check panels directly as they are the source of truth for visibility
    const stylePresetsPanel = document.getElementById('panel_style_presets')
    const smartFixPanel = document.getElementById('panel_smart_fix')
    const autoFixPanel = document.getElementById('panel_auto_fix')

    if (stylePresetsPanel && !stylePresetsPanel.classList.contains('hidden')) return "Style Presets"
    if (smartFixPanel && !smartFixPanel.classList.contains('hidden')) return "SmartFix"
    if (autoFixPanel && !autoFixPanel.classList.contains('hidden')) return "AutoFix"

    return null
  }

  handleStylePresetsTour() {
    const steps = [
      {
        element: this.stylePresetsTabTarget,
        popover: {
          title: "Style Presets",
          description: "Start here to instantly transform your garden with curated landscape styles."
        }
      }
    ]

    if (this.hasFirstPresetTarget) {
      steps.push({
        element: this.firstPresetTarget,
        popover: {
          title: "Select a Preset",
          description: "Choose a style from the grid to see common landscape transformations."
        }
      })
    }

    const canvasWrap = document.getElementById('canvas-fixed-wrapper')
    if (canvasWrap) {
      steps.push({
        element: canvasWrap,
        popover: {
          title: "Paint the Canvas",
          description: "Paint the areas you want to modify (e.g., grass, fence or add the garden to). If you don't paint anything, the style will be applied to the whole image.",
          side: "center",
          align: "start"
        }
      })
    }

    if (this.hasVariationsTarget) {
      steps.push({
        element: this.variationsTarget,
        popover: {
          title: "Choose Variations",
          description: "Select how many versions you want to generate. Note that more variations impact credit charges."
        }
      })
    }

    if (this.hasGenerateBtnTarget) {
      steps.push({
        element: this.generateBtnTarget,
        popover: {
          title: "Generate Now",
          description: "Ready to go? Click Generate Now to see your transformations streamed into layers."
        }
      })
    }

    this.startTour(steps, {
      onNextClick: () => {
        this.driverObj.moveNext()
      },
      onDestroyed: () => {
        // If the user closes the tour at any point, we mark it as seen so it doesn't pop up again
        // "generate_seen" effectively silences the intro tour but keeps the layer hint available
        if (this.stylePresetsStatusValue === "not_started" || this.stylePresetsStatusValue === "intro_seen") {
             this.updateStatus("style_presets", "generate_seen")
        }
      }
    })
  }

  startTour(steps, options = {}) {
    if (this.driverObj) this.driverObj.destroy()

    const defaultOptions = {
      showProgress: false,
      animate: true,
      allowClose: false,
      steps: steps
    }

    this.driverObj = driver({ ...defaultOptions, ...options })
    this.driverObj.drive()
  }

  startStylePresetsLayerHint() {
    // Only run if style_presets onboarding is at generate_seen stage
    if (this.stylePresetsStatusValue !== "generate_seen") return
    if (!this.hasOriginalLayerTarget) return

    // Show popover on the stable original layer (it doesn't change during streaming)
    setTimeout(() => {
      this.showLayerTour(this.originalLayerTarget)
    }, 1500)
  }

  showLayerTour(element) {
    this.startTour([
      {
        element: element,
        popover: {
          title: "Layers Are Generating",
          description: "Your transformations will appear below this original layer. Click on any completed layer to view it and apply further edits."
        }
      }
    ], {
      onNextClick: () => {
        this.updateStatus("style_presets", "completed")
        this.driverObj.destroy()
      }
    })
  }

  handleSmartFixTour() {
    if (this.smartFixStatusValue === "completed") return

    const steps = [
      {
        element: this.smartFixTabTarget,
        popover: {
          title: "Smart Fix",
          description: "Use text prompts to make specific edits to your garden. Hadaa AI will interpret your instructions and apply changes."
        }
      }
    ]

    // AI Assist toggle popover
    if (this.hasAiAssistToggleTarget) {
      steps.push({
        element: this.aiAssistToggleTarget,
        popover: {
          title: "AI Assist Toggle",
          description: "Toggle AI Assist on for creative interpretations, or off for more precise, literal edits."
        }
      })
    }

    // Canvas masking popover
    const canvasWrap = document.getElementById('canvas-fixed-wrapper')
    if (canvasWrap) {
      steps.push({
        element: canvasWrap,
        popover: {
          title: "Paint Your Changes",
          description: "Brush on the image to specify exactly where you want the changes applied. Leave blank to apply to the whole image.",
          side: "left"
        }
      })
    }

    this.startTour(steps, {
      onNextClick: () => {
        const activeIndex = this.driverObj.getActiveIndex()
        const totalSteps = this.driverObj.getConfig().steps.length

        if (activeIndex === totalSteps - 1) {
          this.updateStatus("smart_fix", "completed")
          this.driverObj.destroy()
        } else {
          this.driverObj.moveNext()
        }
      }
    })
  }

  handleAutoFixTour() {
    if (this.autoFixStatusValue === "completed") return

    // Only show the "Generate Fixes" step if button exists
    if (this.hasRecommendFixesBtnTarget) {
      this.startTour([
        {
          element: this.recommendFixesBtnTarget,
          popover: {
            title: "AutoFix",
            description: "Click here to let AI analyze your yard and recommend potential improvements. Each fix can be applied with one click."
          }
        }
      ], {
        onNextClick: () => {
          this.updateStatus("auto_fix", "completed")
          this.driverObj.destroy()
        }
      })
    }
  }

  handleSmartFixWarning() {
    if (!this.hasAiAssistToggleTarget) return

    this.startTour([
      {
        element: this.aiAssistToggleTarget,
        popover: {
          title: "⚠️ Turn Off AI Assist",
          description: "You've used AI Assist many times. If you have very specific instructions, <b>turning this OFF</b> gives you much more precision by doing exactly what you want.",
          side: "bottom",
          align: "center"
        }
      }
    ], {
      onNextClick: () => this.confirmSmartFixWarning(),
      onCloseClick: () => this.confirmSmartFixWarning(),
      onDestroyed: () => {
         this.confirmSmartFixWarning()
      }
    })
  }

  confirmSmartFixWarning() {
      // If we have an active driver, destroy it to close the popover UI
      if (this.driverObj) {
        this.driverObj.destroy()
      }

      if (this.showSmartFixWarningValue === false) return
      this.showSmartFixWarningValue = false

      const formData = new FormData()
      formData.append(`project_onboarding[smart_fix_warning_seen]`, true)

      fetch("/project_onboarding/update", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: formData
      })
  }

  updateStatus(tool, status) {
    const formData = new FormData()
    formData.append(`project_onboarding[${tool}_status]`, status)

    fetch("/project_onboarding/update", {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: formData
    }).then(response => {
      if (response.ok) {
        // Update local value to trigger reactivity if needed
        this[`${this.camelize(tool)}StatusValue`] = status
      }
    })
  }

  camelize(str) {
    return str.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
  }
}
