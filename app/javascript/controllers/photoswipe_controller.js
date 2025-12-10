import { Controller } from "@hotwired/stimulus"
import PhotoSwipeLightbox from "photoswipe-lightbox"
import PhotoSwipe from "photoswipe"

export default class extends Controller {
  connect() {
    this.lightbox = new PhotoSwipeLightbox({
      gallery: this.element,
      children: 'a[data-pswp-src]',
      pswpModule: PhotoSwipe,
      padding: { top: 40, bottom: 40, left: 40, right: 40 }
    });
    this.lightbox.init();
  }

  disconnect() {
    if (this.lightbox) {
      this.lightbox.destroy();
      this.lightbox = null;
    }
  }
}
