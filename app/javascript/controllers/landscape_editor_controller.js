// app/javascript/controllers/editor_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = [
    'editorSection',
    'loadingSection',
    'resultSection',
    'konvaCanvasWrapper',
    'originalResultImage',
    'modifiedResultImage',
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
    'progressBarContainer', // Add this target if it's for the AI processing bar
    'progressBar', // Add this target if it's for the AI processing bar
  ];

  static values = {
    originalImageUrl: String,
    displayImageWidth: Number,
    displayImageHeight: Number,
    landscapeId: Number,
    modifiedImageUrl: String, // For displaying results on initial load if already processed
  };

  // Maximum dimension for client-side image resizing for CANVAS DISPLAY
  MAX_CANVAS_DISPLAY_WIDTH = 500;
  MAX_CANVAS_DISPLAY_HEIGHT = 500;

  connect() {
    console.log('Editor Controller connected.');
    this.setBrushSizeDisplay(40);

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
    const hasLandscapeId = this.hasLandscapeIdValue && this.landscapeIdValue != null; // Check for ID existence and non-null/undefined

    if (originalImageExists) {
      console.log('Original image URL found, initializing editor.');
      this.initializeEditorWithImage(
        this.originalImageUrlValue,
        this.displayImageWidthValue,
        this.displayImageHeightValue
      );
    } else if (modifiedImageExists) {
      // If only a modified URL is present, display results directly
      // Note: originalImageURL might still be needed for the 'original' display
      this.displayResults(this.originalImageUrlValue || '', this.modifiedImageUrlValue);
    } else if (hasLandscapeId) {
      // If there's a landscape ID but no image URLs, it implies an image might be processing
      // or a fresh page load where the image will be fetched.
      // In this case, we might want to show loading or redirect if it's truly an empty state.
      // For now, let's assume if there's an ID, the image *should* exist or be fetched.
      console.warn('Landscape ID found but no image URLs. This might be an intermediate state or an error.');
      // You could add a check here to fetch the image if it's expected.
      // For now, it will proceed without an image on the canvas.
      this.showSection('editor'); // Still show editor, but it'll be empty.
      this.showMessage("No image to display yet. Please upload one or check if it's still processing.");
    } else {
      console.error('Editor Controller connected without image data or a landscape ID.');
      // Keep the current section hidden or show a generic message area
      // and allow the user to click "Start New Design"
      this.showMessage("It looks like there's no image to edit. Please start a new design by uploading an image.");
      // Ensure no section is shown or default to a safe state
      this.editorSectionTarget.classList.add('hidden');
      this.loadingSectionTarget.classList.add('hidden');
      this.resultSectionTarget.classList.add('hidden');

      // Given the critical nature of no image, an explicit redirect to '/landscapes/new'
      // might be the most user-friendly approach here, as there's nothing to edit.
      // Uncomment this line if you want to force redirect in a truly empty state.
      this.returnToNewDesign(2000);
    }

    // Set the landscape_id in the hidden input for form submissions
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

  // --- UI State Management ---
  // Assuming a showSection method exists in your controller:
  showSection(sectionName) {
    console.log('showSection called with:', sectionName);
    // Ensure all sections are hidden first
    this.editorSectionTarget.classList.add('hidden');
    this.loadingSectionTarget.classList.add('hidden');
    this.resultSectionTarget.classList.add('hidden'); // Ensure this is hidden initially

    // Then show the requested section
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

  // Helper for updating brush size display
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

  /**
   * Initializes the Konva editor with the provided image URL and dimensions.
   * @param {string} imageUrl The URL of the image to display.
   * @param {number} displayWidth The width for the canvas.
   * @param {number} displayHeight The height for the canvas.
   */
  async initializeEditorWithImage(imageUrl, displayWidth, displayHeight) {
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
      this.returnToNewDesign(2000);
    }
  }

  // Listener for custom events from KonvaCanvasManager
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
      this.showMessage('No active drawing tool or actions to undo.'); // More specific message
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
      this.showMessage('No active drawing tool or actions to redo.'); // More specific message
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

  // --- Message/Confirmation Pop-ups ---
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

  // --- AJAX Form Submission (for AI processing after making mask) ---
  async submitModification(event) {
    event.preventDefault(); // Prevent default form submission

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

    const landscapeId = this.landscapeIdValue;
    if (!landscapeId) {
      console.error('Landscape ID is missing for modification submission.');
      this.showMessage('Error: Image ID not found. Please start a new design.');
      this.returnToNewDesign();
    }

    // Prepare data for AJAX request
    const formData = new FormData();
    formData.append('landscape[id]', landscapeId); // Ensure landscape ID is sent
    formData.append('landscape[mask_image_data]', maskDataURL);
    formData.append('landscape[preset]', preset);
    formData.append('id', landscapeId);

    try {
      const response = await fetch(`/landscapes/modify`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content, // Include CSRF token
          Accept: 'application/json', // Request JSON response
        },
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to process image.');
      }

      const responseData = await response.json();
      console.log('AJAX submission successful:', responseData);

      // Even with AJAX, we still expect ActionCable to broadcast the final result,
      // as the AI processing is likely async.
      // The AJAX response here might just confirm the job was queued.
      if (responseData.status === 'processing' || responseData.status === 'queued') {
        // Keep showing loading section while ActionCable waits for completion
        console.log('AI processing queued. Waiting for ActionCable broadcast...');
      } else {
        // If the backend returns the final result directly (less common for AI)
        this.handleAiDataReceived(new CustomEvent('landscape:ai-data-received', { detail: responseData }));
      }
    } catch (error) {
      console.error('Error submitting modification:', error);
      this.showMessage(`Error: ${error.message}. Please try again.`);
      this.showSection('editor'); // Go back to editor on AJAX error
      if (this.hasProgressBarContainerTarget) {
        this.progressBarContainerTarget.classList.add('hidden');
      }
    }
  }

  // Assumed to be in app/javascript/controllers/editor_controller.js or landscape_editor_controller.js
  // based on data-controller="landscape-editor" in your HTML

  // Assume these are correctly defined targets:
  // static targets = ["editorSection", "loadingSection", "resultSection",
  //                    "originalResultImage", "modifiedResultImage", "downloadButton",
  //                    "progressBarContainer", "progressBar", ...]

  handleAiDataReceived(event) {
    const data = event.detail;
    console.log('Handling AI data received in Editor Controller:', data);

    if (data.modified_image_url) {
      // Log the URLs received here to confirm they are what you expect
      console.log('handleAiDataReceived - Original URL:', data.original_image_url);
      console.log('handleAiDataReceived - Modified URL:', data.modified_image_url);

      this.displayResults(data.original_image_url, data.modified_image_url);
    } else if (data.error) {
      this.showMessage(`AI processing error: ${data.error}`);
      this.showSection('editor');
    }
    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.add('hidden');
    }
  }

  displayResults(originalUrl, modifiedUrl) {
    console.log('displayResults called with:');
    console.log('  Original URL:', originalUrl);
    console.log('  Modified URL:', modifiedUrl);

    // Check if targets are available
    if (!this.hasOriginalResultImageTarget || !this.hasModifiedResultImageTarget) {
      console.error('displayResults: Image targets not found!');
      return; // Exit if targets are missing
    }

    this.originalResultImageTarget.src = originalUrl || ''; // originalUrl might be null/undefined
    this.modifiedResultImageTarget.src = modifiedUrl;
    this.downloadButtonTarget.href = modifiedUrl;

    console.log('displayResults: Setting originalResultImage src to', this.originalResultImageTarget.src);
    console.log('displayResults: Setting modifiedResultImage src to', this.modifiedResultImageTarget.src);

    // This is the CRITICAL part for visibility
    this.showSection('result');

    // Ensure progress bar is hidden
    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.add('hidden');
    }
  }

  // And your Stimulus targets might look something like this in your controller class:
  // static targets = ["editorSection", "loadingSection", "resultSection", "originalResultImage", "modifiedResultImage", "downloadButton", "modifiedImageUrlInput", "progressBarContainer", "progressBar"];

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
        window.location.href = `/landscapes/${landscapeId}/edit`;
        this.showSection('loading');
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

  // --- Editor Reset ---
  resetEditorState() {
    const konvaController = this.application.getControllerForElementAndIdentifier(
      this.konvaCanvasWrapperTarget,
      'konva-canvas'
    );
    if (konvaController) {
      konvaController.destroyKonva();
    }

    this.maskImageDataInputTarget.value = '';
    if (this.hasModifiedImageUrlInputTarget) {
      this.modifiedImageUrlInputTarget.value = ''; // Corrected target name here if it was a typo
    }
    if (this.hasSelectPresetTarget) {
      this.selectPresetTarget.value = '';
    }

    if (this.hasProgressBarContainerTarget) {
      this.progressBarContainerTarget.classList.add('hidden');
    }
    this.setBrushSizeDisplay(40);
    this.updateUndoRedoButtonStates();
  }
}
