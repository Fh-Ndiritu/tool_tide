import { Controller } from '@hotwired/stimulus';
import { DirectUpload } from '@rails/activestorage';

export default class extends Controller {
  static targets = [
    'uploadSection',
    'editorSection',
    'loadingSection',
    'resultSection',
    'fileInput',
    'dropZone',
    'progressBarContainer',
    'progressBar',
    'canvasContainer',
    'originalResultImage',
    'modifiedResultImage',
    'downloadButton',
    'selectPreset',
    'brushSizeControl',
    'brushSizeDisplay', // NEW: Add brushSizeDisplay as a target
    'undoButton',
    'redoButton',
  ];

  static values = {
    uploadUrl: String,
    originalImageUrl: String,
    modifiedImageUrl: String,
  };

  // Konva.js related properties
  stage = null;
  layer = null;
  imageNode = null;
  maskLayer = null;
  maskContext = null;
  maskImageNode = null;
  isDrawing = false;
  lastLine = null;
  currentTool = 'brush';
  brushSize = 40; // Default brush size
  startRectX = 0;
  startRectY = 0;
  currentRect = null;

  // NEW: History for undo/redo functionality - Changed to store data URLs
  maskHistory = [];
  historyPointer = -1;
  MAX_HISTORY_STATES = 10; // Limit history to prevent excessive memory usage

  // Maximum dimension (width or height) for client-side image resizing before upload
  MAX_UPLOAD_DIMENSION = 1920;

  // NEW: Maximum width for displaying the image on the Konva canvas
  // The height will be calculated to maintain aspect ratio.
  MAX_CANVAS_DISPLAY_WIDTH = 500;

  connect() {
    console.log('Landscaper controller connected!');
    this.showSection('upload');

    // Ensure the brush size input and display reflect the initial default value
    this.setBrushSize(this.brushSize); // Use the new helper method

    document.addEventListener('landscaper:data-received', this.handleDataReceived.bind(this));
    this.updateUndoRedoButtonStates(); // Initialize button states
  }

  disconnect() {
    document.removeEventListener('landscaper:data-received', this.handleDataReceived.bind(this));
    this.resetEditor();
  }

  // Helper method to set brush size and update display
  setBrushSize(size) {
    this.brushSize = size;
    if (this.hasBrushSizeControlTarget) {
      const brushSizeInput = this.brushSizeControlTarget.querySelector('#brush-size');
      if (brushSizeInput) {
        brushSizeInput.value = this.brushSize;
      }
    }
    if (this.hasBrushSizeDisplayTarget) {
      this.brushSizeDisplayTarget.textContent = `${this.brushSize}px`;
    }
  }

  // --- UI State Management ---
  showSection(sectionName) {
    this.uploadSectionTarget.classList.add('hidden');
    this.editorSectionTarget.classList.add('hidden');
    this.loadingSectionTarget.classList.add('hidden');
    this.resultSectionTarget.classList.add('hidden');

    switch (sectionName) {
      case 'upload':
        this.uploadSectionTarget.classList.remove('hidden');
        break;
      case 'editor':
        this.editorSectionTarget.classList.remove('hidden');
        break;
      case 'loading':
        this.loadingSectionTarget.classList.remove('hidden');
        break;
      case 'result':
        this.resultSectionTarget.classList.remove('hidden');
        break;
    }
  }

  // --- Image Upload Logic (Active Storage Direct Upload) ---
  triggerFileInput() {
    this.fileInputTarget.click();
  }

  dragOver(event) {
    event.preventDefault();
    this.dropZoneTarget.classList.add('border-primary', 'bg-neutral-100');
  }

  dragLeave(event) {
    event.preventDefault();
    this.dropZoneTarget.classList.remove('border-primary', 'bg-neutral-100');
  }

  drop(event) {
    event.preventDefault();
    this.dropZoneTarget.classList.remove('border-primary', 'bg-neutral-100');
    const files = event.dataTransfer.files;
    if (files.length > 0) {
      this.fileInputTarget.files = files;
      this.handleFileChange();
    }
  }

  handleFileChange() {
    const files = this.fileInputTarget.files;
    if (files.length > 0) {
      this.uploadFile(files[0]);
    }
  }

  // Helper function for client-side image resizing
  // This resizes the image before upload to a max of MAX_UPLOAD_DIMENSION (e.g., 1920px)
  async resizeImage(file, maxWidth, maxHeight) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (readerEvent) => {
        const image = new Image();
        image.onload = () => {
          let width = image.width;
          let height = image.height;

          // Calculate new dimensions to fit within maxWidth/maxHeight while maintaining aspect ratio
          if (width > maxWidth || height > maxHeight) {
            const aspectRatio = width / height;
            if (width > height) {
              // Landscape or square
              width = maxWidth;
              height = width / aspectRatio;
            } else {
              // Portrait
              height = maxHeight;
              width = height * aspectRatio;
            }

            // Ensure dimensions don't exceed limits after initial scaling
            // This is a safety check if the aspect ratio calculation resulted in a dimension still exceeding max.
            if (width > maxWidth) {
              width = maxWidth;
              height = width / aspectRatio;
            }
            if (height > maxHeight) {
              height = maxHeight;
              width = height * aspectRatio;
            }
          }

          const canvas = document.createElement('canvas');
          const ctx = canvas.getContext('2d');
          canvas.width = width;
          canvas.height = height;

          // Enable image smoothing for better quality during resizing
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'high';

          ctx.drawImage(image, 0, 0, width, height);

          // Convert canvas content back to a Blob
          canvas.toBlob(
            (blob) => {
              if (blob) {
                // Create a new File object from the blob, preserving the original filename and type
                const resizedFile = new File([blob], file.name, { type: file.type });
                resolve(resizedFile);
              } else {
                reject(new Error('Canvas toBlob failed during resizing.'));
              }
            },
            file.type,
            0.9
          );
        };
        image.onerror = () => reject(new Error('Image loading failed for client-side resizing.'));
        image.src = readerEvent.target.result;
      };
      reader.onerror = () => reject(new Error('FileReader failed during client-side resizing.'));
      reader.readAsDataURL(file);
    });
  }

  async uploadFile(file) {
    this.showSection('loading');
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%';

    if (!file) {
      console.error('uploadFile: No file provided.');
      this.showMessage('Please select an image file to upload.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }
    console.log('uploadFile: Attempting to upload:', file.name, 'Type:', file.type, 'Size:', file.size);

    if (!this.uploadUrlValue) {
      console.error('uploadUrlValue is missing. Check data-landscaper-upload-url-value in HTML.');
      this.showMessage('Upload configuration error. Please contact support.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }
    console.log('Using upload URL:', this.uploadUrlValue);

    try {
      // Step 1: Perform client-side resizing before direct upload
      const resizedFile = await this.resizeImage(file, this.MAX_UPLOAD_DIMENSION, this.MAX_UPLOAD_DIMENSION);
      console.log('Original image size:', file.size, 'Resized image size for upload:', resizedFile.size);

      // Step 2: Use the resized file for DirectUpload
      const upload = new DirectUpload(resizedFile, this.uploadUrlValue, this);

      upload.create((error, blob) => {
        if (error) {
          console.error('Direct upload failed:', error);
          console.error('Detailed error:', JSON.stringify(error, null, 2));
          this.showMessage('Image upload failed. Please try again.');
          this.showSection('upload');
          this.progressBarContainerTarget.classList.add('hidden');
        } else {
          console.log('Full blob object:', blob);
          console.log('Blob signed_id:', blob.signed_id);
          console.log('Blob filename:', blob.filename);

          if (blob && blob.signed_id) {
            this.originalImageUrlValue = `/rails/active_storage/blobs/${blob.signed_id}/${encodeURIComponent(
              blob.filename
            )}`;
            console.log('File uploaded to Rails disk storage:', this.originalImageUrlValue);
            this.loadImageOnCanvas(this.originalImageUrlValue);
          } else {
            console.error('Direct upload succeeded, but necessary blob properties are missing.', { blob });
            this.showMessage(
              'Upload failed: Missing necessary blob properties after successful transfer. Please try again.'
            );
            this.showSection('upload');
            this.progressBarContainerTarget.classList.add('hidden');
          }
        }
      });
    } catch (error) {
      console.error('Client-side image processing failed:', error);
      this.showMessage(`Image processing failed: ${error.message}. Please try again.`);
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
    }
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener('progress', (event) => {
      this.updateProgressBar(event);
      console.log(`Upload progress: ${(event.loaded / event.total) * 100}%`);
    });
  }

  updateProgressBar(event) {
    const progress = (event.loaded / event.total) * 100;
    this.progressBarTarget.style.width = `${progress}%`;
  }

  // --- Konva.js Canvas Initialization & Image Loading ---
  // initializeKonva now takes the exact dimensions of the image it will display.
  initializeKonva(imageDisplayWidth, imageDisplayHeight) {
    // Changed parameter names
    this.editorSectionTarget.classList.remove('hidden');
    const container = this.canvasContainerTarget;

    console.log('Initializing Konva Stage with display dimensions:', imageDisplayWidth, imageDisplayHeight);

    if (this.stage) {
      this.stage.destroy(); // Destroy previous stage if it exists
    }

    // Konva Stage width and height are set directly to the calculated display dimensions
    this.stage = new Konva.Stage({
      container: container,
      width: imageDisplayWidth,
      height: imageDisplayHeight,
    });

    this.layer = new Konva.Layer();
    this.stage.add(this.layer);

    this.maskLayer = new Konva.Layer();
    this.stage.add(this.maskLayer);

    // Mask canvas dimensions also match the image display dimensions
    const maskCanvas = document.createElement('canvas');
    maskCanvas.width = imageDisplayWidth;
    maskCanvas.height = imageDisplayHeight;
    this.maskContext = maskCanvas.getContext('2d');
    this.maskContext.fillStyle = 'white'; // Initialize mask with white background
    this.maskContext.fillRect(0, 0, imageDisplayWidth, imageDisplayHeight);

    console.log('Mask canvas dimensions:', maskCanvas.width, maskCanvas.height);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      opacity: 0.4,
    });
    this.maskLayer.add(this.maskImageNode);

    this.setupDrawingEvents();

    // Reset history when a new image is loaded
    this.maskHistory = [];
    this.historyPointer = -1;
    this.saveMaskState(); // Save initial blank mask state
    this.updateUndoRedoButtonStates(); // Update button states after initialization

    // No need for specific CSS here, as the stage dimensions are already fixed to the desired display size.
    // The parent container should ensure visibility and responsiveness.
    // Any `max-width: 100%` on the container will handle responsiveness if the screen is smaller than 500px.
    container.style.width = `${imageDisplayWidth}px`; // Set explicit width
    container.style.height = `${imageDisplayHeight}px`; // Set explicit height
    container.style.maxWidth = '100%'; // Ensures it shrinks on smaller screens
    container.style.margin = '0 auto'; // Center the container
    container.style.overflow = 'hidden'; // Hide overflow if content is larger
  }

  handleCanvasResize() {
    // This function is still effectively not needed for dynamic resizing Konva stage
    // as the stage is initialized to a fixed size based on the image's display dimensions.
    // However, the internal logic for resizing the mask canvas if it somehow differs
    // from the stage dimensions is retained as a safety measure.
    console.log('handleCanvasResize called, but stage dimensions are now fixed to image display dimensions.');
    if (this.stage && this.maskContext && this.maskImageNode) {
      const stageWidth = this.stage.width();
      const stageHeight = this.stage.height();

      if (this.maskContext.canvas.width !== stageWidth || this.maskContext.canvas.height !== stageHeight) {
        const oldMaskCanvas = this.maskContext.canvas;
        const newMaskCanvas = document.createElement('canvas');
        newMaskCanvas.width = stageWidth;
        newMaskCanvas.height = stageHeight;
        const newMaskContext = newMaskCanvas.getContext('2d');

        newMaskContext.drawImage(
          oldMaskCanvas,
          0,
          0,
          oldMaskCanvas.width,
          oldMaskCanvas.height,
          0,
          0,
          newMaskCanvas.width,
          newMaskCanvas.height
        );
        this.maskContext = newMaskContext;
        this.maskImageNode.image(newMaskCanvas);
        this.maskLayer.batchDraw();
      }
    }
  }

  loadImageOnCanvas(imageUrl) {
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.onload = () => {
      console.log('Image loaded successfully:', img.naturalWidth, img.naturalHeight);

      let displayWidth = img.naturalWidth;
      let displayHeight = img.naturalHeight;

      this.editorSectionTarget.classList.remove('hidden');
      // Get the actual width of the editorSection
      const editorSectionActualWidth = this.editorSectionTarget.offsetWidth;

      // Determine the maximum allowable width for the canvas
      let maxAllowableCanvasWidth = this.MAX_CANVAS_DISPLAY_WIDTH;

      // If editorSection is smaller than MAX_CANVAS_DISPLAY_WIDTH, use 96% of its width
      if (editorSectionActualWidth < this.MAX_CANVAS_DISPLAY_WIDTH) {
        maxAllowableCanvasWidth = editorSectionActualWidth * 0.96; // 96% of editorSection width
      }

      if (displayWidth > maxAllowableCanvasWidth) {
        const aspectRatio = displayWidth / displayHeight;
        displayWidth = maxAllowableCanvasWidth;
        displayHeight = displayWidth / aspectRatio;
      }
      displayHeight = Math.round(displayHeight);
      console.log('Calculated display dimensions for Konva:', displayWidth, displayHeight);

      // Initialize Konva stage, layers, and mask with the calculated display dimensions.
      this.initializeKonva(displayWidth, displayHeight);

      if (!this.stage) {
        console.error('Konva Stage is not initialized after image load.');
        return;
      }

      // The imageNode is created with the calculated display dimensions and placed at (0,0)
      this.imageNode = new Konva.Image({
        image: img,
        x: 0,
        y: 0,
        width: displayWidth,
        height: displayHeight,
        draggable: false,
      });

      this.layer.add(this.imageNode);
      this.layer.batchDraw();
      this.showSection('editor');
      this.progressBarContainerTarget.classList.add('hidden');
    };
    img.onerror = (e) => {
      console.error('Failed to load image:', e);
      this.showMessage('Could not load image for editing. Please try a different image. Check console for details.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
    };
    img.src = imageUrl;
  }

  // --- Drawing and Selection Logic (Konva.js) ---
  setupDrawingEvents() {
    if (!this.stage) {
      console.error('Stage is not initialized for drawing events.');
      return;
    }

    this.stage.on('mousedown touchstart', this.handleMouseDown.bind(this));
    this.stage.on('mousemove touchmove', this.handleMouseMove.bind(this));
    this.stage.on('mouseup touchend', this.handleMouseUp.bind(this));
  }

  handleMouseDown(e) {
    if (!this.imageNode || !this.stage) return;

    this.isDrawing = true;
    const pos = this.stage.getPointerPosition();
    if (!pos) return;

    const { x, y } = this.getRelativePointerPosition(pos);

    this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
    this.maskContext.strokeStyle = 'green'; // Changed from black to green
    this.maskContext.lineWidth = this.brushSize;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
      this.lastLine = new Konva.Line({
        points: [x, y],
        stroke: this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : 'rgba(0,128,0, 0.7)', // Changed from black to green
        strokeWidth: this.brushSize,
        lineCap: 'round',
        lineJoin: 'round',
      });
      this.maskLayer.add(this.lastLine);
    } else if (this.currentTool === 'rect') {
      this.startRectX = x;
      this.startRectY = y;
      this.currentRect = new Konva.Rect({
        x: x,
        y: y,
        width: 0,
        height: 0,
        fill: 'rgba(0,128,0, 0.7)', // Changed from black to green
        opacity: 1,
      });
      this.maskLayer.add(this.currentRect);
    }
    this.maskLayer.batchDraw();
  }

  handleMouseMove(e) {
    if (!this.isDrawing || !this.imageNode || !this.stage) return;

    const pos = this.stage.getPointerPosition();
    if (!pos) return;

    const { x, y } = this.getRelativePointerPosition(pos);

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.lineTo(x, y);
      this.maskContext.stroke();
      if (this.lastLine) {
        this.lastLine.points(this.lastLine.points().concat([x, y]));
      }
    } else if (this.currentTool === 'rect' && this.currentRect) {
      const width = x - this.startRectX;
      const height = y - this.startRectY;
      this.currentRect.width(width);
      this.currentRect.height(height);
    }
    if (this.maskImageNode) {
      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw();
    }
  }

  handleMouseUp() {
    this.isDrawing = false;
    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.closePath();
      if (this.lastLine) {
        this.lastLine.destroy();
        this.lastLine = null;
      }
    } else if (this.currentTool === 'rect' && this.currentRect) {
      // For rectangle, directly apply to maskContext
      this.maskContext.fillStyle = 'green'; // Changed from black to green
      // Need to respect globalCompositeOperation for eraser tool with rect
      const originalCompositeOperation = this.maskContext.globalCompositeOperation;
      this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
      this.maskContext.fillRect(
        this.currentRect.x(),
        this.currentRect.y(),
        this.currentRect.width(),
        this.currentRect.height()
      );
      this.maskContext.globalCompositeOperation = originalCompositeOperation; // Restore original

      this.currentRect.destroy();
      this.currentRect = null;
    }

    if (this.maskImageNode) {
      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw();
    }
    this.saveMaskState(); // Save the state after the action
  }

  // --- Undo/Redo Logic ---
  saveMaskState() {
    if (!this.maskContext) return;

    // If we've undone some actions and now perform a new one,
    // we need to clear the "future" history (redo states)
    if (this.historyPointer < this.maskHistory.length - 1) {
      this.maskHistory = this.maskHistory.slice(0, this.historyPointer + 1);
    }

    // Capture the entire visual state of the mask canvas as a data URL
    const dataURL = this.maskContext.canvas.toDataURL();
    this.maskHistory.push(dataURL);

    // Limit history size
    if (this.maskHistory.length > this.MAX_HISTORY_STATES) {
      this.maskHistory.shift(); // Remove the oldest state
    } else {
      this.historyPointer++;
    }

    console.log('Mask state saved. History size:', this.maskHistory.length, 'Pointer:', this.historyPointer);
    this.updateUndoRedoButtonStates();
  }

  applyMaskState(dataURL) {
    if (!this.maskContext || !this.maskImageNode) {
      console.error('Cannot apply mask state: maskContext or maskImageNode is null.');
      return;
    }

    const img = new Image();
    img.onload = () => {
      // Clear the canvas completely before drawing the new state
      this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      // Draw the restored image onto the mask canvas
      this.maskContext.drawImage(img, 0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw();
      console.log('Mask state applied from dataURL.');
    };
    img.onerror = (e) => {
      console.error('Error loading mask image from dataURL for undo/redo:', e);
    };
    img.src = dataURL;
  }

  undoPaintAction() {
    if (this.historyPointer > 0) {
      this.historyPointer--;
      const dataURL = this.maskHistory[this.historyPointer];
      if (dataURL) {
        this.applyMaskState(dataURL);
        console.log('Undo successful. History pointer:', this.historyPointer);
      }
    } else {
      console.log('No more undo history.');
      this.showMessage('No more actions to undo.');
    }
    this.updateUndoRedoButtonStates();
  }

  redoPaintAction() {
    if (this.historyPointer < this.maskHistory.length - 1) {
      this.historyPointer++;
      const dataURL = this.maskHistory[this.historyPointer];
      if (dataURL) {
        this.applyMaskState(dataURL);
        console.log('Redo successful. History pointer:', this.historyPointer);
      }
    } else {
      console.log('No more redo history.');
      this.showMessage('No more actions to redo.');
    }
    this.updateUndoRedoButtonStates();
  }

  updateUndoRedoButtonStates() {
    // Only try to access targets if they exist (e.g., editor section is visible)
    if (this.hasUndoButtonTarget) {
      this.undoButtonTarget.disabled = this.historyPointer <= 0;
      this.undoButtonTarget.classList.toggle('opacity-50', this.historyPointer <= 0);
      this.undoButtonTarget.classList.toggle('cursor-not-allowed', this.historyPointer <= 0);
    }
    if (this.hasRedoButtonTarget) {
      this.redoButtonTarget.disabled = this.historyPointer >= this.maskHistory.length - 1;
      this.redoButtonTarget.classList.toggle('opacity-50', this.historyPointer >= this.maskHistory.length - 1);
      this.redoButtonTarget.classList.toggle('cursor-not-allowed', this.historyPointer >= this.maskHistory.length - 1);
    }
  }

  getRelativePointerPosition(absolutePos) {
    // Now that the Konva stage is explicitly sized to the calculated display dimensions
    // and the imageNode also matches these dimensions, the pointer position from
    // stage.getPointerPosition() is already the correct pixel coordinate relative to the displayed image.
    if (this.imageNode && this.imageNode.image()) {
      return {
        x: absolutePos.x,
        y: absolutePos.y,
      };
    }
    return { x: 0, y: 0 };
  }

  selectRectTool() {
    this.currentTool = 'rect';
    this.brushSizeControlTarget.classList.add('hidden');
    console.log('Selected: Rectangle Tool');
  }

  selectBrushTool() {
    this.currentTool = 'brush';
    this.brushSizeControlTarget.classList.remove('hidden');
    console.log('Selected: Brush Tool');
  }

  updateBrushSize(event) {
    this.setBrushSize(parseInt(event.target.value)); // Use the helper method
  }

  clearSelection() {
    this.showConfirmation('Are you sure you want to clear all selections?', () => {
      if (this.maskContext && this.maskContext.canvas) {
        this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
        this.maskContext.fillStyle = 'white';
        this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

        if (this.maskImageNode) {
          this.maskImageNode.image(this.maskContext.canvas);
        }
        if (this.maskLayer) {
          this.maskLayer.batchDraw();
        }
        console.log('Selections cleared.');
        this.saveMaskState(); // Save state after clearing
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

  async submitModification() {
    if (!this.imageNode) {
      this.showMessage('Please upload an image first.');
      return;
    }
    const preset = this.selectPresetTarget.value.trim();
    if (!preset) {
      this.showMessage('Please select a vibe to style your yard.');
      return;
    }

    this.showSection('loading');
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%';

    if (!this.imageNode || !this.imageNode.image()) {
      console.error('Image node or image is not available.');
      this.showMessage('Image data is not available for modification.');
      this.showSection('editor');
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }

    // Use the *current Konva stage dimensions* for the mask, as these now
    // represent the desired display size (max 500px width, aspect-ratio preserved).
    const finalMaskCanvas = document.createElement('canvas');
    finalMaskCanvas.width = this.stage.width();
    finalMaskCanvas.height = this.stage.height();
    const finalMaskContext = finalMaskCanvas.getContext('2d');

    // Draw the mask canvas onto the final mask canvas, ensuring it's the same size as the image
    finalMaskContext.drawImage(
      this.maskContext.canvas,
      0,
      0,
      this.maskContext.canvas.width,
      this.maskContext.canvas.height, // Source rectangle
      0,
      0,
      finalMaskCanvas.width,
      finalMaskCanvas.height // Destination rectangle
    );

    // Convert green shades to black
    this.convertGreenToBlack(finalMaskCanvas, finalMaskContext);

    const maskDataURL = finalMaskCanvas.toDataURL('image/png');

    try {
      const response = await fetch('/landscaper/modify_image', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          landscape: {
            original_image_url: this.originalImageUrlValue,
            mask_image_data: maskDataURL,
            preset: preset,
          },
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Something went wrong with the AI generation.');
      }

      console.log('AI modification request sent. Waiting for Action Cable update.');
    } catch (error) {
      console.error('Error submitting modification:', error);
      this.showMessage(`Failed to generate landscape: ${error.message}. Please try again.`);
      this.showSection('editor');
      this.progressBarContainerTarget.classList.add('hidden');
    }
  }

  // Function to convert green shades to black
  convertGreenToBlack(canvas, context) {
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;

    for (let i = 0; i < data.length; i += 4) {
      const red = data[i];
      const green = data[i + 1];
      const blue = data[i + 2];

      // Check if the pixel is a shade of green
      if (green > red && green > blue) {
        // Convert green shades to black
        data[i] = 0; // Red
        data[i + 1] = 0; // Green
        data[i + 2] = 0; // Blue
      }
    }

    context.putImageData(imageData, 0, 0);
  }

  handleDataReceived(event) {
    const data = event.detail;
    console.log('Handling data received in Stimulus controller:', data);

    if (data.modified_image_url) {
      this.modifiedImageUrlValue = data.modified_image_url;
      console.log('Modified Image URL:', this.modifiedImageUrlValue);
      this.displayResults();
    } else if (data.error) {
      alert(`AI processing error: ${data.error}`);
      this.showSection('editor');
    }
  }

  displayResults() {
    // If the images in the result section should also be limited to 500px width,
    // you'll need to apply CSS styles to them or use a utility like Tailwind's max-w-sm/md/lg.
    // For now, they'll display at their natural size unless CSS constrains them.
    this.originalResultImageTarget.src = this.originalImageUrlValue;
    this.modifiedResultImageTarget.src = this.modifiedImageUrlValue;
    this.downloadButtonTarget.href = this.modifiedImageUrlValue;
    this.showSection('result');
    this.progressBarContainerTarget.classList.add('hidden');
  }

  cancelEdit() {
    this.showConfirmation('Discard current changes and start over?', () => {
      this.resetEditor();
      this.showSection('upload');
    });
  }

  editFurther() {
    this.resetEditor();
    this.loadImageOnCanvas(this.originalImageUrlValue);
  }

  startNewDesign() {
    this.resetEditor();
    this.showSection('upload');
  }

  resetEditor() {
    if (this.stage) {
      this.stage.destroy();
    }
    this.stage = null;
    this.layer = null;
    this.maskLayer = null;
    this.imageNode = null;
    this.maskContext = null;
    this.maskImageNode = null;
    this.isDrawing = false;
    this.lastLine = null;
    this.currentRect = null;
    this.fileInputTarget.value = null;
    if (this.hasSelectPresetTarget) {
      this.selectPresetTarget.value = '';
    }
    this.modifiedImageUrlValue = '';
    this.progressBarTarget.style.width = '0%';
    this.progressBarContainerTarget.classList.add('hidden');
    this.brushSizeControlTarget.classList.remove('hidden');
    this.currentTool = 'brush';
    this.setBrushSize(40); // Reset to new default using helper
    const container = this.canvasContainerTarget;
    container.style.width = '';
    container.style.height = '';
    container.style.maxWidth = '';
    container.style.margin = '';
    container.style.overflow = '';
    // Crucially, reset undo/redo history
    this.maskHistory = [];
    this.historyPointer = -1;
    this.updateUndoRedoButtonStates();
  }
}
