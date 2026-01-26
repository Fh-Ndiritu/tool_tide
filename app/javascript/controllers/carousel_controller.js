import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    images: Array,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.currentIndex = 0
    this.element.classList.add("relative", "overflow-hidden")

    // Ensure initial state
    if (this.hasImagesValue && this.imagesValue.length > 0) {
      this.setupInitialImage()
      this.startTimer = setTimeout(() => {
        this.startCarousel()
      }, 5000)
    }
  }

  disconnect() {
    if (this.startTimer) clearTimeout(this.startTimer)
    this.stopCarousel()
  }

  setupInitialImage() {
    // Clear existing content
    this.element.innerHTML = ""

    // Create first image
    const img = this.createImageElement(this.imagesValue[0])
    img.classList.add("translate-x-0")
    this.element.appendChild(img)
    this.currentImage = img
  }

  createImageElement(src) {
    const img = document.createElement("img")
    img.src = src
    img.classList.add(
      "absolute", "inset-0", "w-full", "h-full", "object-cover",
      "transition-transform", "duration-500", "ease-in-out"
    )
    return img
  }

  startCarousel() {
    this.stopCarousel()
    this.timer = setInterval(() => {
      this.next()
    }, this.intervalValue)
  }

  stopCarousel() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  next() {
    const nextIndex = (this.currentIndex + 1) % this.imagesValue.length
    const nextSrc = this.imagesValue[nextIndex]

    // Create next image, positioned off-screen to the right
    const nextImage = this.createImageElement(nextSrc)
    nextImage.classList.add("translate-x-full")
    this.element.appendChild(nextImage)

    // Force reflow
    void nextImage.offsetHeight

    // Animate
    // Move current image to the left
    if (this.currentImage) {
      this.currentImage.classList.remove("translate-x-0")
      this.currentImage.classList.add("-translate-x-full")
    }

    // Move next image to center
    nextImage.classList.remove("translate-x-full")
    nextImage.classList.add("translate-x-0")

    // Cleanup old image after transition
    const oldImage = this.currentImage
    setTimeout(() => {
      if (oldImage && oldImage.parentNode === this.element) {
        this.element.removeChild(oldImage)
      }
    }, 600) // slightly longer than duration-500 to be safe

    // Update state
    this.currentIndex = nextIndex
    this.currentImage = nextImage
  }
}
