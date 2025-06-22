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
  resizeObserver = null;

  connect() {
    console.log('Landscaper controller connected!');
    // # we log canvasContainerTarget size
    console.log(
      'The canvasContainerTarget size is: ',
      this.canvasContainerTarget.offsetWidth,
      this.canvasContainerTarget.offsetHeight,
      'px'
    );
    this.showSection('upload');

    this.resizeObserver = new ResizeObserver((entries) => {
      for (let entry of entries) {
        if (entry.target === this.canvasContainerTarget && this.stage) {
          this.handleCanvasResize();
        }
      }
    });
    this.resizeObserver.observe(this.canvasContainerTarget);
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
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
        if (!this.stage) {
          this.initializeKonva();
        } else {
          this.handleCanvasResize();
        }
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

  uploadFile(file) {
    this.showSection('loading');
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%';

    if (!file) {
      console.error('uploadFile: No file provided.');
      alert('Please select an image file to upload.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }
    console.log('uploadFile: Attempting to upload:', file.name, 'Type:', file.type, 'Size:', file.size);

    if (!this.uploadUrlValue) {
      console.error('uploadUrlValue is missing. Check data-landscaper-upload-url-value in HTML.');
      alert('Upload configuration error. Please contact support.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
      return;
    }
    console.log('Using upload URL:', this.uploadUrlValue);

    const upload = new DirectUpload(file, this.uploadUrlValue, this);

    upload.create((error, blob) => {
      if (error) {
        console.error('Direct upload failed:', error);
        console.error('Detailed error:', JSON.stringify(error, null, 2));
        alert('Image upload failed. Please try again.');
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
          alert('Upload failed: Missing necessary blob properties after successful transfer. Please try again.');
          this.showSection('upload');
          this.progressBarContainerTarget.classList.add('hidden');
        }
      }
    });
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
  initializeKonva() {
    // # we show the holding container first
    this.editorSectionTarget.classList.remove('hidden');
    const container = this.canvasContainerTarget;
    const width = container.clientWidth;
    const height = container.clientHeight;

    console.log('Initializing Konva with container dimensions:', width, height);

    if (width === 0 || height === 0) {
      console.error('Container dimensions are zero. Cannot initialize Konva.');
      return;
    }

    if (this.stage) {
      this.stage.destroy();
    }

    this.stage = new Konva.Stage({
      container: container,
      width: width,
      height: height,
    });

    this.layer = new Konva.Layer();
    this.stage.add(this.layer);

    this.maskLayer = new Konva.Layer();
    this.stage.add(this.maskLayer);

    const maskCanvas = document.createElement('canvas');
    maskCanvas.width = width;
    maskCanvas.height = height;
    this.maskContext = maskCanvas.getContext('2d');
    this.maskContext.fillStyle = 'white';
    this.maskContext.fillRect(0, 0, width, height);

    console.log('Mask canvas dimensions:', maskCanvas.width, maskCanvas.height);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      globalCompositeOperation: 'source-over',
      opacity: 0.5,
    });
    this.maskLayer.add(this.maskImageNode);

    this.setupDrawingEvents();
  }

  handleCanvasResize() {
    if (!this.stage || !this.imageNode) return;

    const container = this.canvasContainerTarget;
    const newWidth = container.clientWidth;
    const newHeight = container.clientHeight;

    console.log('Resizing canvas to dimensions:', newWidth, newHeight);

    this.stage.width(newWidth);
    this.stage.height(newHeight);

    if (this.imageNode && this.imageNode.image()) {
      const img = this.imageNode.image();
      const scale = Math.min(newWidth / img.width, newHeight / img.height);
      const scaledWidth = img.width * scale;
      const scaledHeight = img.height * scale;

      this.imageNode.setAttrs({
        x: (newWidth - scaledWidth) / 2,
        y: (newHeight - scaledHeight) / 2,
        width: scaledWidth,
        height: scaledHeight,
      });
    }

    if (this.maskContext && this.maskContext.canvas) {
      const oldMaskCanvas = this.maskContext.canvas;
      const newMaskCanvas = document.createElement('canvas');
      newMaskCanvas.width = newWidth;
      newMaskCanvas.height = newHeight;
      const newMaskContext = newMaskCanvas.getContext('2d');

      newMaskContext.drawImage(
        oldMaskCanvas,
        0,
        0,
        oldMaskCanvas.width,
        oldMaskCanvas.height,
        0,
        0,
        newWidth,
        newHeight
      );

      this.maskContext = newMaskContext;
      this.maskImageNode.image(newMaskCanvas);
      this.maskLayer.batchDraw();
    }

    this.layer.batchDraw();
  }

  loadImageOnCanvas(imageUrl) {
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.onload = () => {
      console.log('Image loaded successfully:', img.width, img.height);
      this.initializeKonva();

      if (!this.stage) {
        console.error('Stage is not initialized.');
        return;
      }

      const stageWidth = this.stage.width();
      const stageHeight = this.stage.height();

      const scale = Math.min(stageWidth / img.width, stageHeight / img.height);
      const scaledWidth = img.width * scale;
      const scaledHeight = img.height * scale;

      console.log('Scaling image to dimensions:', scaledWidth, scaledHeight);

      this.imageNode = new Konva.Image({
        image: img,
        x: (stageWidth - scaledWidth) / 2,
        y: (stageHeight - scaledHeight) / 2,
        width: scaledWidth,
        height: scaledHeight,
        draggable: false,
      });

      this.layer.add(this.imageNode);
      this.layer.batchDraw();
      this.showSection('editor');
      this.progressBarContainerTarget.classList.add('hidden');
    };
    img.onerror = (e) => {
      console.error('Failed to load image:', e);
      console.error('Image loading error event:', e);
      alert('Could not load image for editing. Please try a different image. Check console for details.');
      this.showSection('upload');
      this.progressBarContainerTarget.classList.add('hidden');
    };
    img.src = imageUrl;
  }

  // --- Drawing and Selection Logic (Konva.js) ---
  setupDrawingEvents() {
    if (!this.stage) {
      console.error('Stage is not initialized.');
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
    this.maskContext.strokeStyle = 'black';
    this.maskContext.lineWidth = this.brushSize;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
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
        fill: 'rgba(0,0,0,0.5)',
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
      this.maskContext.fillStyle = 'black';
      this.maskContext.fillRect(
        this.currentRect.x(),
        this.currentRect.y(),
        this.currentRect.width(),
        this.currentRect.height()
      );
      this.currentRect.destroy();
      this.currentRect = null;
    }
    if (this.maskImageNode) {
      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw();
    }
  }

  getRelativePointerPosition(absolutePos) {
    if (!this.imageNode || !this.imageNode.image()) return { x: 0, y: 0 };

    const imagePos = this.imageNode.position();
    const imageScaledWidth = this.imageNode.width();
    const imageScaledHeight = this.imageNode.height();
    const originalImageWidth = this.imageNode.image().width;
    const originalImageHeight = this.imageNode.image().height;

    const scaleFactorX = imageScaledWidth / originalImageWidth;
    const scaleFactorY = imageScaledHeight / originalImageHeight;

    const xOnImageScaled = absolutePos.x - imagePos.x;
    const yOnImageScaled = absolutePos.y - imagePos.y;

    const xOriginal = xOnImageScaled / scaleFactorX;
    const yOriginal = yOnImageScaled / scaleFactorY;

    return {
      x: xOriginal,
      y: yOriginal,
    };
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
        this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
        this.maskContext.fillStyle = 'white';
        this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

        if (this.maskImageNode) {
          this.maskImageNode.image(this.maskContext.canvas);
        }
        if (this.maskLayer) {
          this.maskLayer.removeChildren();
          this.maskLayer.add(this.maskImageNode);
          this.maskLayer.batchDraw();
        }
        console.log('Selections cleared.');
      }
    });
  }

  showConfirmation(message, onConfirm) {
    const confirmationDiv = document.createElement('div');
    confirmationDiv.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50';
    confirmationDiv.innerHTML = `
      <div class="bg-white p-6 rounded-lg shadow-xl text-center">
        <p class="mb-4 text-lg">${message}</p>
        <div class="flex justify-center space-x-4">
          <button id="confirm-btn" class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600">Yes</button>
          <button id="cancel-btn" class="px-4 py-2 bg-gray-300 text-gray-800 rounded hover:bg-gray-400">No</button>
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
      alert('Please upload an image first.');
      return;
    }
    const prompt = this.promptInputTarget.value.trim();
    if (!prompt) {
      alert('Please enter a prompt for your landscaping modification.');
      return;
    }

    this.showSection('loading');
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%';

    if (!this.imageNode || !this.imageNode.image()) {
      console.error('Image node or image is not available.');
      return;
    }

    const originalImgElement = this.imageNode.image();
    const originalImageWidth = originalImgElement.width;
    const originalImageHeight = originalImgElement.height;

    const finalMaskCanvas = document.createElement('canvas');
    finalMaskCanvas.width = originalImageWidth;
    finalMaskCanvas.height = originalImageHeight;
    const finalMaskContext = finalMaskCanvas.getContext('2d');

    finalMaskContext.drawImage(
      this.maskContext.canvas,
      0,
      0,
      this.maskContext.canvas.width,
      this.maskContext.canvas.height,
      0,
      0,
      originalImageWidth,
      originalImageHeight
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
      alert(`Failed to generate landscape: ${error.message}. Please try again.`);
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
    this.promptInputTarget.value = '';
    this.originalImageUrlValue = '';
    this.modifiedImageUrlValue = '';
    this.progressBarTarget.style.width = '0%';
    this.progressBarContainerTarget.classList.add('hidden');
    this.brushSizeControlTarget.classList.add('hidden');
    this.currentTool = 'brush';
  }
}
