// app/javascript/controllers/slider_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['track'];

  // Add a property to store the interval ID
  autoplayInterval = null;

  connect() {
    this.updateVisibility(); // Initial visibility check (though for auto-play, buttons might always be desired)
    window.addEventListener('resize', this.updateVisibility.bind(this));

    // Start autoplay when the controller connects
    this.startAutoplay();

    // Add event listeners to stop autoplay on user interaction
    this.trackTarget.addEventListener('scroll', this.resetAutoplay.bind(this));
    this.trackTarget.addEventListener('touchstart', this.resetAutoplay.bind(this)); // For touch devices
    this.trackTarget.addEventListener('mousedown', this.resetAutoplay.bind(this)); // For desktop drag
  }

  disconnect() {
    window.removeEventListener('resize', this.updateVisibility.bind(this));
    this.stopAutoplay(); // Stop autoplay when the controller disconnects

    // Remove event listeners
    this.trackTarget.removeEventListener('scroll', this.resetAutoplay.bind(this));
    this.trackTarget.removeEventListener('touchstart', this.resetAutoplay.bind(this));
    this.trackTarget.removeEventListener('mousedown', this.resetAutoplay.bind(this));
  }

  // Starts the autoplay
  startAutoplay() {
    // Clear any existing interval to prevent duplicates
    this.stopAutoplay();
    this.autoplayInterval = setInterval(() => {
      this.next(); // Move to the next slide
      // If we reach the end, loop back to the beginning
      if (this.trackTarget.scrollLeft + this.trackTarget.clientWidth >= this.trackTarget.scrollWidth) {
        this.trackTarget.scrollTo({ left: 0, behavior: 'smooth' });
      }
    }, 2000); // 2000 milliseconds = 2 seconds
  }

  // Stops the autoplay
  stopAutoplay() {
    if (this.autoplayInterval) {
      clearInterval(this.autoplayInterval);
      this.autoplayInterval = null;
    }
  }

  // Resets the autoplay timer (stops it and restarts it after a brief delay)
  resetAutoplay() {
    this.stopAutoplay();
    // Give a brief delay before restarting, in case user is still interacting
    clearTimeout(this.resetTimeout); // Clear any pending reset
    this.resetTimeout = setTimeout(() => {
      this.startAutoplay();
    }, 3000); // Wait 3 seconds after interaction before restarting autoplay
  }

  // Moves the slider to the previous item
  prev() {
    this.stopAutoplay(); // Stop autoplay on manual navigation
    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    track.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
    this.resetAutoplay(); // Restart autoplay after movement
  }

  // Moves the slider to the next item
  next() {
    this.stopAutoplay(); // Stop autoplay on manual navigation
    const track = this.trackTarget;
    const scrollAmount = this.getScrollAmount();
    track.scrollBy({ left: scrollAmount, behavior: 'smooth' });
    this.resetAutoplay(); // Restart autoplay after movement
  }

  // Dynamically calculates scroll amount based on visible items and device
  getScrollAmount() {
    const track = this.trackTarget;
    const firstItem = track.firstElementChild;

    if (!firstItem) return 0;

    // Get the actual computed style of the track to determine gap
    const trackStyle = getComputedStyle(track);
    const gap = parseFloat(trackStyle.gap || '0'); // Get gap from track, default to 0 if not set

    // A more robust way to get item width, considering its own margins/paddings
    const itemWidth = firstItem.offsetWidth;

    // Check for responsive breakpoints (e.g., Tailwind's `lg:`)
    // You might want to get the actual `w-1/3` width based on the container
    // A simple approach is to always scroll by the width of the first item (card)
    // plus any gap that might be applied between cards.
    // This is generally more reliable as `firstItem.offsetWidth` accounts for
    // `w-full` on mobile and `w-1/3` (or similar) on larger screens.

    // If your items are truly snapping to the width of a single item regardless of screen size,
    // then scrolling by `itemWidth + gap` is often the most consistent.
    // However, if on larger screens, you want to scroll *exactly* 1/3 of the track,
    // then you'd use that logic. Given `snap-x snap-mandatory`, scrolling by the item width
    // is often sufficient as the browser will snap it correctly.

    // Let's refine based on the expected behavior with `w-full` and `w-1/3`.
    // On small screens, `firstItem.offsetWidth` will be effectively the track width.
    // On large screens, `firstItem.offsetWidth` will be 1/3 of the track width minus gap.

    // So, scrolling by `firstItem.offsetWidth` should generally work well.
    // The `gap` might be added if the track itself does not handle it implicitly
    // in `scrollBy` when snapping.

    // For `w-full` on mobile: `firstItem.offsetWidth` will be the full item width.
    // For `w-1/3` on large: `firstItem.offsetWidth` will be one third of the track width minus two gaps.
    // (e.g., track is `3*itemWidth + 2*gap`)
    // If you want to scroll by *one whole card* including the gap that follows it:
    return itemWidth + gap; // Scroll by the width of one card plus the gap after it.
  }

  // Hides/shows navigation buttons based on scroll position
  updateVisibility() {
    // This method is less critical with autoplay and snap behavior,
    // as buttons are often always visible.
    // If you want to hide/show buttons based on scroll position,
    // you would need to add refs for the buttons and manipulate their `hidden` attribute or `display` style.
    // Example (requires adding `static targets = ['track', 'prevButton', 'nextButton'];` and refs in HTML):
    /*
    const track = this.trackTarget;
    const scrollLeft = track.scrollLeft;
    const scrollWidth = track.scrollWidth;
    const clientWidth = track.clientWidth;

    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.style.display = scrollLeft === 0 ? 'none' : 'block';
    }
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.style.display = scrollLeft + clientWidth >= scrollWidth ? 'none' : 'block';
    }
    */
  }
}
