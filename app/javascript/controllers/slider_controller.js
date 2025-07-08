// app/javascript/controllers/slider_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['track'];

  autoplayInterval = null;
  resetTimeout = null;
  isDragging = false;
  startX = 0;
  scrollLeft = 0;
  touchMoveThreshold = 10; // Pixels to move before considering it a drag

  // Flag to enable/disable drag functionality
  enableDrag = false;

  connect() {
    this.updateVisibility();
    window.addEventListener('resize', this.updateVisibility.bind(this));

    this.startAutoplay();

    // Determine if drag should be enabled
    this.checkIfDragShouldBeEnabled();
    window.addEventListener('resize', this.checkIfDragShouldBeEnabled.bind(this)); // Re-check on resize

    // Add event listeners for autoplay reset (user interaction)
    this.trackTarget.addEventListener('scroll', this.resetAutoplay.bind(this));

    // Add drag event listeners conditionally based on enableDrag
    if (this.enableDrag) {
      this.addDragListeners();
    }
  }

  disconnect() {
    window.removeEventListener('resize', this.updateVisibility.bind(this));
    this.stopAutoplay();
    clearTimeout(this.resetTimeout);

    this.trackTarget.removeEventListener('scroll', this.resetAutoplay.bind(this));

    if (this.enableDrag) {
      this.removeDragListeners();
    }

    window.removeEventListener('resize', this.checkIfDragShouldBeEnabled.bind(this));
    window.removeEventListener('mouseup', this.globalEndDrag.bind(this));
    window.removeEventListener('touchend', this.globalEndDrag.bind(this));
  }

  checkIfDragShouldBeEnabled() {
    // Option 1: Feature Detection (touch support)
    const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

    // Option 2: Media Query (screen width often indicates mobile/tablet)
    // You can adjust these breakpoints to match your CSS breakpoints for mobile/tablet
    const isMobileOrTabletScreen = window.matchMedia('(max-width: 1024px)').matches; // Example: screens up to 1024px wide

    // Combine conditions: enable drag if it's a touch device AND within typical mobile/tablet screen size
    const shouldEnable = hasTouch && isMobileOrTabletScreen;

    if (shouldEnable && !this.enableDrag) {
      // If drag should be enabled and currently isn't, add listeners
      this.enableDrag = true;
      this.addDragListeners();
    } else if (!shouldEnable && this.enableDrag) {
      // If drag should be disabled and currently is, remove listeners
      this.enableDrag = false;
      this.removeDragListeners();
    }
  }

  addDragListeners() {
    // Desktop mouse events
    this.trackTarget.addEventListener('mousedown', this.startDrag.bind(this));
    this.trackTarget.addEventListener('mouseleave', this.endDrag.bind(this));
    this.trackTarget.addEventListener('mouseup', this.endDrag.bind(this));
    this.trackTarget.addEventListener('mousemove', this.drag.bind(this));

    // Mobile touch events
    this.trackTarget.addEventListener('touchstart', this.startTouch.bind(this), { passive: true });
    this.trackTarget.addEventListener('touchend', this.endDrag.bind(this), { passive: true });
    this.trackTarget.addEventListener('touchmove', this.drag.bind(this), { passive: false });

    // Global listeners for ending drag if mouse/touch goes off the element
    // These should always be on window if drag is enabled, regardless of where drag ends
    window.addEventListener('mouseup', this.globalEndDrag.bind(this));
    window.addEventListener('touchend', this.globalEndDrag.bind(this));
  }

  removeDragListeners() {
    this.trackTarget.removeEventListener('mousedown', this.startDrag.bind(this));
    this.trackTarget.removeEventListener('mouseleave', this.endDrag.bind(this));
    this.trackTarget.removeEventListener('mouseup', this.endDrag.bind(this));
    this.trackTarget.removeEventListener('mousemove', this.drag.bind(this));

    this.trackTarget.removeEventListener('touchstart', this.startTouch.bind(this), { passive: true });
    this.trackTarget.removeEventListener('touchend', this.endDrag.bind(this), { passive: true });
    this.trackTarget.removeEventListener('touchmove', this.drag.bind(this), { passive: false });

    window.removeEventListener('mouseup', this.globalEndDrag.bind(this));
    window.removeEventListener('touchend', this.globalEndDrag.bind(this));
  }

  startAutoplay() {
    this.stopAutoplay();
    this.autoplayInterval = setInterval(() => {
      if (!this.isDragging) {
        const track = this.trackTarget;
        const currentScrollLeft = track.scrollLeft;
        const scrollWidth = track.scrollWidth;
        const clientWidth = track.clientWidth;
        const scrollAmount = this.getScrollAmount();

        const atEnd = currentScrollLeft + clientWidth >= scrollWidth - 1;

        if (atEnd) {
          track.scrollTo({ left: 0, behavior: 'smooth' });
        } else {
          track.scrollBy({ left: scrollAmount, behavior: 'smooth' });
        }
      }
    }, 4000);
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
      if (!this.isDragging) {
        this.startAutoplay();
      }
    }, 3000);
  }

  // --- Drag/Touch Handlers ---

  startDrag(e) {
    if (!this.enableDrag) return; // Only proceed if drag is enabled

    this.isDragging = true;
    this.trackTarget.style.cursor = 'grabbing';
    this.startX = (e.touches ? e.touches[0].pageX : e.pageX) - this.trackTarget.offsetLeft;
    this.scrollLeft = this.trackTarget.scrollLeft;
    this.stopAutoplay();
  }

  startTouch(e) {
    if (!this.enableDrag) return; // Only proceed if drag is enabled

    this.startX = e.touches[0].pageX - this.trackTarget.offsetLeft;
    this.scrollLeft = this.trackTarget.scrollLeft;
    this.stopAutoplay();
  }

  endDrag() {
    if (!this.enableDrag) return; // Only proceed if drag is enabled

    this.isDragging = false;
    this.trackTarget.style.cursor = 'grab';
    this.resetAutoplay();
  }

  globalEndDrag() {
    if (!this.enableDrag) return; // Only proceed if drag is enabled
    if (this.isDragging) {
      this.endDrag();
    }
  }

  drag(e) {
    if (!this.enableDrag) return; // Only proceed if drag is enabled

    const currentX = (e.touches ? e.touches[0].pageX : e.pageX) - this.trackTarget.offsetLeft;
    const distanceX = Math.abs(currentX - this.startX);

    if (e.type === 'touchmove') {
      if (!this.isDragging && distanceX > this.touchMoveThreshold) {
        this.isDragging = true;
        this.trackTarget.style.cursor = 'grabbing';
      }
      if (this.isDragging) {
        e.preventDefault();
      } else {
        return; // Allow default scrolling if not dragging slider
      }
    } else {
      // For mouse events
      if (!this.isDragging) return;
      e.preventDefault();
    }

    const walk = (currentX - this.startX) * 1.5;
    this.trackTarget.scrollLeft = this.scrollLeft - walk;
  }

  // --- Navigation & Utility ---

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

    const itemWidth = firstItem.offsetWidth;

    return itemWidth + gap;
  }

  updateVisibility() {
    // This method remains as is.
  }
}
