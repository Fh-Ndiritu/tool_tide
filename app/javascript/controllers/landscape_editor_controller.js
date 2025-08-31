// app/javascript/controllers/editor_controller.js
import { Controller } from '@hotwired/stimulus';
import consumer from 'channels/consumer';

export default class extends Controller {
  static targets = [
    'editorSection',
    'loadingSection',
    'resultSection',
    'konvaCanvasWrapper',
    'originalResultImage',
    'modifiedResultImage1', // Keep these targets for consistency, though they won't be set directly here anymore
    'modifiedResultImage2',
    'modifiedResultImage3',
    'downloadButton',
    'selectPreset',
    'brushSizeControl',
    'brushSizeDisplay',
    'undoButton',
    'redoButton',
    'form',
    'maskImageDataInput',
    'modifiedImageUrlInput',
    'landscapeIdInput', // Hidden input to pass landscape ID back to Rails
    'progressBarContainer',
    'progressBar',
    'latitudeInput',
    'longitudeInput',
    'locationBtn',
    'profileBtn',
    'processingMessage',
  ];

  static values = {
    originalImageUrl: String,
    displayImageWidth: Number,
    displayImageHeight: Number,
    landscapeId: Number,
    modifiedImageUrl: String,
    landscapeRequestId: Number,
  };

  // Maximum dimension for client-side image resizing for CANVAS DISPLAY
  MAX_CANVAS_DISPLAY_WIDTH = 500;
  MAX_CANVAS_DISPLAY_HEIGHT = 500;

  connect() {
    this.createChannels();
    console.log('Editor Controller connected.');
    this.setBrushSizeDisplay(60);

    // Listen for AI results (ActionCable)
    document.addEventListener('landscape:ai-data-received', this.handleAiDataReceived.bind(this));

    // Listen for custom events from the konva-canvas controller
    if (this.hasKonvaCanvasWrapperTarget) {
      this.konvaCanvasWrapperTarget.addEventListener(
        'konva:mask-history-changed',
        this._handleKonvaHistoryChange.bind(this)
      );
    }
    this.updateUndoRedoButtonStates(); // Initial state for buttons

    // --- REVISED LOGIC FOR CONNECT METHOD ---
    const originalImageExists = this.originalImageUrlValue && this.originalImageUrlValue.length > 0;
    const modifiedImageExists = this.modifiedImageUrlValue && this.modifiedImageUrlValue.length > 0;
    const hasLandscapeId = this.hasLandscapeIdValue && this.landscapeIdValue != null;

    if (originalImageExists) {
      console.log('Original image URL found, initializing editor.');
      this.initializeEditorWithImage(
        this.originalImageUrlValue,
        this.displayImageWidthValue,
        this.displayImageHeightValue
      );
    } else if (modifiedImageExists) {
      // If a modified URL is present on initial load, it means it's already processed.
      // We will now redirect to the show page to display it.
      console.log('Modified image URL found on connect, redirecting to show page.');
      this.redirectToLandscapeShow(this.landscapeIdValue);
    } else if (hasLandscapeId) {
      console.warn('Landscape ID found but no image URLs. This might be an intermediate state or an error.');
      this.showSection('editor');
      this.showMessage("No image to display yet. Please upload one or check if it's still processing.");
    } else {
      console.error('Editor Controller connected without image data or a landscape ID.');
      this.showMessage("It looks like there's no image to edit. Please start a new design by uploading an image.");
      this.editorSectionTarget.classList.add('hidden');
      this.loadingSectionTarget.classList.add('hidden');
      this.resultSectionTarget.classList.add('hidden');
      this.returnToNewDesign(2000);
    }

    if (hasLandscapeId) {
      this.landscapeIdInputTarget.value = this.landscapeIdValue;
    }
  }

  disconnect() {
    console.log('Editor Controller disconnected.');
    document.removeEventListener('landscape:ai-data-received', this.handleAiDataReceived.bind(this));
    if (this.hasKonvaCanvasWrapperTarget) {
      this.konvaCanvasWrapperTarget.removeEventListener(
        'konva:mask-history-changed',
        this._handleKonvaHistoryChange.bind(this)
      );
    }
    this.resetEditorState();
  }

  createChannels() {
    // Create a subscription to the LandscaperChannel
    console.log(`************************* Connecting to LandscapeChannel for ID: ${this.landscapeIdValue}`);

    this.channel = consumer.subscriptions.create(
      {
        channel: 'LandscapeChannel',
        landscape_id: this.landscapeIdValue, // Pass the landscape_id as a parameter
      },
      {
        connected: () => {
          console.log(`Connected to LandscapeChannel for ID: ${this.landscapeIdValue}`);
          // You can perform actions here after successful connection
        },
        disconnected: () => {
          console.log(`Disconnected from LandscapeChannel for ID: ${this.landscapeIdValue}`);
        },
        received(data) {
          console.log('Received data from LandscaperChannel:', data);

          // Dispatch a custom event with the received data
          const event = new CustomEvent('landscape:ai-data-received', {
            detail: data,
            bubbles: true,
            cancelable: true,
          });

          document.dispatchEvent(event);
        },
      }
    );
  }

  showSection(sectionName) {
    console.log('showSection called with:', sectionName);
    this.editorSectionTarget.classList.add('hidden');
    this.loadingSectionTarget.classList.add('hidden');
    this.resultSectionTarget.classList.add('hidden');

    switch (sectionName) {
      case 'editor':
        this.editorSectionTarget.classList.remove('hidden');
        break;
      case 'loading':
        this.loadingSectionTarget.classList.remove('hidden');
        break;
      case 'result':
        this.resultSectionTarget.classList.remove('hidden');
        console.log('Result section should now be visible (hidden class removed).');
        break;
    }
  }

  setBrushSizeDisplay(size) {
    if (this.hasBrushSizeControlTarget) {
      const brushSizeInput = this.brushSizeControlTarget.querySelector('#brush-size');
      if (brushSizeInput) {
        brushSizeInput.value = size;
      }
    }
    if (this.hasBrushSizeDisplayTarget) {
      this.brushSizeDisplayTarget.textContent = `${size}px`;
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

        this.showSection('editor');
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

  selectRectTool() {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      konvaController.setTool({ params: { tool: 'rect' } });
      this.brushSizeControlTarget.classList.add('hidden');
      console.log('Selected: Rectangle Tool');
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
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      konvaController.brushSizeValue = size;
    }
    this.setBrushSizeDisplay(size);
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

  showMessage(message) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50';
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

  async submitModification(event) {
    event.preventDefault();

    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );

    if (!konvaController || !konvaController.imageNode) {
      this.showMessage('Please upload an image and make a selection first.');
      return;
    }
    const preset = this.selectPresetTarget.value.trim();
    if (!preset) {
      this.showMessage('Please select a vibe to style your yard.');
      return;
    }

    this.showSection('loading');
    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.remove('hidden');
      this.progressBarTarget.style.width = '0%';
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

    const landscapeRequestId = this.landscapeRequestIdValue;
    if (!landscapeRequestId) {
      console.error('Landscape ID is missing for modification submission.');
      this.showMessage(' Image ID not found. Please start a new design.');
      this.returnToNewDesign();
    }

    console.log('landscapeRequestIdValue', this.landscapeRequestIdValue);
    const formData = new FormData();
    formData.append('landscape_request[id]', landscapeRequestId);
    formData.append('landscape_request[mask]', maskDataURL);
    formData.append('landscape_request[preset]', preset);

    try {
      const response = await fetch(`/landscape_requests/` + landscapeRequestId, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          Accept: 'application/json',
        },
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        console.error('AJAX submission failed:', errorData);

        // Check for the specific status code and error message for low credits
        if (response.status === 401 && errorData.error.includes('low on free engine credits')) {
          window.location.href = `/landscape_requests/${landscapeRequestId}/low_credits`;
        } else {
          throw new Error(errorData.error || 'Failed to process image.');
        }
      } else {
        // Handling a successful response
        const responseData = await response.json();
        console.log('AJAX submission successful:', responseData);

        if (responseData.status === 'processing' || responseData.status === 'queued') {
          console.log('AI processing queued. Waiting for ActionCable broadcast...');
        } else {
          // If the backend returns the final result directly (less common for AI)
          this.handleAiDataReceived(new CustomEvent('landscape:ai-data-received', { detail: responseData }));
        }
      }
    } catch (error) {
      console.error('Error submitting modification:', error);
      this.showMessage(`${error.message}. Please try again.`);
      this.showSection('editor');
      if (this.hasProgressBarContainerTarget) {
        this.progressBarContainerTarget.classList.add('hidden');
      }
    }
  }

  handleAiDataReceived(event) {
    const data = event.detail;
    console.log('Handling AI data received in Editor Controller:', data);

    if (data.status === 'completed' && data.landscape_id) {
      console.log('AI processing completed. Redirecting to landscape show page:', data.landscape_id);
      this.redirectToLandscapeShow(data.landscape_id);
    } else if (data.message) {
      console.log('Found message', data);
      // this.processingMessage.innerHTML = data.message;
    } else if (data.error) {
      this.showMessage(` ${data.error}`);
      this.showSection('editor');
    } else {
      console.warn('AI data received but not in expected completed format or missing landscape_id.');
      // Keep showing loading or return to editor if no clear status
      // You might want to add a timeout to return to editor if no completion signal
    }
    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.add('hidden');
    }
  }

  // New method to handle redirection
  redirectToLandscapeShow(landscapeId) {
    if (landscapeId) {
      window.location.href = `/landscapes/${landscapeId}`;
    } else {
      console.error('Cannot redirect, landscape ID is missing.');
      this.showMessage('An error occurred. Please try starting a new design.');
      this.returnToNewDesign(2000);
    }
  }

  // The displayResults method is no longer needed in this controller
  // as the show page will handle displaying the images.
  // displayResults(originalUrl, modifiedUrls) { /* ... */ }

  cancelEdit() {
    this.showConfirmation('Discard current changes and start over?', () => {
      this.resetEditorState();
      this.returnToNewDesign();
    });
  }

  editFurther() {
    this.showConfirmation('Start a new edit with the original image?', () => {
      this.resetEditorState();
      const landscapeId = this.landscapeIdValue;
      if (landscapeId) {
        window.location.href = `/landscapes/${landscapeId}/edit`; // Stay on edit page
        this.showSection('loading'); // Show loading state briefly
      } else {
        this.showMessage('Original image ID not available for further editing. Please start a new design.');
        this.returnToNewDesign(2000);
      }
    });
  }

  returnToNewDesign(delay = 0) {
    setTimeout(() => {
      window.location.href = '/landscapes/new';
    }, delay);
  }

  startNewDesign() {
    this.resetEditorState();
    this.returnToNewDesign();
  }

  resetEditorState() {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      konvaController.destroyKonva();
    }

    this.maskImageDataInputTarget.value = '';
    // These targets are no longer directly set by this controller, but good to clear if they exist
    if (this.hasOriginalResultImageTarget) this.originalResultImageTarget.src = '';
    if (this.hasModifiedResultImage1Target) this.modifiedResultImage1Target.src = '';
    if (this.hasModifiedResultImage2Target) this.modifiedResultImage2Target.src = '';
    if (this.hasModifiedResultImage3Target) this.modifiedResultImage3Target.src = '';
    if (this.hasDownloadButtonTarget) this.downloadButtonTarget.removeAttribute('href');

    if (this.hasModifiedImageUrlInputTarget) {
      this.modifiedImageUrlInputTarget.value = '';
    }
    if (this.hasSelectPresetTarget) {
      this.selectPresetTarget.value = '';
    }

    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.add('hidden');
    }
    this.setBrushSizeDisplay(60);
    this.updateUndoRedoButtonStates();
  }

  fetchLocation() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(this.handleSuccess.bind(this), this.handleError.bind(this));
    }
  }

  handleSuccess(position) {
    const { latitude, longitude } = position.coords;
    this.latitudeInputTarget.value = latitude;
    this.longitudeInputTarget.value = longitude;
    this.profileBtnTarget.click();
  }

  handleError(error) {
    console.error(`ERROR(${error.code}): ${error.message}`);
  }
}
