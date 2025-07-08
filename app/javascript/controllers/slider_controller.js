// app/javascript/controllers/slider_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['track'];

  autoplayInterval = null;
  resetTimeout = null; // Declare resetTimeout property

  connect() {
    this.updateVisibility();
    window.addEventListener('resize', this.updateVisibility.bind(this));

    this.startAutoplay();

    // Add event listeners with explicit non-passive option for touchstart
    this.trackTarget.addEventListener('scroll', this.resetAutoplay.bind(this));
    // Making touchstart non-passive to ensure our event handling takes precedence
    this.trackTarget.addEventListener('touchstart', this.resetAutoplay.bind(this), { passive: false });
    this.trackTarget.addEventListener('mousedown', this.resetAutoplay.bind(this));
  }

  disconnect() {
    window.removeEventListener('resize', this.updateVisibility.bind(this));
    this.stopAutoplay();
    clearTimeout(this.resetTimeout); // Clear any pending reset on disconnect

    this.trackTarget.removeEventListener('scroll', this.resetAutoplay.bind(this));
    this.trackTarget.removeEventListener('touchstart', this.resetAutoplay.bind(this), { passive: false });
    this.trackTarget.removeEventListener('mousedown', this.resetAutoplay.bind(this));
  }

  startAutoplay() {
    this.stopAutoplay();
    this.autoplayInterval = setInterval(() => {
      const track = this.trackTarget;
      const currentScrollLeft = track.scrollLeft;
      const scrollWidth = track.scrollWidth;
      const clientWidth = track.clientWidth;
      const scrollAmount = this.getScrollAmount();

      // Check if we are at or very near the end
      // Use a small epsilon for floating point comparison robustness
      const atEnd = currentScrollLeft + clientWidth >= scrollWidth - 1; // -1 for a small buffer

      if (atEnd) {
        // Loop back to the beginning
        track.scrollTo({ left: 0, behavior: 'smooth' });
      } else {
        // Move to the next slide
        track.scrollBy({ left: scrollAmount, behavior: 'smooth' });
      }
    }, 4000); // 4000 milliseconds = 4 seconds
  }

  stopAutoplay() {
    if (this.autoplayInterval) {
      clearInterval(this.autoplayInterval);
      this.autoplayInterval = null;
    }
  }

  resetAutoplay() {
    this.stopAutoplay();
    clearTimeout(this.resetTimeout);
    this.resetTimeout = setTimeout(() => {
      this.startAutoplay();
    }, 3000);
  }

  prev() {
    this.stopAutoplay();
    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    track.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
    this.resetAutoplay();
  }

  next() {
    this.stopAutoplay();
    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    track.scrollBy({ left: scrollAmount, behavior: 'smooth' });
    this.resetAutoplay();
  }

  getScrollAmount() {
    const track = this.trackTarget;
    const firstItem = track.firstElementChild;

    if (!firstItem) return 0;

    const trackStyle = getComputedStyle(track);
    const gap = parseFloat(trackStyle.gap || '0');

    // Get the actual computed width of one item, including its padding/border, but not margin
    // offsetWidth is usually reliable for this
    const itemWidth = firstItem.offsetWidth;

    // Given 'snap-start' and 'w-full'/'w-1/3', each snap point corresponds to an item.
    // So, scrolling by the item's computed width plus any gap is appropriate.
    // On mobile (w-full), it will scroll one full card.
    // On desktop (w-1/3), it will scroll one third-width card.
    return itemWidth + gap;
  }

  updateVisibility() {
    // This method remains as is. It's for button visibility, not directly related to autoplay issue.
  }
}
