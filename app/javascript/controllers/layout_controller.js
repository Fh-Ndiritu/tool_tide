import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebarLeft", "sidebarRight", "mainWrapper", "canvasWrapper"]
  static classes = ["overlay", "push", "dock"]

  connect() {
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
    this.handleResize() // Initial check
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
  }

  handleResize() {
    const width = window.innerWidth

    if (width >= 1280) {
        this.setMode("push")
    } else if (width >= 1024) {
        this.setMode("dock")
    } else {
        this.setMode("overlay")
    }
  }

  setMode(mode) {
    if (this.currentMode === mode) return
    this.currentMode = mode

    // Reset classes
    this.element.dataset.layoutMode = mode

    // Broadcast event for other controllers (like canvas) to react if needed
    this.dispatch("modeChanged", { detail: { mode } })

    this.updateSidebarState()
  }

  toggleLeft() {
    this.toggleSidebar(this.sidebarLeftTarget)
  }

  toggleRight() {
    this.toggleSidebar(this.sidebarRightTarget)
  }

  openLeft() {
    this.setSidebarState(this.sidebarLeftTarget, true)
  }

  closeLeft() {
    this.setSidebarState(this.sidebarLeftTarget, false)
  }

  openRight() {
    this.setSidebarState(this.sidebarRightTarget, true)
  }

  closeRight() {
    this.setSidebarState(this.sidebarRightTarget, false)
  }

  toggleSidebar(sidebar) {
    const isExpanded = sidebar.getAttribute("aria-expanded") === "true"
    this.setSidebarState(sidebar, !isExpanded)
  }

  setSidebarState(sidebar, expanded) {
      sidebar.setAttribute("aria-expanded", expanded)
      sidebar.dataset.state = expanded ? "expanded" : "collapsed"
  }

  updateSidebarState() {
     // Ensure sidebars correspond to defaults for the mode
     if (this.currentMode === "dock") {
         this.closeLeft()
         this.closeRight()
     } else if (this.currentMode === "push") {
         this.openLeft()
         this.openRight()
     } else {
         // Overlay default: closed
         this.closeLeft()
         this.closeRight()
     }
  }
  toggleFocus() {
    const isLeftOpen = this.sidebarLeftTarget.getAttribute("aria-expanded") === "true"
    const isRightOpen = this.sidebarRightTarget.getAttribute("aria-expanded") === "true"

    if (isLeftOpen || isRightOpen) {
      this.closeLeft()
      this.closeRight()
    } else {
      this.updateSidebarState()
    }
  }
}
