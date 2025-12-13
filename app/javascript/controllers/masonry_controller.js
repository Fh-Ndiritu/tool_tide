import { Controller } from "@hotwired/stimulus"
import Masonry from "masonry-layout"
import imagesLoaded from "imagesloaded"

// Connects to data-controller="masonry"
export default class extends Controller {
  static values = {
    itemSelector: { type: String, default: ".masonry-item" },
    percentPosition: { type: Boolean, default: true }
  }

  connect() {
    this.layout()
  }

  layout() {
    this.masonry = new Masonry(this.element, {
      itemSelector: this.itemSelectorValue,
      percentPosition: this.percentPositionValue,
      horizontalOrder: true, // Keep L-R order roughly
      transitionDuration: 0 // Disable animation for faster feel
    })

    const imgLoad = imagesLoaded(this.element)
    imgLoad.on("progress", () => {
      this.masonry.layout()
    })
  }

  disconnect() {
    if (this.masonry) {
      this.masonry.destroy()
    }
  }
}
