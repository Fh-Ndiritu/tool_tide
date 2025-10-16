import { Controller } from '@hotwired/stimulus';

// Removed: let globalModalInitialized = false;

export default class GalleryController extends Controller {
  // 1. Declare modalContainer as a static target
  // The modal element MUST be a child of this controller's scope and have data-gallery-target="modalContainer"
  static targets = ['modalContainer', 'modalImage', 'modalTitle'];
  static values = { images: Array };

  // --- Swiping properties (unchanged) ---
  swipeThreshold = 50;
  startX = 0;

  // Local references (no longer initialized globally)
  currentIndex = 0;

  connect() {
    this.currentIndex = 0;

    // Check if the modal structure is present within this controller's scope
    if (this.hasModalContainerTarget) {
      // 1. Set the local reference
      this.modalContainer = this.modalContainerTarget;

      // 2. We now use modalImageTarget and modalTitleTarget directly from Stimulus,
      // so no need to querySelector for them here!

      // --- Manual click handler setup ---
      if (!this._boundHandleClicks) {
        this._boundHandleClicks = this.handleClicks.bind(this);
      }
      this.modalContainer.addEventListener('click', this._boundHandleClicks);

      // --- Swiping: Attach listeners to the container that holds the image ---
      if (!this._boundTouchStart) {
        this._boundTouchStart = this.handleTouchStart.bind(this);
      }
      if (!this._boundTouchEnd) {
        this._boundTouchEnd = this.handleTouchEnd.bind(this);
      }

      // We attach listeners to the central image container for all swipes
      const imageContainer = this.modalContainer.querySelector('.relative.w-full.h-full');
      if (imageContainer) {
        imageContainer.addEventListener('touchstart', this._boundTouchStart, { passive: true });
        imageContainer.addEventListener('touchend', this._boundTouchEnd, { passive: true });
      }

      // Check if inner targets are present (though Stimulus usually handles this gracefully)
      if (!this.hasModalImageTarget || !this.hasModalTitleTarget) {
        console.warn(
          '⚠️ WARNING: Gallery controller found modal container but is missing inner modalImage or modalTitle targets.'
        );
      }
    } else {
      console.warn(
        '⚠️ WARNING: Gallery controller connected but modal target (modalContainer) not found in its scope.'
      );
    }

    console.log('🖼️ Gallery Controller connected.', {
      element: this.element,
      imagesCount: this.imagesValue.length,
    });
  }

  // Removed: initializeModal()

  disconnect() {
    // We only remove the instance-specific event listeners
    if (this.modalContainer && this._boundHandleClicks) {
      this.modalContainer.removeEventListener('click', this._boundHandleClicks);
    }
    // We do NOT remove the keydown listener here; it's managed by the modal state in close().

    // Clean up touch listeners
    const imageContainer = this.modalContainer?.querySelector('.relative.w-full.h-full');
    if (imageContainer) {
      imageContainer.removeEventListener('touchstart', this._boundTouchStart);
      imageContainer.removeEventListener('touchend', this._boundTouchEnd);
    }
    // Clean up keydown listener
    if (this._boundNavigate) {
      document.removeEventListener('keydown', this._boundNavigate);
    }
  }

  // --- SWIPE LOGIC METHODS (Unchanged) ---
  handleTouchStart(event) {
    this.startX = event.touches[0].clientX;
    console.log('👆 Touch Start at:', this.startX);
  }
  handleTouchEnd(event) {
    if (this.startX === 0) return;

    const endX = event.changedTouches[0].clientX;
    const diffX = this.startX - endX;

    console.log('🤚 Touch End at:', endX, 'Difference:', diffX);

    if (Math.abs(diffX) > this.swipeThreshold) {
      if (diffX > 0) {
        this.next();
      } else {
        this.previous();
      }
    }
    this.startX = 0;
  }

  // --- NEW: Manual click handler for the external modal buttons (Unchanged) ---
  handleClicks(event) {
    let target = event.target.closest('[data-action]');
    if (target) {
      const action = target.getAttribute('data-action');
      if (action.startsWith('gallery#')) {
        event.preventDefault();
        const methodName = action.split('#')[1];

        if (typeof this[methodName] === 'function') {
          this[methodName]();
        }
      }
    }
  }

  // Open the modal starting at the clicked image index
  open(event) {
    event.preventDefault();

    this.currentIndex = 0;

    console.log(
      `👉 Action: open. Starting gallery forced to index ${this.currentIndex}. Using data from current element.`
    );
    this.showModal();
  }

  // --- Handle keyboard navigation (Unchanged) ---
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
      document.removeEventListener('keydown', this._boundNavigate);

      console.log('❌ Action: close. Modal hidden.');
    } else {
      // Use standard Stimulus target check if modalContainer wasn't set locally
      if (this.hasModalContainerTarget) {
        this.modalContainerTarget.classList.add('hidden');
        document.body.classList.remove('overflow-hidden');
        document.removeEventListener('keydown', this._boundNavigate);
      } else {
        console.warn('❌ Action: close failed. Modal container not found in scope.');
      }
    }
  }

  // Moves to the next image in the set, looping at the end (Unchanged)
  next() {
    this.currentIndex = (this.currentIndex + 1) % this.imagesValue.length;
    console.log(`➡️ Action: next. New index: ${this.currentIndex}`);
    this.updateModalContent();
  }

  // Moves to the previous image in the set, looping at the start (Unchanged)
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

      if (!this._boundNavigate) {
        this._boundNavigate = this.navigate.bind(this);
      }
      document.addEventListener('keydown', this._boundNavigate);

      console.log(`✅ Action: showModal. Displaying image ${this.currentIndex}`);
      this.updateModalContent();
    } else {
      console.error('❌ Action: showModal failed. Modal container not found in scope.');
    }
  }

  // Updates the modal's image source and title based on the current index
  updateModalContent() {
    console.group(`🔄 Update Modal Content (Index: ${this.currentIndex})`);

    const currentImage = this.imagesValue[this.currentIndex];

    if (!currentImage) {
      console.error(`🚨 ERROR: updateModalContent failed. Image data missing for index ${this.currentIndex}.`);
      console.groupEnd();
      return;
    }

    // 💡 Using Stimulus targets directly now: this.modalImageTarget, this.modalTitleTarget

    // Check for image data and load
    if (this.hasModalImageTarget) {
      this.modalImageTarget.src = currentImage.url;

      console.log('Data Object:', currentImage);
      console.log(
        `📷 Target type: ${this.modalImageTarget.tagName}. Src set to: ${currentImage.url.substring(0, 50)}...`
      );

      this.modalImageTarget.onerror = () => {
        console.error(`🚨 IMAGE LOAD FAILED for URL: ${currentImage.url}`);
      };
    } else {
      console.warn('⚠️ Update: modalImage target not found in scope. Cannot set source.');
    }

    // Check for title data and load
    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = currentImage.title;
      console.log('Title set to:', currentImage.title);
    }

    console.groupEnd();
  }
}
