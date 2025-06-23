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
    'promptInput',
    'brushSizeControl',
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
  brushSize = 20;
  startRectX = 0;
  startRectY = 0;
  currentRect = null;

  // Maximum dimension (width or height) for client-side image resizing before upload
  MAX_UPLOAD_DIMENSION = 1920;

  connect() {
    console.log('Landscaper controller connected!');
    this.showSection('upload');

    // The ResizeObserver is removed as the Konva Stage will now match the image's natural dimensions,
    // and responsive display for the overall container will be handled by CSS.
  }

  disconnect() {
    this.resetEditor();
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
        // Konva initialization now happens *after* image load, in loadImageOnCanvas
        // No need for a separate initializeKonva call here or handleCanvasResize on section show
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
              width = maxWidth;
              height = width / aspectRatio;
            } else {
              height = maxHeight;
              width = height * aspectRatio;
            }

            // Ensure dimensions don't exceed limits after initial scaling
            // This is a safety check if the aspect ratio calculation resulted in a dimension still exceeding max.
            // (e.g., if maxWidth was hit, but height is still too large due to initial calculation)
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
            file.type, // Use original file type for the output blob
            0.9 // Compression quality for JPEG/WebP (0.9 for good balance)
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
            // Construct the URL to the uploaded original image (which is now the client-resized version)
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
  initializeKonva(imageWidth, imageHeight) {
    this.editorSectionTarget.classList.remove('hidden');
    const container = this.canvasContainerTarget;

    console.log('Initializing Konva Stage with image dimensions:', imageWidth, imageHeight);

    if (this.stage) {
      this.stage.destroy(); // Destroy previous stage if it exists
    }

    // Konva Stage width and height are set directly to the image's dimensions
    this.stage = new Konva.Stage({
      container: container,
      width: imageWidth,
      height: imageHeight,
    });

    this.layer = new Konva.Layer();
    this.stage.add(this.layer);

    this.maskLayer = new Konva.Layer();
    this.stage.add(this.maskLayer);

    // Mask canvas dimensions also match the image dimensions
    const maskCanvas = document.createElement('canvas');
    maskCanvas.width = imageWidth;
    maskCanvas.height = imageHeight;
    this.maskContext = maskCanvas.getContext('2d');
    this.maskContext.fillStyle = 'white'; // Initialize mask with white background
    this.maskContext.fillRect(0, 0, imageWidth, imageHeight);

    console.log('Mask canvas dimensions:', maskCanvas.width, maskCanvas.height);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      opacity: 0.5, // Visual opacity for the mask over the original image
      // globalCompositeOperation: 'source-over' is the default and can be omitted
    });
    this.maskLayer.add(this.maskImageNode);

    this.setupDrawingEvents();

    // Apply CSS to the container to make the fixed-size Konva canvas responsive.
    // This allows the canvas to shrink/grow with the viewport while maintaining aspect ratio.
    container.style.maxWidth = '100%';
    container.style.height = 'auto'; // Let height adjust based on maxWidth and aspect ratio
    container.style.margin = '0 auto'; // Center the container
    container.style.overflow = 'hidden'; // Hide overflow if content is larger
    // The actual Konva canvas element will be the 'imageWidth' x 'imageHeight'
    // but its display size will be governed by these container styles and the browser's scaling.
  }

  // handleCanvasResize is no longer needed as the Konva Stage dimensions are fixed to the image,
  // and the mask canvas is created with the same fixed dimensions.
  // The outer container manages its responsive display via CSS.
  // The original handleCanvasResize logic was for fitting an image *into* a resizable stage,
  // which is different from the requirement "canvas is the same size and aspect ratio as the image".
  // The mask context dimensions are set precisely in initializeKonva and will match the stage/image.
  handleCanvasResize() {
    // This function is effectively no longer needed in its original form.
    // The Konva stage and mask canvas are initialized to the exact image dimensions
    // and do not dynamically resize to the container.
    // The container's CSS handles responsive scaling of the fixed-size canvas.
    console.log('handleCanvasResize called, but stage dimensions are now fixed to image dimensions.');
    if (this.stage && this.maskContext && this.maskImageNode) {
      const stageWidth = this.stage.width();
      const stageHeight = this.stage.height();

      // Ensure the mask canvas dimensions match the stage dimensions (which are image dimensions)
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

      // Initialize Konva stage, layers, and mask with the actual natural dimensions of the loaded image.
      this.initializeKonva(img.naturalWidth, img.naturalHeight);

      if (!this.stage) {
        console.error('Konva Stage is not initialized after image load.');
        return;
      }

      // The imageNode is created with the natural dimensions and placed at (0,0)
      this.imageNode = new Konva.Image({
        image: img,
        x: 0,
        y: 0,
        width: img.naturalWidth,
        height: img.naturalHeight,
        draggable: false, // Prevent dragging the base image
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

    // With the stage dimensions now directly matching the image dimensions (1:1 pixel mapping),
    // the pointer position relative to the stage is the correct drawing coordinate.
    const { x, y } = this.getRelativePointerPosition(pos);

    this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
    this.maskContext.strokeStyle = 'black';
    this.maskContext.lineWidth = this.brushSize;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
      // Visual line for real-time drawing feedback on the mask layer (will be destroyed on mouseup)
      this.lastLine = new Konva.Line({
        points: [x, y],
        stroke: this.currentTool === 'eraser' ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)',
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
        fill: 'rgba(0,0,0,0.5)', // Visible fill for the rectangle selection
        opacity: 1,
      });
      this.maskLayer.add(this.currentRect);
    }
    this.maskLayer.batchDraw(); // Update mask layer to show initial drawing/rect
  }

  handleMouseMove(e) {
    if (!this.isDrawing || !this.imageNode || !this.stage) return;

    const pos = this.stage.getPointerPosition();
    if (!pos) return;

    // Directly use pointer position as stage is 1:1 with image
    const { x, y } = this.getRelativePointerPosition(pos);

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.lineTo(x, y);
      this.maskContext.stroke(); // Draw on the off-screen mask canvas context
      if (this.lastLine) {
        // Update the visual Konva Line node for smooth feedback
        this.lastLine.points(this.lastLine.points().concat([x, y]));
      }
    } else if (this.currentTool === 'rect' && this.currentRect) {
      // Update the Konva Rectangle node for visual feedback
      const width = x - this.startRectX;
      const height = y - this.startRectY;
      this.currentRect.width(width);
      this.currentRect.height(height);
    }
    if (this.maskImageNode) {
      // Update the Konva Image node with the modified off-screen mask canvas
      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw(); // Redraw mask layer to show changes
    }
  }

  handleMouseUp() {
    this.isDrawing = false;
    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.closePath(); // Finish the path on the mask canvas
      if (this.lastLine) {
        this.lastLine.destroy(); // Remove the temporary visual line
        this.lastLine = null;
      }
    } else if (this.currentTool === 'rect' && this.currentRect) {
      // Draw the final rectangle onto the off-screen mask canvas
      this.maskContext.fillStyle = 'black';
      this.maskContext.fillRect(
        this.currentRect.x(),
        this.currentRect.y(),
        this.currentRect.width(),
        this.currentRect.height()
      );
      this.currentRect.destroy(); // Remove the temporary visual rectangle
      this.currentRect = null;
    }
    if (this.maskImageNode) {
      this.maskImageNode.image(this.maskContext.canvas); // Update Konva Image node with final mask
      this.maskLayer.batchDraw(); // Redraw mask layer
    }
  }

  // Corrected getRelativePointerPosition:
  // With the Konva Stage set to the natural dimensions of the image,
  // and the imageNode placed at (0,0) and matching those dimensions,
  // the pointer position directly from stage.getPointerPosition() is already
  // in the correct pixel coordinates relative to the image.
  getRelativePointerPosition(absolutePos) {
    // If the imageNode exists and has an image, return the absolute pointer position directly.
    // No complex scaling or offset calculations are needed because:
    // 1. The Konva stage is sized exactly to the image's natural dimensions.
    // 2. The image node itself is placed at (0,0) within that stage and uses its natural dimensions.
    // Therefore, the stage's coordinate system is a 1:1 match with the image's pixel coordinates.
    if (this.imageNode && this.imageNode.image()) {
      return {
        x: absolutePos.x,
        y: absolutePos.y,
      };
    }
    return { x: 0, y: 0 }; // Fallback
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

  selectEraserTool() {
    this.currentTool = 'eraser';
    this.brushSizeControlTarget.classList.remove('hidden');
    console.log('Selected: Eraser Tool');
  }

  updateBrushSize(event) {
    this.brushSize = parseInt(event.target.value);
  }

  clearSelection() {
    this.showConfirmation('Are you sure you want to clear all selections?', () => {
      if (this.maskContext && this.maskContext.canvas) {
        // Clear and refill mask canvas with white
        this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
        this.maskContext.fillStyle = 'white';
        this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

        // Update Konva mask image node with the cleared canvas
        if (this.maskImageNode) {
          this.maskImageNode.image(this.maskContext.canvas);
        }
        // Remove any temporary drawing lines/rects from the mask layer
        if (this.maskLayer) {
          // It's better to remove all children except the maskImageNode itself
          const childrenToKeep = this.maskLayer.getChildren().filter((node) => node === this.maskImageNode);
          this.maskLayer.removeChildren();
          this.maskLayer.add(...childrenToKeep); // Add back only the maskImageNode
          this.maskLayer.batchDraw();
        }
        console.log('Selections cleared.');
      }
    });
  }

  // Replaces standard alert() for displaying simple messages
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
    const prompt = this.promptInputTarget.value.trim();
    if (!prompt) {
      this.showMessage('Please enter a prompt for your landscaping modification.');
      return;
    }

    this.showSection('loading');
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%';

    if (!this.imageNode || !this.imageNode.image()) {
      console.error('Image node or image is not available.');
      this.showMessage('Image data is not available for modification.');
      this.showSection('editor'); // Go back to editor if image is gone
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }

    // Use the dimensions of the Konva stage, which are now set to the natural
    // (potentially resized by client-side preprocessing) image dimensions.
    const originalImageWidth = this.stage.width();
    const originalImageHeight = this.stage.height();

    const finalMaskCanvas = document.createElement('canvas');
    finalMaskCanvas.width = originalImageWidth;
    finalMaskCanvas.height = originalImageHeight;
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
      originalImageWidth,
      originalImageHeight // Destination rectangle
    );

    const maskDataURL = finalMaskCanvas.toDataURL('image/png');

    try {
      const response = await fetch('/landscaper/modify_image', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          original_image_url: this.originalImageUrlValue,
          mask_image_data: maskDataURL,
          prompt: prompt,
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

  displayResults() {
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
    this.originalImageUrlValue = this.modifiedImageUrlValue;
    // Reload the modified image for further editing
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
    this.fileInputTarget.value = null; // Clear file input
    this.promptInputTarget.value = '';
    this.originalImageUrlValue = '';
    this.modifiedImageUrlValue = '';
    this.progressBarTarget.style.width = '0%';
    this.progressBarContainerTarget.classList.add('hidden');
    // Ensure brush size control visibility is reset to default (visible for brush/eraser)
    this.brushSizeControlTarget.classList.remove('hidden');
    this.currentTool = 'brush'; // Reset default tool
    this.brushSize = 20; // Reset default brush size
    // Reset container styles in case they were set for a specific image size
    const container = this.canvasContainerTarget;
    container.style.width = '';
    container.style.height = '';
    container.style.maxWidth = '';
    container.style.margin = '';
    container.style.overflow = '';
  }
}
