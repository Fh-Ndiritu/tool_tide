import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form", "dropZone"]

  connect() {
    // Optional: Preload animations or verify dragging capabilities
  }

  triggerInput() {
    this.inputTarget.click()
  }

  handleDrop(event) {
    event.preventDefault()
    this.resetDragState()

    if (event.dataTransfer.files.length > 0) {
      this.inputTarget.files = event.dataTransfer.files
      this.handleFileSelect()
    }
  }

  handleDragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-primary", "bg-primary/5", "scale-[1.01]")
  }

  handleDragLeave(event) {
    event.preventDefault()
    this.resetDragState()
  }

  resetDragState() {
    this.dropZoneTarget.classList.remove("border-primary", "bg-primary/5", "scale-[1.01]")
  }

  handleFileSelect() {
    if (this.inputTarget.files.length > 0) {
      this.showLoadingState()
      // Submit the form
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit()
      }
    }
  }

  showLoadingState() {
    const content = this.dropZoneTarget.querySelector('.drop-zone-content')
    if (content) {
      content.innerHTML = `
        <div class="flex flex-col items-center animate-pulse">
          <div class="relative w-16 h-16 mb-4">
             <div class="absolute inset-0 border-4 border-primary/20 rounded-full"></div>
             <div class="absolute inset-0 border-4 border-primary rounded-full border-t-transparent animate-spin"></div>
          </div>
          <h3 class="text-xl font-bold text-white mb-1">Creating Project</h3>
          <p class="text-neutral-400">Uploading and initializing your workspace...</p>
        </div>
      `
    }
    // Disable interactions
    this.dropZoneTarget.style.pointerEvents = 'none'
  }
}
