import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "source"]
  static values = {
    videos: Array
  }

  connect() {
    this.currentIndex = 0
    if (this.videosValue.length > 0) {
      this.playVideo(this.currentIndex)
    }
  }

  playVideo(index) {
    const videoSrc = this.videosValue[index]
    this.sourceTarget.src = videoSrc
    this.videoTarget.load()
    // Ensure muted is set for autoplay to work in most browsers
    this.videoTarget.muted = true
    this.videoTarget.play().catch(e => console.log("Autoplay prevented:", e))
  }

  onEnded() {
    this.currentIndex = (this.currentIndex + 1) % this.videosValue.length
    this.playVideo(this.currentIndex)
  }
}
