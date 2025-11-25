import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="mask-request"
export default class extends Controller {
  static targets = [
    'editorSection',
    'loadingSection',
    'resultSection',
    'konvaCanvasWrapper',
    'originalResultImage',
    'modifiedResultImage1',
    'modifiedResultImage2',
    'modifiedResultImage3',
    'downloadButton',
    'selectPreset',
    'brushSizeControl',
    'brushSizeDisplay',
    'undoButton',
    'redoButton',
    'form',
    'mask',
    'modifiedImageUrlInput',
    'landscapeIdInput', // Hidden input to pass landscape ID back to Rails
    'progressBarContainer',
    'progressBar',
    'latitudeInput',
    'longitudeInput',
    'locationBtn',
    'profileBtn',
    'processingMessage',
    'submit',
    'brushRange',
    'thumb',
    'fill',
    'display',
    'suggestionsSection',
  ];

  static values = {
    imageUrl: String,
    displayImageWidth: Number,
    displayImageHeight: Number,
    modifiedImageUrl: String,
  };

  MAX_CANVAS_DISPLAY_WIDTH = 500;
  MAX_CANVAS_DISPLAY_HEIGHT = 500;

  connect() {
    this.setBrushSize(60);

    // Listen for custom events from the konva-canvas controller
    if (this.hasKonvaCanvasWrapperTarget) {
      this.konvaCanvasWrapperTarget.addEventListener(
        'konva:mask-history-changed',
        this._handleKonvaHistoryChange.bind(this)
      );
    }
    this.updateUndoRedoButtonStates(); // Initial state for buttons

    // --- REVISED LOGIC FOR CONNECT METHOD ---
    const ImageExists = this.ImageUrlValue && this.ImageUrlValue.length > 0;

    if (ImageExists) {
      console.log('Original image URL found, initializing editor.');
      // this.initializeEditorWithImage(this.ImageUrlValue, this.displayImageWidthValue, this.displayImageHeightValue);
      this.initializeEditorWithImage(this.ImageUrlValue, 500, 500);
    }
    {
      console.error('Editor Controller connected without image data or a landscape ID.');
    }
  }

  async initializeEditorWithImage(imageUrl, displayWidth, displayHeight) {
    setTimeout(() => {
      const konvaController = this.application.getControllerForElementAndIdentifier(
        this.konvaCanvasWrapperTarget,
        'konva-canvas'
      );

      if (konvaController) {
        const editorSectionActualWidth = this.editorSectionTarget.offsetWidth;
        let maxAllowableCanvasWidth = this.MAX_CANVAS_DISPLAY_WIDTH;

        if (editorSectionActualWidth < this.MAX_CANVAS_DISPLAY_WIDTH) {
          maxAllowableCanvasWidth = editorSectionActualWidth * 0.96;
        }

        let finalDisplayWidth = displayWidth;
        let finalDisplayHeight = displayHeight;

        if (finalDisplayWidth > maxAllowableCanvasWidth) {
          const aspectRatio = finalDisplayWidth / finalDisplayHeight;
          finalDisplayWidth = maxAllowableCanvasWidth;
          finalDisplayHeight = finalDisplayWidth / aspectRatio;
        }
        finalDisplayHeight = Math.round(finalDisplayHeight);
        finalDisplayWidth = Math.round(finalDisplayWidth);

        console.log('Calculated final display dimensions for Konva:', finalDisplayWidth, finalDisplayHeight);

        konvaController.displayWidthValue = finalDisplayWidth;
        konvaController.displayHeightValue = finalDisplayHeight;
        konvaController.imageUrlValue = imageUrl;
        konvaController.brushSizeValue = parseInt(this.brushSizeControlTarget.querySelector('#brush-size').value, 10);
      } else {
        console.error('Konva Canvas Controller not found on konvaCanvasWrapperTarget.');
        this.showMessage('Error initializing editor. Please ensure Konva Canvas is correctly set up.');
        this.returnToNewDesign(1000);
      }
    }, 1000);
  }

  _handleKonvaHistoryChange(event) {
    const { historyPointer, historyLength } = event.detail;
    this.updateUndoRedoButtonStates(historyPointer, historyLength);
  }

  undoPaintAction() {
    console.log('Attempting to undo paint action...');
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );

    if (konvaController) {
      console.log('Found konva-canvas controller:', konvaController);
      konvaController.undo();
    } else {
      console.error('ERROR: konva-canvas controller NOT found for konvaCanvasWrapperTarget!');
      this.showMessage('No active drawing tool or actions to undo.');
    }
  }

  redoPaintAction() {
    console.log('Attempting to redo paint action...');
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );

    if (konvaController) {
      console.log('Found konva-canvas controller:', konvaController);
      konvaController.redo();
    } else {
      console.error('ERROR: konva-canvas controller NOT found for konvaCanvasWrapperTarget!');
      this.showMessage('No active drawing tool or actions to redo.');
    }
  }

  updateUndoRedoButtonStates(historyPointer = -1, historyLength = 0) {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      historyPointer = konvaController.historyPointer;
      historyLength = konvaController.maskHistory.length;
    }

    if (this.hasUndoButtonTarget) {
      this.undoButtonTarget.disabled = historyPointer <= 0;
      this.undoButtonTarget.classList.toggle('opacity-50', historyPointer <= 0);
      this.undoButtonTarget.classList.toggle('cursor-not-allowed', historyPointer <= 0);
    }
    if (this.hasRedoButtonTarget) {
      this.redoButtonTarget.disabled = historyPointer >= historyLength - 1;
      this.redoButtonTarget.classList.toggle('opacity-50', historyPointer >= historyLength - 1);
      this.redoButtonTarget.classList.toggle('cursor-not-allowed', historyPointer >= historyLength - 1);
    }
  }

  selectBrushTool() {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      konvaController.setTool({ params: { tool: 'brush' } });
      this.brushSizeControlTarget.classList.remove('hidden');
      console.log('Selected: Brush Tool');
    }
  }

  updateBrushSize(event) {
    const size = parseInt(event.target.value, 10);
    this.setBrushSize(size);
  }

  setBrushSize(size) {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );

    if (konvaController) {
      konvaController.brushSizeValue = size;
    }

    const min = parseInt(this.brushRangeTarget.min, 10);
    const max = parseInt(this.brushRangeTarget.max, 10);

    const fillPercentage = (size - min) / (max - min);
    const thumbSize = 10 + ((size - min) / (max - min)) * 15;
    const fillWidth = `${fillPercentage * 100}%`;
    const thumbLeft = `calc(${fillPercentage * 100}% + (${15 - 5}px) * ${fillPercentage} - 5px)`;

    this.fillTarget.style.width = fillWidth;
    this.thumbTarget.style.left = thumbLeft;
    this.thumbTarget.style.setProperty('--thumb-size', `${thumbSize}px`);

    this.brushSizeDisplayTarget.textContent = `${size}px`;
  }

  clearSelection() {
    this.showConfirmation('Are you sure you want to clear all selections?', () => {
      const konvaController = this.application.getControllerForElementAndIdentifier(
        this.konvaCanvasWrapperTarget,
        'konva-canvas'
      );
      if (konvaController) {
        konvaController.clearSelection();
      }
    });
  }

  showMessage(message, autoHide = false, duration = 2000) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50';

    if (autoHide) {
      // Auto-hide version without OK button
      messageDiv.innerHTML = `
        <div class="bg-white p-6 rounded-lg shadow-xl text-center rounded-xl">
          <p class="text-lg font-semibold">${message}</p>
        </div>
      `;
      document.body.appendChild(messageDiv);

      setTimeout(() => {
        if (document.body.contains(messageDiv)) {
          document.body.removeChild(messageDiv);
        }
      }, duration);
    } else {
      // Manual dismiss version with OK button
      messageDiv.innerHTML = `
        <div class="bg-white p-6 rounded-lg shadow-xl text-center rounded-xl">
          <p class="mb-4 text-lg font-semibold">${message}</p>
          <div class="flex justify-center">
            <button id="ok-btn" class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 shadow-md transition duration-300 ease-in-out">OK</button>
          </div>
        </div>
      `;
      document.body.appendChild(messageDiv);

      document.getElementById('ok-btn').onclick = () => {
        document.body.removeChild(messageDiv);
      };
    }
  }

  showConfirmation(message, onConfirm) {
    const confirmationDiv = document.createElement('div');
    confirmationDiv.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50';
    confirmationDiv.innerHTML = `
      <div class="bg-white p-6 rounded-lg shadow-xl text-center rounded-xl">
        <p class="mb-4 text-lg font-semibold">${message}</p>
        <div class="flex justify-center space-x-4">
          <button id="confirm-btn" class="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 shadow-md transition duration-300 ease-in-out">Yes</button>
          <button id="cancel-btn" class="px-6 py-2 bg-gray-300 text-gray-800 rounded-lg hover:bg-gray-400 shadow-md transition duration-300 ease-in-out">No</button>
        </div>
      </div>
    `;
    document.body.appendChild(confirmationDiv);

    document.getElementById('confirm-btn').onclick = () => {
      onConfirm();
      document.body.removeChild(confirmationDiv);
    };
    document.getElementById('cancel-btn').onclick = () => {
      document.body.removeChild(confirmationDiv);
    };
  }

  returnToNewDesign(delay = 0) {
    setTimeout(() => {
      window.location.href = '/landscapes/new';
    }, delay);
  }

  async insertMask(event) {
    event.preventDefault();

    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );

    if (!konvaController || !konvaController.imageNode) {
      this.showMessage('Please upload an image and make a selection first.');
      return;
    }

    const maskDataURL = konvaController.getMaskDataURL();
    if (!maskDataURL) {
      this.showMessage('Failed to generate mask data. Please try again.');
      this.showSection('editor');
      if (this.hasProgressBarContainerTarget) {
        this.progressBarContainerTarget.classList.add('hidden');
      }
      return;
    }

    const response = await fetch(maskDataURL);
    const blob = await response.blob();

    const fileName = `mask-${Date.now()}.png`;
    const file = new File([blob], fileName, { type: 'image/png' });

    const dataTransfer = new DataTransfer();
    dataTransfer.items.add(file);

    this.maskTarget.files = dataTransfer.files;

    this.submitTarget.click();
  }

  getLocation(event) {
    event.preventDefault();
    if (navigator.geolocation) {
      // No custom overlay - let the server-side loader handle progress display
      navigator.geolocation.getCurrentPosition(
        (position) => {
          this.updateLocation(position.coords.latitude, position.coords.longitude);
        },
        (error) => {
          console.error("Error getting location:", error);
          this.showMessage("Could not get your location. Please ensure you have allowed location access.");
        }
      );
    } else {
      this.showMessage("Geolocation is not supported by this browser.");
    }
  }

  updateLocation(lat, lng) {
    const url = this.element.dataset.maskRequestUpdateLocationUrl;

    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ user: { latitude: lat, longitude: lng } })
    })
    .then(response => {
      if (response.ok) {
        // Just trigger plant suggestions - loader will be managed by broadcasts
        this.requestPlantSuggestions();
        if (this.hasSuggestionsSectionTarget) {
          this.suggestionsSectionTarget.classList.remove('hidden');
        }
      } else {
        this.showMessage("Failed to update location.");
      }
    });
  }

  requestPlantSuggestions() {
    const url = this.element.dataset.maskRequestSuggestPlantsUrl;
    fetch(url, {
      method: 'POST',
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.text())
    .then(html => {
      if (window.Turbo) {
        window.Turbo.renderStreamMessage(html);
      } else {
        console.error("Turbo not found");
      }
    });
  }
}
