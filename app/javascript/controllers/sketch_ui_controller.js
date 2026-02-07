import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["descriptionInput", "typeInput", "startButton", "logs"]

  connect() {
    console.log("Sketch UI Connected")
  }

  start(event) {
    event.preventDefault()

    const description = this.descriptionInputTarget.value
    const transformationType = this.typeInputTarget.value

    // Description is optional - no validation needed

    this.startButtonTarget.disabled = true
    this.startButtonTarget.innerHTML = `
      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
      </svg>
      Transforming...
    `

    this.appendLog("Starting Sketch Transformation...")
    if (description) {
      this.appendLog(`Description: ${description}`)
    }
    this.appendLog(`Type: ${transformationType}`)

    const projectId = window.location.pathname.split("/")[2]

    fetch(`/projects/${projectId}/start_sketch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({
        goal: description, // Keep as 'goal' for backend compatibility
        transformation_type: transformationType
      })
    })
    .then(response => {
       if (response.ok) {
         this.appendLog("Transformation started. Processing...")
       } else {
         this.appendLog("Error starting transformation.")
         this.resetButton()
       }
    })
    .catch(err => {
      this.appendLog(`System Error: ${err.message}`)
      this.resetButton()
    })
  }

  appendLog(message) {
    const div = document.createElement("div")
    div.className = "text-cyan-400"
    div.innerText = `[${new Date().toLocaleTimeString()}] ${message}`
    this.logsTarget.appendChild(div)
    this.logsTarget.scrollTop = this.logsTarget.scrollHeight
  }

  resetButton() {
    this.startButtonTarget.disabled = false
    this.startButtonTarget.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5 group-hover:scale-110 transition-transform">
         <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
      Transform Sketch
    `
  }
}
