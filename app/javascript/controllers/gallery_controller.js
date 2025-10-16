import { Controller } from '@hotwired/stimulus';

// Use a static property to ensure the modal is initialized only once,
// regardless of how many GalleryController instances exist.
let globalModalInitialized = false;

export default class GalleryController extends Controller {
  // Remove staticTargets, as the modal will not be a child of this controller instance's element.
  static targets = [];
  // Keep imagesValue, as this is unique data for each gallery instance.
  static values = { images: Array };

  // --- Swiping properties (unchanged) ---
  swipeThreshold = 50;
  startX = 0;

  // Global references (shared or set dynamically)
  // These will be initialized in initializeModal
  modalContainer = null;
  modalImageTarget = null;
  modalTitleTarget = null;

  connect() {
    this.currentIndex = 0;

    // 1. Initialize the single, shared modal structure
    this.initializeModal();

    // 2. Attach listeners to the modal once it's available
    if (this.modalContainer) {
      // --- Manual click handler setup (Only bind once per controller instance) ---
      if (!this._boundHandleClicks) {
        this._boundHandleClicks = this.handleClicks.bind(this);
      }
      // Note: The click listener must remain attached to the modal, not the controller's element.
      this.modalContainer.addEventListener('click', this._boundHandleClicks);

      // --- Swiping: Attach listeners to the container that holds the image (Only bind once per controller instance) ---
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
    }

    console.log('🖼️ Gallery Controller connected.', {
      element: this.element,
      imagesCount: this.imagesValue.length,
    });
  }

  // Ensures global modal elements are found and stored only ONCE.
  initializeModal() {
    if (globalModalInitialized) {
      // If already initialized, just set local references
      const globalModal = document.getElementById('gallery-modal');
      if (globalModal) {
        this.modalContainer = globalModal;
        this.modalImageTarget = globalModal.querySelector('[data-gallery-target="modalImage"]');
        this.modalTitleTarget = globalModal.querySelector('[data-gallery-target="modalTitle"]');
      }
      return;
    }

    // First time initialization
    const modalElement = document.getElementById('gallery-modal');
    if (modalElement) {
      this.modalContainer = modalElement;
      this.modalImageTarget = modalElement.querySelector('[data-gallery-target="modalImage"]');
      this.modalTitleTarget = modalElement.querySelector('[data-gallery-target="modalTitle"]');

      // IMPORTANT: Mark as initialized so other controllers skip this heavy lookup.
      globalModalInitialized = true;
      console.log('⚙️ Single Modal Structure Initialized.');
    } else {
      console.error('❌ ERROR: Could not find single modal element with ID "gallery-modal".');
    }
  }

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

  // Closes the modal and re-enables scrolling (Unchanged)
  close(event) {
    if (event) event.preventDefault();

    if (this.modalContainer) {
      this.modalContainer.classList.add('hidden');
      document.body.classList.remove('overflow-hidden');
      document.removeEventListener('keydown', this._boundNavigate);

      console.log('❌ Action: close. Modal hidden.');
    } else {
      console.warn('❌ Action: close failed. Modal container not found.');
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

  // Shows the modal, disables scrolling, and sets the content (Unchanged)
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
      console.error('❌ Action: showModal failed. Modal container not found.');
    }
  }

  // Updates the modal's image source and title based on the current index
  updateModalContent() {
    console.group(`🔄 Update Modal Content (Index: ${this.currentIndex})`); // Grouping start

    const currentImage = this.imagesValue[this.currentIndex];

    if (!currentImage) {
      console.error(`🚨 ERROR: updateModalContent failed. Image data missing for index ${this.currentIndex}.`);
      console.groupEnd(); // Grouping end
      return;
    }

    // 💡 NEW DEBUG LOG: Check the entire object being processed
    console.log('Data Object:', currentImage);
    console.log('Image URL:', currentImage.url);

    if (this.modalImageTarget) {
      this.modalImageTarget.src = currentImage.url;
      // 💡 NEW DEBUG LOG: Confirm the target element type and src attribute
      console.log(
        `📷 Target type: ${this.modalImageTarget.tagName}. Src set to: ${currentImage.url.substring(0, 50)}...`
      );

      // If the URL is set but the image doesn't show, check the console for a network error (404/CORS)
      this.modalImageTarget.onerror = () => {
        console.error(`🚨 IMAGE LOAD FAILED for URL: ${currentImage.url}`);
      };
    } else {
      console.warn('⚠️ Update: modalImage element not found. Cannot set source.');
    }

    if (this.modalTitleTarget) {
      this.modalTitleTarget.textContent = currentImage.title;
      console.log('Title set to:', currentImage.title);
    }

    console.groupEnd(); // Grouping end
  }
}
