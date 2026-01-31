import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="asset-clipboard"
// Usage: <div data-controller="asset-clipboard">
//          <button data-action="click->asset-clipboard#copy" data-asset-clipboard-text-param="Some text">Copy</button>
//        </div>
export default class extends Controller {
  static targets = ["source", "feedback"]
  static values = { successMessage: { type: String, default: "Copied!" } }

  async copy(event) {
    const text = event.params.text || this.sourceTarget?.textContent || ""
    const button = event.currentTarget

    try {
      await navigator.clipboard.writeText(text)
      this.showFeedback(button, true)
    } catch (err) {
      console.error("Failed to copy:", err)
      this.showFeedback(button, false)
    }
  }

  async copyFromElement(event) {
    const targetId = event.params.target
    const button = event.currentTarget
    const element = document.getElementById(targetId)
    if (!element) return

    const text = element.textContent || element.value || ""

    try {
      await navigator.clipboard.writeText(text)
      this.showFeedback(button, true)
    } catch (err) {
      console.error("Failed to copy:", err)
      this.showFeedback(button, false)
    }
  }

  showFeedback(button, success) {
    if (!button) return

    const originalText = button.textContent
    const originalClasses = button.className

    // Update state
    button.textContent = success ? this.successMessageValue : "Failed"

    // Add feedback classes
    if (success) {
      button.classList.add("text-green-400", "font-bold")
      button.classList.remove("text-purple-400", "text-gray-500")
    } else {
      button.classList.add("text-red-400")
    }

    setTimeout(() => {
      button.textContent = originalText
      button.className = originalClasses
    }, 2000)
  }
}
