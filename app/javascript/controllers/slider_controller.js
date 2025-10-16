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

  // INFINITE SCROLL PROPERTIES
  loopBuffer = 3; // Number of items to clone at the start and end for the loop effect
  isLooping = false; // Flag to prevent re-entry during the scroll jump
  originalItemCount = 0;

  connect() {
    this.setupInfiniteScroll(); // NEW: Setup cloning and initial positioning
    this.updateVisibility();
    window.addEventListener('resize', this.updateVisibility.bind(this));
    window.addEventListener('resize', this.handleResize.bind(this)); // Use a dedicated resize handler

    this.startAutoplay();

    // Determine if drag should be enabled
    this.checkIfDragShouldBeEnabled();

    // Add event listeners for autoplay reset (user interaction)
    this.trackTarget.addEventListener('scroll', this.resetAutoplay.bind(this));
    this.trackTarget.addEventListener('scroll', this.checkLoopBoundary.bind(this)); // NEW: Check boundaries on scroll

    // Add drag event listeners conditionally based on enableDrag
    if (this.enableDrag) {
      this.addDragListeners();
    }
  }

  disconnect() {
    window.removeEventListener('resize', this.updateVisibility.bind(this));
    window.removeEventListener('resize', this.handleResize.bind(this));

    this.stopAutoplay();
    clearTimeout(this.resetTimeout);

    this.trackTarget.removeEventListener('scroll', this.resetAutoplay.bind(this));
    this.trackTarget.removeEventListener('scroll', this.checkLoopBoundary.bind(this));

    if (this.enableDrag) {
      this.removeDragListeners();
    }

    window.removeEventListener('mouseup', this.globalEndDrag.bind(this));
    window.removeEventListener('touchend', this.globalEndDrag.bind(this));
  }

  handleResize() {
    // Re-check drag status and reset infinite scroll structure on resize
    this.checkIfDragShouldBeEnabled();

    // To properly reset the loop, we need to strip and re-add clones.
    // For simplicity, we just reload the loop logic.
    this.removeLoopClones();
    this.setupInfiniteScroll();
  }

  // --- INFINITE SCROLL LOGIC ---

  setupInfiniteScroll() {
    const track = this.trackTarget;
    const items = Array.from(track.children);
    this.originalItemCount = items.length;

    // 1. Remove any existing clones (important for resize/reconnect)
    this.removeLoopClones();

    // 2. Clone the start and end for seamless looping
    const clonesEnd = items.slice(0, this.loopBuffer).map((item) => item.cloneNode(true));
    const clonesStart = items.slice(-this.loopBuffer).map((item) => item.cloneNode(true));

    // 3. Add 'is-clone' class for identification
    [...clonesStart, ...clonesEnd].forEach((clone) => clone.classList.add('is-clone', 'snap-start'));

    // 4. Prepend clones of the end items to the start
    clonesStart.reverse().forEach((clone) => track.prepend(clone));

    // 5. Append clones of the start items to the end
    clonesEnd.forEach((clone) => track.appendChild(clone));

    // 6. Set initial scroll position to skip the prepended clones
    const initialScrollPosition = this.getScrollAmount() * this.loopBuffer;
    track.scrollLeft = initialScrollPosition;
  }

  removeLoopClones() {
    Array.from(this.trackTarget.children)
      .filter((child) => child.classList.contains('is-clone'))
      .forEach((clone) => clone.remove());
  }

  checkLoopBoundary() {
    if (this.isLooping) return;

    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    const currentScrollLeft = track.scrollLeft;

    const totalWidth = scrollAmount * (this.originalItemCount + 2 * this.loopBuffer);
    const startOffset = scrollAmount * this.loopBuffer;
    const endOffset = totalWidth - scrollAmount * this.loopBuffer;

    if (currentScrollLeft <= 0.01) {
      // User scrolled past the start clones
      this.isLooping = true;
      // Jump to the equivalent position at the end of the real items
      track.scrollLeft = endOffset - track.clientWidth;
      this.isLooping = false;
    } else if (currentScrollLeft + track.clientWidth >= endOffset) {
      // User scrolled into the end clones
      this.isLooping = true;
      // Jump back to the equivalent position at the start of the real items
      track.scrollLeft = startOffset;
      this.isLooping = false;
    }
  }

  // --- EXISTING UTILITY METHODS (Modified for Infinite Scroll) ---

  startAutoplay() {
    this.stopAutoplay();
    this.autoplayInterval = setInterval(() => {
      if (!this.isDragging) {
        // Use the existing 'next' method which handles the loop boundary
        this.next(true);
      }
    }, 4000);
  }

  next(fromAutoplay = false) {
    if (!fromAutoplay) this.stopAutoplay();

    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();

    track.scrollBy({ left: scrollAmount, behavior: 'smooth' });

    // Handle loop boundary for buttons/user interaction (optional, checkLoopBoundary usually covers it)
    if (!fromAutoplay) this.resetAutoplay();
  }

  prev() {
    this.stopAutoplay();
    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    track.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
    this.resetAutoplay();
  }

  getScrollAmount() {
    const track = this.trackTarget;
    // Find the first ORIGINAL item, skipping prepended clones
    const firstItem = Array.from(track.children).find((child) => !child.classList.contains('is-clone'));

    if (!firstItem) return 0;

    const trackStyle = getComputedStyle(track);
    // Use parseFloat to handle values like '8px' or '1rem'
    const gap = parseFloat(trackStyle.gap || '0');

    const itemWidth = firstItem.offsetWidth;

    // The scroll amount is the width of one item plus the gap
    return itemWidth + gap;
  }

  // --- DRAG/TOUCH HANDLERS (Unchanged) ---

  checkIfDragShouldBeEnabled() {
    const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    const isMobileOrTabletScreen = window.matchMedia('(max-width: 1024px)').matches;
    const shouldEnable = hasTouch && isMobileOrTabletScreen;

    if (shouldEnable && !this.enableDrag) {
      this.enableDrag = true;
      this.addDragListeners();
    } else if (!shouldEnable && this.enableDrag) {
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
    window.addEventListener('mouseup', this.globalEndDrag.bind(this));
    window.addEventListener('touchend', this.globalEndDrag.bind(this));
  }

  removeDragListeners() {
    this.trackTarget.removeEventListener('mousedown', this.startDrag.bind(this));
    this.trackTarget.removeEventListener('mouseleave', this.endDrag.bind(this));
    this.trackTarget.removeEventListener('mouseup', this.endDrag.bind(this));
    this.trackTarget.removeEventListener('mousemove', this.drag.bind(this));

    this.trackTarget.removeEventListener('touchstart', this.startTouch.bind(this));
    this.trackTarget.removeEventListener('touchend', this.endDrag.bind(this));
    this.trackTarget.removeEventListener('touchmove', this.drag.bind(this));

    window.removeEventListener('mouseup', this.globalEndDrag.bind(this));
    window.removeEventListener('touchend', this.globalEndDrag.bind(this));
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

  startDrag(e) {
    if (!this.enableDrag) return;
    this.isDragging = true;
    this.trackTarget.style.cursor = 'grabbing';
    this.startX = (e.touches ? e.touches[0].pageX : e.pageX) - this.trackTarget.offsetLeft;
    this.scrollLeft = this.trackTarget.scrollLeft;
    this.stopAutoplay();
  }

  startTouch(e) {
    if (!this.enableDrag) return;
    this.startX = e.touches[0].pageX - this.trackTarget.offsetLeft;
    this.scrollLeft = this.trackTarget.scrollLeft;
    this.stopAutoplay();
  }

  endDrag() {
    if (!this.enableDrag) return;
    this.isDragging = false;
    this.trackTarget.style.cursor = 'grab';
    this.resetAutoplay();
  }

  globalEndDrag() {
    if (!this.enableDrag) return;
    if (this.isDragging) {
      this.endDrag();
    }
  }

  drag(e) {
    if (!this.enableDrag) return;

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
        return;
      }
    } else {
      if (!this.isDragging) return;
      e.preventDefault();
    }

    const walk = (currentX - this.startX) * 1.5;
    this.trackTarget.scrollLeft = this.scrollLeft - walk;
  }

  updateVisibility() {
    // This method remains as is.
  }
}
