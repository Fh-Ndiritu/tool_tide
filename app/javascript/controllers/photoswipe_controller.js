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

    // Update dimensions from loaded images to fix aspect ratio issues
    // when backend metadata might be missing or default (1024x1024)
    this.element.querySelectorAll('a[data-pswp-src] > img').forEach(img => {
      if (img.complete) {
        this.updateDimensions(img);
      } else {
        img.onload = () => this.updateDimensions(img);
      }
    });

    this.lightbox.init();

    // Observe for new images added via Turbo/updates
    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) {
             const links = node.matches && node.matches('a[data-pswp-src]') ? [node] : node.querySelectorAll('a[data-pswp-src]');
             links.forEach(link => {
               const img = link.querySelector('img');
               if (img) {
                 if (img.complete) {
                   this.updateDimensions(img);
                 } else {
                   img.onload = () => this.updateDimensions(img);
                 }
               }
             });
          }
        });
      });
    });

    this.mutationObserver.observe(this.element, { childList: true, subtree: true });
  }

  updateDimensions(img) {
    const link = img.closest('a');
    if (link && img.naturalWidth > 0 && img.naturalHeight > 0) {
      link.dataset.pswpWidth = img.naturalWidth;
      link.dataset.pswpHeight = img.naturalHeight;
    }
  }

  disconnect() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
    }

    if (this.lightbox) {
      this.lightbox.destroy();
      this.lightbox = null;
    }
  }
}
