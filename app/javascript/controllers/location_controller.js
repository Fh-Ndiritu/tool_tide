import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

// Connects to data-controller="location"
export default class extends Controller {
  static targets = ["input"]
  static values = { enableUrl: String }

  connect() {
  }

  toggle() {
    if (this.inputTarget.checked) {
      this.getLocation()
    } else {
      this.clearLocation()
    }
  }

  async clearLocation() {
    try {
      const response = await patch(this.enableUrlValue, {
        body: JSON.stringify({
          user: {
            latitude: null,
            longitude: null
          }
        })
      })

      if (!response.ok) {
        console.error("Failed to clear location")
      }
    } catch (error) {
      console.error("Error clearing location:", error)
    }
  }

  getLocation() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        this.success.bind(this),
        this.error.bind(this)
      )
    } else {
      alert("Geolocation is not supported by this browser.")
      this.inputTarget.checked = false
    }
  }

  async success(position) {
    const latitude = position.coords.latitude
    const longitude = position.coords.longitude

    try {
      const response = await patch(this.enableUrlValue, {
        body: JSON.stringify({
          user: {
            latitude: latitude,
            longitude: longitude
          }
        })
      })

      if (!response.ok) {
        console.error("Failed to update location")
        this.inputTarget.checked = false
      }
    } catch (error) {
      console.error("Error updating location:", error)
      this.inputTarget.checked = false
    }
  }

  error(err) {
    console.warn(`ERROR(${err.code}): ${err.message}`)
    alert("Unable to retrieve your location.")
    this.inputTarget.checked = false
  }
}
