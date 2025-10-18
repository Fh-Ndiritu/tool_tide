import { Controller } from '@hotwired/stimulus';

export default class GalleryController extends Controller {
  static targets = ['modalContainer', 'modalImage', 'modalTitle'];
  static values = { images: Array };

  swipeThreshold = 50;
  startX = 0;

  currentIndex = 0;

  connect() {
    this.currentIndex = 0;

    if (this.hasModalContainerTarget) {
      this.modalContainer = this.modalContainerTarget;

      if (!this._boundHandleClicks) {
        this._boundHandleClicks = this.handleClicks.bind(this);
      }
      this.modalContainer.addEventListener('click', this._boundHandleClicks);

      if (!this._boundTouchStart) {
        this._boundTouchStart = this.handleTouchStart.bind(this);
      }
      if (!this._boundTouchEnd) {
        this._boundTouchEnd = this.handleTouchEnd.bind(this);
      }

      const imageContainer = this.modalContainer.querySelector('.relative.w-full.h-full');
      if (imageContainer) {
        imageContainer.addEventListener('touchstart', this._boundTouchStart, { passive: true });
        imageContainer.addEventListener('touchend', this._boundTouchEnd, { passive: true });
      }
    }
  }

  disconnect() {
    if (this.modalContainer && this._boundHandleClicks) {
      this.modalContainer.removeEventListener('click', this._boundHandleClicks);
    }

    const imageContainer = this.modalContainer?.querySelector('.relative.w-full.h-full');
    if (imageContainer) {
      imageContainer.removeEventListener('touchstart', this._boundTouchStart);
      imageContainer.removeEventListener('touchend', this._boundTouchEnd);
    }

    if (this._boundNavigate) {
      document.removeEventListener('keydown', this._boundNavigate);
    }
  }

  handleTouchStart(event) {
    this.startX = event.touches[0].clientX;
  }

  handleTouchEnd(event) {
    if (this.startX === 0) return;

    const endX = event.changedTouches[0].clientX;
    const diffX = this.startX - endX;

    if (Math.abs(diffX) > this.swipeThreshold) {
      if (diffX > 0) {
        this.next();
      } else {
        this.previous();
      }
    }
    this.startX = 0;
  }

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

  open(event) {
    event.preventDefault();
    this.currentIndex = 0;
    this.showModal();
  }

  navigate(event) {
    if (event.key === 'ArrowRight') {
      this.next();
    } else if (event.key === 'ArrowLeft') {
      this.previous();
    } else if (event.key === 'Escape') {
      this.close();
    }
  }

  close(event) {
    if (event) event.preventDefault();

    const modal = this.hasModalContainerTarget ? this.modalContainerTarget : this.modalContainer;

    if (modal) {
      modal.classList.add('hidden');
      document.body.classList.remove('overflow-hidden');
      document.removeEventListener('keydown', this._boundNavigate);
    }
  }

  next() {
    this.currentIndex = (this.currentIndex + 1) % this.imagesValue.length;
    this.updateModalContent();
  }

  previous() {
    this.currentIndex = (this.currentIndex - 1 + this.imagesValue.length) % this.imagesValue.length;
    this.updateModalContent();
  }

  showModal() {
    if (this.modalContainer) {
      this.modalContainer.classList.remove('hidden');
      document.body.classList.add('overflow-hidden');

      if (!this._boundNavigate) {
        this._boundNavigate = this.navigate.bind(this);
      }
      document.addEventListener('keydown', this._boundNavigate);

      this.updateModalContent();
    }
  }

  updateModalContent() {
    const currentImage = this.imagesValue[this.currentIndex];

    if (!currentImage) return;

    if (this.hasModalImageTarget) {
      this.modalImageTarget.src = currentImage.url;
    }

    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = currentImage.title;
    }
  }
}
