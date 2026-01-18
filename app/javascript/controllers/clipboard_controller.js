import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    content: String,
    successMessage: { type: String, default: "Copied to clipboard!" }
  }

  copy(event) {
    if (event) event.preventDefault()

    // Fallback if content value is missing, try to get it from text content of target or param
    const textToCopy = this.contentValue || event.params?.content

    if (!textToCopy) return

    navigator.clipboard.writeText(textToCopy).then(() => {
      this.originalContent = this.element.innerHTML
      this.element.innerHTML = `<span class="flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg> Copied!</span>`
      this.element.classList.add("text-green-400", "border-green-400")

      setTimeout(() => {
        this.element.innerHTML = this.originalContent
        this.element.classList.remove("text-green-400", "border-green-400")
      }, 2000)
    }).catch(err => {
      console.error('Failed to copy text: ', err)
    })
  }
}
