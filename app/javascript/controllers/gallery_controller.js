import { Controller } from '@hotwired/stimulus';

export default class GalleryController extends Controller {
  static targets = [];
  static values = { images: Array };

  // --- Swiping properties ---
  swipeThreshold = 50; // Minimum horizontal distance (in pixels) for a swipe to register
  startX = 0;

  connect() {
    this.currentIndex = 0;

    // --- Access modal globally by ID ---
    this.modalContainer = document.getElementById('gallery-modal');

    // --- Find the necessary elements inside the modal once on connect ---
    if (this.modalContainer) {
      this.modalImageTarget = this.modalContainer.querySelector('[data-gallery-target="modalImage"]');
      this.modalTitleTarget = this.modalContainer.querySelector('[data-gallery-target="modalTitle"]');

      // --- Manual click handler setup (existing code) ---
      if (!this._boundHandleClicks) {
        this._boundHandleClicks = this.handleClicks.bind(this);
      }
      this.modalContainer.addEventListener('click', this._boundHandleClicks);

      // --- Swiping: Bind and attach touch listeners once on connect for the modal ---
      if (!this._boundTouchStart) {
        this._boundTouchStart = this.handleTouchStart.bind(this);
      }
      if (!this._boundTouchEnd) {
        this._boundTouchEnd = this.handleTouchEnd.bind(this);
      }
      // Attach listeners to the container that holds the image
      const imageContainer = this.modalContainer.querySelector('.relative.w-full.h-full');
      if (imageContainer) {
        imageContainer.addEventListener('touchstart', this._boundTouchStart, { passive: true });
        imageContainer.addEventListener('touchend', this._boundTouchEnd, { passive: true });
      }
    }

    console.log('🖼️ Gallery Controller connected.', {
      element: this.element,
      imagesCount: this.imagesValue.length,
    });

    if (!this.modalContainer) {
      console.error('❌ ERROR: Could not find modal element with ID "gallery-modal". The modal will not open.');
    } else if (!this.modalImageTarget || !this.modalTitleTarget) {
      console.error(
        '❌ ERROR: Could not find modalImage or modalTitle targets inside #gallery-modal. Check your _gallery_modal.html.erb partial.'
      );
    }
  }

  disconnect() {
    // Clean up the manually bound click listener
    if (this.modalContainer && this._boundHandleClicks) {
      this.modalContainer.removeEventListener('click', this._boundHandleClicks);
    }
    // Clean up the keydown listener if it's still active (should be removed in close, but safe to check)
    if (this._boundNavigate) {
      document.removeEventListener('keydown', this._boundNavigate);
    }
    // Clean up touch listeners
    const imageContainer = this.modalContainer?.querySelector('.relative.w-full.h-full');
    if (imageContainer) {
      imageContainer.removeEventListener('touchstart', this._boundTouchStart);
      imageContainer.removeEventListener('touchend', this._boundTouchEnd);
    }
  }

  // --- SWIPE LOGIC METHODS ---

  handleTouchStart(event) {
    // Capture the initial X position of the touch
    this.startX = event.touches[0].clientX;
    console.log('👆 Touch Start at:', this.startX);
  }

  handleTouchEnd(event) {
    if (this.startX === 0) return; // Prevent action if startX wasn't captured

    // Capture the final X position of the touch
    const endX = event.changedTouches[0].clientX;
    const diffX = this.startX - endX; // Positive diffX = swipe left (next), Negative diffX = swipe right (previous)

    console.log('🤚 Touch End at:', endX, 'Difference:', diffX);

    if (Math.abs(diffX) > this.swipeThreshold) {
      if (diffX > 0) {
        // Swipe Left (diffX is positive) -> Go to next image
        this.next();
      } else {
        // Swipe Right (diffX is negative) -> Go to previous image
        this.previous();
      }
    }

    // Reset startX for the next swipe
    this.startX = 0;
  }

  // --- End of SWIPE LOGIC METHODS ---

  // ... (rest of the controller methods remain the same) ...

  // --- NEW: Manual click handler for the external modal buttons ---
  // This method listens for clicks on the modal and executes the corresponding gallery#action
  handleClicks(event) {
    // Find the element with a data-action attribute that triggered the event (or its ancestor)
    let target = event.target.closest('[data-action]');

    if (target) {
      const action = target.getAttribute('data-action');
      if (action.startsWith('gallery#')) {
        event.preventDefault(); // Prevent default link/button action
        const methodName = action.split('#')[1];

        if (typeof this[methodName] === 'function') {
          this[methodName](); // Call the corresponding controller method (e.g., this.next())
        }
      }
    }
  }

  // Open the modal starting at the clicked image index
  open(event) {
    event.preventDefault();

    // Get the index passed from the clicked link (data-gallery-index-param)
    const clickedIndex = parseInt(event.params.index, 10);
    this.currentIndex = clickedIndex;

    console.log(`👉 Action: open. Starting gallery at index ${this.currentIndex}`);

    this.showModal();
  }

  // --- Handle keyboard navigation (Escape, Left Arrow, Right Arrow) ---
  navigate(event) {
    if (event.key === 'ArrowRight') {
      this.next();
    } else if (event.key === 'ArrowLeft') {
      this.previous();
    } else if (event.key === 'Escape') {
      this.close();
    }
  }

  // Closes the modal and re-enables scrolling
  close(event) {
    if (event) event.preventDefault();

    if (this.modalContainer) {
      this.modalContainer.classList.add('hidden');
      document.body.classList.remove('overflow-hidden');

      // FIX: Remove keydown listener on close
      document.removeEventListener('keydown', this._boundNavigate);

      console.log('❌ Action: close. Modal hidden.');
    } else {
      console.warn('❌ Action: close failed. Modal container not found.');
    }
  }

  // Moves to the next image in the set, looping at the end
  next() {
    this.currentIndex = (this.currentIndex + 1) % this.imagesValue.length;
    console.log(`➡️ Action: next. New index: ${this.currentIndex}`);
    this.updateModalContent();
  }

  // Moves to the previous image in the set, looping at the start
  previous() {
    this.currentIndex = (this.currentIndex - 1 + this.imagesValue.length) % this.imagesValue.length;
    console.log(`⬅️ Action: previous. New index: ${this.currentIndex}`);
    this.updateModalContent();
  }

  // Shows the modal, disables scrolling, and sets the content
  showModal() {
    if (this.modalContainer) {
      this.modalContainer.classList.remove('hidden');
      document.body.classList.add('overflow-hidden');

      // FIX: Add keydown listener on open
      if (!this._boundNavigate) {
        this._boundNavigate = this.navigate.bind(this);
      }
      document.addEventListener('keydown', this._boundNavigate);

      console.log(`✅ Action: showModal. Displaying image ${this.currentIndex}`);
      this.updateModalContent();
    } else {
      console.error('❌ Action: showModal failed. Modal container not found.');
    }
  }

  // Updates the modal's image source and title based on the current index
  updateModalContent() {
    const currentImage = this.imagesValue[this.currentIndex];

    if (!currentImage) {
      console.error(`🚨 ERROR: updateModalContent failed. Image data missing for index ${this.currentIndex}.`);
      return;
    }

    // Check for dynamically found targets
    if (this.modalImageTarget) {
      this.modalImageTarget.src = currentImage.url;
      // Truncating URL for cleaner console log
      console.log(`📷 Update: Image src set to ${currentImage.url.substring(0, 50)}...`);
    } else {
      console.warn('⚠️ Update: modalImage element not found. Cannot set source.');
    }

    if (this.modalTitleTarget) {
      this.modalTitleTarget.textContent = currentImage.title;
    }
  }
}
