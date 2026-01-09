import { Controller } from "@hotwired/stimulus"
import { driver } from "driver.js"
import confetti from "canvas-confetti"

export default class extends Controller {
  static targets = [
    "modal", "upload", "brush", "canvas", "submit", "plantsButton",
    "textEdit", "prompt", "generate", "history", "control"
  ]

  static values = {
    stage: String,
    completeRequestCount: Number,
    currentRequestProgress: String
  }

  connect() {
    console.log("Onboarding Controller Connected")
    document.body.dataset.onboardingConnected = "true"

    this.onTurboLoad = this.handleStage.bind(this)
    window.addEventListener("turbo:load", this.onTurboLoad)

    this.handleStage()
    this.checkCelebrate()
  }

  disconnect() {
    window.removeEventListener("turbo:load", this.onTurboLoad)
    if (this.driverObj) this.driverObj.destroy()
    if (this.historyObserver) this.historyObserver.disconnect()
    this.historyTourStarted = false
    this.generationTourStarted = false
    this.enableControls()
  }

  stageValueChanged() {
    this.handleStage()
  }

  handleStage() {
    const stage = this.stageValue
    console.log("Current Stage:", stage)

    // Stop tooltips if we are in the sketch pipeline
    // http://localhost:3000/canvas/20/mask_requests/new?sketch_detected=true
    if (window.location.pathname.includes("/sketch_requests/") || window.location.search.includes("sketch_detected")) {
      return
    }

    switch (stage) {
      case "fresh":
        this.showWelcomeModal()
        break
      case "welcome_seen":
        this.startUploadTour()
        break
      case "image_uploaded":
        this.startBrushTour()
        break
      case "mask_drawn":
        break
      case "style_selected":
        this.startPlantsTour()
        break
      case "plants_viewed":
        if (this.hasPlantsButtonTarget || document.querySelector('[data-onboarding-target="nextButton"]')) {
           this.startPlantsTour()
           // If suggestions are already visible, showNextButtonStep will be triggered by the observer or we can trigger it directly
           const suggestionsSection = document.querySelector('[data-mask-request-target="suggestionsSection"]')
           if (suggestionsSection && !suggestionsSection.classList.contains('hidden')) {
              this.showNextButtonStep()
           }
        } else {
           this.startTextEditTour()
        }
        break
      case "first_result_viewed":
        this.startTextEditTour()
        break
      case "text_editor_opened":
        this.startGenerationTour()
        break
      case "refinement_generated":
        this.startHistoryTour()
        break
    }
  }

  showWelcomeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      // Delay celebration slightly for better visual impact as modal pops in
      setTimeout(() => this.celebrate(), 300)
    }
  }

  checkCelebrate() {
    // We can keep this if we want to force it via URL,
    // but the 'fresh' stage case above should handle typical flow.
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.get('celebrate') === 'true') {
      this.showWelcomeModal()
      const newUrl = window.location.pathname + window.location.search.replace(/[?&]celebrate=true/, '').replace(/^&/, '?')
      window.history.replaceState({}, document.title, newUrl)
    }
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.updateStage("welcome_seen")
    }
  }

  startTour(steps, options = {}) {
    if (this.driverObj) {
      this.driverObj.destroy()
    }

    try {
      const defaultOptions = {
        showProgress: false,
        animate: true,
        allowClose: false,
        steps: steps
      }

      this.driverObj = driver({ ...defaultOptions, ...options })
      this.driverObj.drive()
    } catch (e) {
      console.error("Driver.js init error:", e)
    }
  }

  startUploadTour() {
    if (!this.hasUploadTarget) return

    this.startTour([
      {
        element: this.uploadTarget,
        popover: {
          title: "Upload Your Photo",
          description: "Start by uploading a real photo of your garden or outdoor space."
        }
      }
    ])
    this.pulseElement(this.uploadTarget)
  }

  startBrushTour() {
    if (!this.hasBrushTarget || !this.hasCanvasTarget || !this.hasSubmitTarget) return

    this.disableControls()

    const steps = [
      {
        element: this.brushTarget,
        popover: {
          title: "Select the Brush",
          description: "Choose the brush tool to start editing."
        }
      },
      {
        element: this.canvasTarget,
        popover: {
          title: "Paint Areas",
          description: "Paint over the areas you want to modify (e.g., grass, fence)."
        }
      },
      {
        element: this.submitTarget,
        popover: {
          title: "Create Design",
          description: "When you're done, click here to generate your design."
        }
      }
    ]

    this.startTour(steps, {
      onHighlightStarted: (element) => {
        if (element) {
           this.pulseElement(element)
        }
      },
      onDestroyed: () => {
        this.enableControls()
        this.clearPulses()
      }
    })

    // Pulse the first element immediately
    this.pulseElement(this.brushTarget)
  }

  startPlantsTour() {
    if (!this.hasPlantsButtonTarget) return

    const suggestionsSection = document.querySelector('[data-mask-request-target="suggestionsSection"]')
    const suggestionsVisible = suggestionsSection && !suggestionsSection.classList.contains('hidden')

    if (suggestionsVisible) {
      this.showNextButtonStep()
    } else {
      this.startTour([
        {
          element: this.plantsButtonTarget,
          popover: {
            title: "Get Plant Suggestions",
            description: "Get AI-powered plant recommendations based on your location."
          }
        }
      ])
      this.pulseElement(this.plantsButtonTarget)

      // Listen for the plants being loaded
      if (suggestionsSection) {
        const observer = new MutationObserver((mutations) => {
          mutations.forEach((mutation) => {
            if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
              if (!suggestionsSection.classList.contains('hidden')) {
                this.showNextButtonStep()
                observer.disconnect()
              }
            }
          })
        })
        observer.observe(suggestionsSection, { attributes: true })
      }
    }
  }

  showNextButtonStep() {
    const checkLoader = () => {
      const loader = document.querySelector('[data-loader-target="loader"]')
      // If loader exists and does NOT have 'hidden' class, it's visible.
      // Wait for it to be hidden.
      if (loader && !loader.classList.contains('hidden')) {
        setTimeout(checkLoader, 500)
        return
      }

      // Loader is hidden (or doesn't exist), proceed.
      const nextBtn = document.querySelector('[data-onboarding-target="nextButton"]:not([disabled])')
      if (nextBtn) {
        this.startTour([
          {
            element: nextBtn,
            popover: {
              title: "Next Step",
              description: "Great! Now that you have your suggestions, click Next to proceed."
            }
          }
        ])
        this.pulseElement(nextBtn)
      }
    }

    checkLoader()
  }

  startTextEditTour() {
   return
    // Relaxed check: As long as we have the target (Smart Fix button), we can show the tour.
    // This supports the new streaming flow where 'complete' might not be the exact status yet,
    // but the button is visible.
    // if (this.currentRequestProgressValue !== 'uploading' && this.currentRequestProgressValue !== 'complete') return

    const steps = [
      {
        element: this.textEditTarget,
        popover: {
          title: "Refine with AI",
          description: "Use the AI Editor to make specific changes with text prompts."
        }
      }
    ]



    if (document.querySelector('[data-onboarding-target="download"]')) {
      steps.push({
        element: '[data-onboarding-target="download"]',
        popover: {
          title: "Download",
          description: "Download your high-resolution design."
        }
      })
    }

    if (document.querySelector('[data-onboarding-target="brushEdit"]')) {
      steps.push({
        element: '[data-onboarding-target="brushEdit"]',
        popover: {
          title: "Brush Edit",
          description: "Edit your mask again to change the area being redesigned."
        }
      })
    }

    if (document.querySelector('[data-onboarding-target="newDesign"]')) {
      steps.push({
        element: '[data-onboarding-target="newDesign"]',
        popover: {
          title: "New Design",
          description: "Start over completely with a new photo and design."
        }
      })
    }

    if (document.querySelector('[data-onboarding-target="changeStyle"]')) {
      steps.push({
        element: '[data-onboarding-target="changeStyle"]',
        popover: {
          title: "Change Style",
          description: "Keep your current mask but try a different style."
        }
      })
    }

    // Add final step pointing back to the main call to action
    steps.push({
      element: this.textEditTarget,
      popover: {
        title: "Try the AI Editor",
        description: "Click here to finish the tour and start refining your design."
      }
    })

    // Delay to allow layout to settle
    setTimeout(() => {
      this.startTour(steps)
      this.pulseElement(this.textEditTarget)
    }, 1500)
  }

  startGenerationTour() {
    // Check if loader is visible - if so, we are generating, so don't show the tour
    const loader = document.querySelector('[data-loader-target="loader"]')
    if (loader && !loader.classList.contains('hidden')) return

    // Guard against double execution
    if (this.generationTourStarted) return

    // Only show if uploading (fresh request)
    if (this.currentRequestProgressValue !== 'uploading') return

    // Use querySelector for robustness
    const promptEl = document.querySelector('[data-onboarding-target="prompt"]')
    const generateEl = document.querySelector('[data-onboarding-target="generate"]')

    if (!promptEl || !generateEl) return

    this.generationTourStarted = true

    // Delay to allow layout to settle
    setTimeout(() => {
      this.startTour([
        {
          element: promptEl,
          popover: {
            title: "Describe Changes",
            description: "Type what you want to change, or select a quick prompt below."
          }
        },
        {
          element: generateEl,
          popover: {
            title: "Generate",
            description: "Click to see your new design. Costs 8 credits."
          }
        }
      ])
    }, 1500)
  }

  startHistoryTour() {
    // Check for visible history target (mobile or desktop)
    // We use offsetParent to check for visibility (it's null if display: none)
    const historyContainer = this.historyTargets.find(el => el.offsetParent !== null)

    if (!historyContainer) return

    // Only show if exactly 1 complete request
    if (this.completeRequestCountValue !== 1) return

    // Guard against double execution
    if (this.historyTourStarted) return
    this.historyTourStarted = true

    // Function to run the tour on a specific element
    const runTourOnItem = (item) => {
      // Try to find the image inside the item, otherwise use the item itself
      const target = item.querySelector('img') || item

      const showTour = () => {
         this.startTour([
          {
            element: target,
            popover: {
              title: "History & Versions",
              description: "Click this image to fork and create a new version without losing this one."
            }
          }
        ], {
          onDestroyed: () => {
            this.updateStage("completed")
            this.celebrate()
          }
        })
        this.pulseElement(target)
      }

      // If target is an image, ensure it's loaded to prevent misplacement
      if (target.tagName === 'IMG' && !target.complete) {
        target.onload = () => {
           // Delay to allow layout to settle after image load
           setTimeout(showTour, 1500)
        }
      } else {
         // Delay to allow layout to settle (especially for mobile slide-ins)
         setTimeout(showTour, 1500)
      }
    }

    // 1. Check for EXISTING items (Page Reload / Turbo Render)
    // We look for the first child that is an element
    const existingItems = Array.from(historyContainer.children).filter(node => node.nodeType === 1)
    if (existingItems.length > 0) {
      // If we have items, show the tour on the first one immediately
      runTourOnItem(existingItems[0])
      // We don't need to observe if we already found an item, unless we expect DYNAMIC additions
      // that should OVERRIDE the current tour?
      // Usually, if we are in this stage, we just want to show it once.
      return
    }

    // 2. Setup Observer for NEW items (Live flow)
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
          const newItem = mutation.addedNodes[0]
          if (newItem.nodeType === 1) { // Ensure it's an element
             observer.disconnect() // Stop observing once we found our new item
             runTourOnItem(newItem)
          }
        }
      })
    })

    observer.observe(historyContainer, { childList: true, subtree: false }) // subtree false to only catch direct children (requests)

    // Store observer to disconnect later if needed
    this.historyObserver = observer
  }

  updateStage(stage) {
    this.stageValue = stage
    fetch("/onboarding/update", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ stage: stage })
    })
  }

  pulseElement(element) {
    this.clearPulses()
    if (element) {
      element.classList.add("ring-pulse")
    }
  }

  clearPulses() {
    document.querySelectorAll(".ring-pulse").forEach(el => el.classList.remove("ring-pulse"))
  }

  disableControls() {
    this.controlTargets.forEach(el => {
      el.classList.add("opacity-50", "pointer-events-none")
      if (el.tagName === 'BUTTON' || el.tagName === 'A') {
         el.setAttribute('disabled', 'true')
      }
    })
  }

  enableControls() {
    this.controlTargets.forEach(el => {
      el.classList.remove("opacity-50", "pointer-events-none")
      if (el.tagName === 'BUTTON' || el.tagName === 'A') {
         el.removeAttribute('disabled')
      }
    })
  }

  celebrate() {
    const count = 200
    const defaults = {
      origin: { y: 0.7 },
      zIndex: 1000
    }

    function fire(particleRatio, opts) {
      confetti({
        ...defaults,
        ...opts,
        particleCount: Math.floor(count * particleRatio)
      })
    }

    fire(0.25, {
      spread: 26,
      startVelocity: 55,
    })
    fire(0.2, {
      spread: 60,
    })
    fire(0.35, {
      spread: 100,
      decay: 0.91,
      scalar: 0.8
    })
    fire(0.1, {
      spread: 120,
      startVelocity: 25,
      decay: 0.92,
      scalar: 1.2
    })
    fire(0.1, {
      spread: 120,
      startVelocity: 45,
    })
  }
}
