// app/javascript/controllers/konva_canvas_controller.js
import { Controller } from '@hotwired/stimulus';

const GREEN_COLOR = 'rgba(100 245 3 / 0.5)';
const MASK_COLOR = 'rgba(100, 245, 3, 1)';
const DEFAULT_MASK = 'rgba(12, 12, 12, 0)';
const CURSOR_COLOR = 'aqua'; // New constant for the cursor color
const CANVAS_PADDING = 40;

export default class extends Controller {
  static targets = ['canvasContainer'];

  static values = {
    imageUrl: String,
    brushSize: { type: Number, default: 40 },
  };

  stage = null;
  layer = null;
  imageNode = null;
  maskLayer = null;
  maskContext = null;
  maskImageNode = null;
  isDrawing = false;
  lastLine = null;
  currentTool = 'brush';
  startRectX = 0;
  startRectY = 0;
  currentRect = null;
  crosshairGroup = null;
  crosshairHorizontal = null;
  crosshairVertical = null;

  maskHistory = [];
  historyPointer = -1;
  MAX_HISTORY_STATES = 10;

  connect() {
    console.log('Konva Canvas Controller connected.');
    console.log('Image URL:', this.imageUrlValue);
    console.log('Display Width:', this.displayWidthValue);
    console.log('Display Height:', this.displayHeightValue);

    if (this.hasImageUrlValue && this.imageUrlValue) {
       this.loadImage(this.imageUrlValue);
    } else {
       console.log('No Image URL provided initially.');
    }

    // Add resize listener
    this.boundHandleResize = this.handleResize.bind(this);
    window.addEventListener('resize', this.boundHandleResize);
  }

  disconnect() {
    console.log('Konva Canvas Controller disconnected.');
    window.removeEventListener('resize', this.boundHandleResize);
    this.destroyKonva();
  }

  imageUrlValueChanged(url, oldUrl) {
    if (url && url !== oldUrl) {
      console.log('imageUrlValue changed, loading new image:', url);
      this.loadImage(url);
    }
  }

  handleResize() {
     if (this.imageNode && this.imageNode.image()) {
         this.updateDimensions(this.imageNode.image());
     }
  }



  brushSizeValueChanged() {
    if (this.crosshairHorizontal && this.crosshairVertical) {
      const halfBrushSize = this.brushSizeValue / 2;
      this.crosshairHorizontal.points([-halfBrushSize, 0, halfBrushSize, 0]);
      this.crosshairVertical.points([0, -halfBrushSize, 0, halfBrushSize]);
      this.maskLayer.batchDraw();
    }
  }

  initializeKonva(width, height) {
    if (this.stage) {
      this.stage.destroy();
    }

    const container = this.canvasContainerTarget;
    container.style.width = '100%';
    container.style.height = '100%';
    container.style.display = 'flex';
    container.style.justifyContent = 'center';
    container.style.alignItems = 'center';

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
    this.maskContext.fillStyle = DEFAULT_MASK;
    this.maskContext.fillRect(0, 0, width, height);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      opacity: 0.7,
    });
    this.maskLayer.add(this.maskImageNode);

    this.crosshairGroup = new Konva.Group({ listening: false, visible: false });

    // Move cursor setup here so it's re-created with new stage
    this.cursorCircle = new Konva.Circle({
        radius: this.brushSizeValue / 2,
        stroke: CURSOR_COLOR,
        strokeWidth: 1,
        listening: false,
    });

    this.crosshairHorizontal = new Konva.Line({
        points: [-10, 0, 10, 0],
        stroke: CURSOR_COLOR,
        strokeWidth: 3,
        lineCap: 'butt',
        listening: false,
    });

    this.crosshairVertical = new Konva.Line({
        points: [0, -10, 0, 10],
        stroke: CURSOR_COLOR,
        strokeWidth: 3,
        lineCap: 'butt',
        listening: false,
    });

    this.crosshairGroup.add(this.cursorCircle, this.crosshairHorizontal, this.crosshairVertical);
    this.maskLayer.add(this.crosshairGroup);

    // Hide default cursor
    // The container style cursor is nice, but we need to ensure it applies to stage
    this.stage.container().style.cursor = 'none';


    this.setupDrawingEvents();
    this.resetMaskHistory();
    this.saveMaskState(); // Initial save
    console.log(`Konva initialized with ${width}x${height}`);
  }

  loadImage(imageDataURL) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'Anonymous';
      img.onload = () => {
        this.updateDimensions(img);
        resolve();
      };
      img.onerror = (e) => {
        console.error('Failed to load image.', e);
        reject();
      };
      img.src = imageDataURL;
    });
  }

  updateDimensions(img) {
      if (!this.hasCanvasContainerTarget) return;

      const container = this.element.parentElement; // Parent container
      // Apply padding to the available dimensions
      const maxWidth = container.clientWidth - (CANVAS_PADDING * 2);
      const maxHeight = container.clientHeight - (CANVAS_PADDING * 2);

      const imgWidth = img.naturalWidth;
      const imgHeight = img.naturalHeight;
      const aspectRatio = imgWidth / imgHeight;

      let displayWidth = maxWidth;
      let displayHeight = maxWidth / aspectRatio;

      if (displayHeight > maxHeight) {
          displayHeight = maxHeight;
          displayWidth = maxHeight * aspectRatio;
      }

      // Rounding
      displayWidth = Math.floor(displayWidth);
      displayHeight = Math.floor(displayHeight);

      // Re-initialize Konva with new dimensions
      this.initializeKonva(displayWidth, displayHeight);

      this.imageNode = new Konva.Image({
          image: img,
          x: 0,
          y: 0,
          width: displayWidth,
          height: displayHeight,
          draggable: false
      });

      this.layer.add(this.imageNode);
      this.imageNode.moveToBottom();
      this.layer.batchDraw();
  }

  setupDrawingEvents() {
    if (this.stage) {
      this.stage.on('mousedown touchstart', this._handleMouseDown.bind(this));
      this.stage.on('mousemove touchmove', this._handleMouseMove.bind(this));
      this.stage.on('mouseup touchend', this._handleMouseUp.bind(this));
      this.stage.on('mouseenter', this._handleMouseEnter.bind(this));
      this.stage.on('mouseleave', this._handleMouseLeave.bind(this));
    }
  }

  _getRelativePointerPosition(absolutePos) {
    const transform = this.stage.getAbsoluteTransform().copy();
    transform.invert();
    const pos = transform.point(absolutePos);
    return {
      x: pos.x,
      y: pos.y,
    };
  }

  _handleMouseEnter() {
    if (this.crosshairGroup && (this.currentTool === 'brush' || this.currentTool === 'eraser')) {
      this.crosshairGroup.visible(true);
      this.maskLayer.batchDraw();
    }
  }

  _handleMouseLeave() {
    if (this.crosshairGroup) {
      this.crosshairGroup.visible(false);
      this.maskLayer.batchDraw();
    }
  }

  _handleMouseDown(e) {
    if (!this.imageNode || !this.stage) return;

    this.isDrawing = true;
    const pos = this.stage.getPointerPosition();
    if (!pos) return;

    const { x, y } = this._getRelativePointerPosition(pos);

    this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
    this.maskContext.strokeStyle = this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : GREEN_COLOR;
    this.maskContext.lineWidth = this.brushSizeValue;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
      this.lastLine = new Konva.Line({
        points: [x, y],
        stroke: this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : GREEN_COLOR,
        strokeWidth: this.brushSizeValue,
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
        fill: GREEN_COLOR,
        opacity: 1,
      });
      this.maskLayer.add(this.currentRect);
    }
    this.maskLayer.batchDraw();
  }

  _handleMouseMove(e) {
    if (!this.imageNode || !this.stage) return;

    const pos = this.stage.getPointerPosition();
    if (!pos) {
      if (this.crosshairGroup) {
        this.crosshairGroup.visible(false);
        this.maskLayer.batchDraw();
      }
      return;
    }

    const { x, y } = this._getRelativePointerPosition(pos);

    if (this.crosshairGroup && (this.currentTool === 'brush' || this.currentTool === 'eraser')) {
      this.crosshairGroup.position({ x: x, y: y });
      const halfBrushSize = this.brushSizeValue / 2;
      this.crosshairHorizontal.points([-halfBrushSize, 0, halfBrushSize, 0]);
      this.crosshairVertical.points([0, -halfBrushSize, 0, halfBrushSize]);
      this.crosshairGroup.visible(true);
      const crosshairColor = this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : CURSOR_COLOR;
      this.crosshairHorizontal.stroke(crosshairColor);
      this.crosshairVertical.stroke(crosshairColor);
    } else if (this.crosshairGroup) {
      this.crosshairGroup.visible(false);
    }

    if (!this.isDrawing) {
      this.maskLayer.batchDraw();
      return;
    }

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

  _handleMouseUp() {
    this.isDrawing = false;
    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.closePath();
      if (this.lastLine) {
        this.lastLine.destroy();
        this.lastLine = null;
      }
    } else if (this.currentTool === 'rect' && this.currentRect) {
      this.maskContext.fillStyle = MASK_COLOR;
      const originalCompositeOperation = this.maskContext.globalCompositeOperation;
      this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
      this.maskContext.fillRect(
        this.currentRect.x(),
        this.currentRect.y(),
        this.currentRect.width(),
        this.currentRect.height()
      );
      this.maskContext.globalCompositeOperation = originalCompositeOperation;

      this.currentRect.destroy();
      this.currentRect = null;
    }

    if (this.maskImageNode) {
      this.maskImageNode.image(this.maskContext.canvas);
      this.maskLayer.batchDraw();
    }
    this.saveMaskState();
  }

  resetMaskHistory() {
    this.maskHistory = [];
    this.historyPointer = -1;
    if (this.maskContext) {
      this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      this.maskContext.fillStyle = DEFAULT_MASK;
      this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      if (this.maskImageNode) {
        this.maskImageNode.image(this.maskContext.canvas);
        this.maskLayer.batchDraw();
      }
    }
    this._dispatchHistoryChangeEvent();
  }

  saveMaskState() {
    if (!this.maskContext) return;

    if (this.historyPointer < this.maskHistory.length - 1) {
      this.maskHistory = this.maskHistory.slice(0, this.historyPointer + 1);
    }

    const dataURL = this.maskContext.canvas.toDataURL();
    this.maskHistory.push(dataURL);

    if (this.maskHistory.length > this.MAX_HISTORY_STATES) {
      this.maskHistory.shift();
    }

    this.historyPointer = this.maskHistory.length - 1;
    console.log('Mask state saved. History size:', this.maskHistory.length, 'Pointer:', this.historyPointer);
    this._dispatchHistoryChangeEvent();
  }

  applyMaskState(dataURL) {
    if (!this.maskContext || !this.maskImageNode) {
      console.error('Cannot apply mask state: maskContext or maskImageNode is null.');
      return;
    }

    const img = new Image();
    img.onload = () => {
      this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
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

  undo() {
    if (this.historyPointer > 0) {
      this.historyPointer--;
      const dataURL = this.maskHistory[this.historyPointer];
      if (dataURL) {
        this.applyMaskState(dataURL);
      }
      console.log('Undo performed. History Pointer:', this.historyPointer);
    } else {
      console.log('Cannot undo: Already at the beginning of history.');
    }
    this._dispatchHistoryChangeEvent();
  }

  redo() {
    if (this.historyPointer < this.maskHistory.length - 1) {
      this.historyPointer++;
      const dataURL = this.maskHistory[this.historyPointer];
      if (dataURL) {
        this.applyMaskState(dataURL);
      }
      console.log('Redo performed. History Pointer:', this.historyPointer);
    } else {
      console.log('Cannot redo: Already at the end of history.');
    }
    this._dispatchHistoryChangeEvent();
  }

  _dispatchHistoryChangeEvent() {
    this.element.dispatchEvent(
      new CustomEvent('konva:mask-history-changed', {
        bubbles: true,
        detail: {
          historyPointer: this.historyPointer,
          historyLength: this.maskHistory.length,
        },
      })
    );
    console.log(
      'Dispatched konva:mask-history-changed event. Pointer:',
      this.historyPointer,
      'Length:',
      this.maskHistory.length
    );
  }

  setTool(event) {
    const toolName = event.params.tool || 'brush';
    this.currentTool = toolName;
    console.log(`Tool set to: ${this.currentTool}`);

    if (this.crosshairGroup) {
      if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
        this.crosshairGroup.visible(true);
        const crosshairColor = this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : CURSOR_COLOR;
        this.crosshairHorizontal.stroke(crosshairColor);
        this.crosshairVertical.stroke(crosshairColor);
      } else {
        this.crosshairGroup.visible(false);
      }
      this.maskLayer.batchDraw();
    }
  }

  setBrushSizeFromUI(event) {
    this.brushSizeValue = parseInt(event.target.value, 10);
  }

  clearSelection() {
    if (this.maskContext && this.maskContext.canvas) {
      this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      this.maskContext.fillStyle = DEFAULT_MASK;
      this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

      if (this.maskImageNode) {
        this.maskImageNode.image(this.maskContext.canvas);
        this.maskLayer.batchDraw();
      }
      console.log('Selections cleared.');
      this.saveMaskState();
    }
  }

  destroyKonva() {
    if (this.stage) {
      this.stage.destroy();
    }
    this.stage = null;
    this.layer = null;
    this.maskLayer = null;
    this.imageNode = null;
    this.maskContext = null;
    this.maskImageNode = null;
    this.crosshairGroup = null;
    this.crosshairHorizontal = null;
    this.crosshairVertical = null;
    this.maskHistory = [];
    this.historyPointer = -1;
    if (this.hasCanvasContainerTarget) {
      this.canvasContainerTarget.innerHTML = '';
      this.canvasContainerTarget.style.width = '';
      this.canvasContainerTarget.style.height = '';
    }
    console.log('Konva Stage destroyed and resources cleaned.');
  }

  setZoom(scale) {
    if (!this.stage) return;

    const oldScale = this.stage.scaleX();

    // Center the zoom
    // We want the center of the view to remain the center
    const width = this.stage.width();
    const height = this.stage.height();

    // Calculate new position to keep center... centered.
    // However, since we are doing absolute scale setting (not relative zoom),
    // it's easier to just center the 0,0-based content in the view.
    // If the content is at 0,0, its center is width*scale/2, height*scale/2
    // We want that point to be at width/2, height/2 of the stage.
    // So stage.x + width*scale/2 = width/2 => stage.x = width/2 - width*scale/2

    const newX = (width - width * scale) / 2;
    const newY = (height - height * scale) / 2;

    this.stage.scale({ x: scale, y: scale });
    this.stage.position({ x: newX, y: newY });
    this.stage.batchDraw();
    console.log(`Zoom set to ${scale}`);
  }

  getMaskDataURL() {
    if (!this.maskContext || !this.maskContext.canvas || !this.imageNode || !this.imageNode.image()) {
      console.error('Mask canvas, imageNode, or image is not available for generating mask data.');
      return null;
    }

    const originalWidth = this.imageNode.image().naturalWidth;
    const originalHeight = this.imageNode.image().naturalHeight;
    const finalMaskCanvas = document.createElement('canvas');
    finalMaskCanvas.width = originalWidth;
    finalMaskCanvas.height = originalHeight;
    const finalMaskContext = finalMaskCanvas.getContext('2d');

    // scale factor
    const scaleX = originalWidth / this.stage.width();
    const scaleY = originalHeight / this.stage.height();

    // Draw the original mask onto the new canvas, scaling it
    finalMaskContext.drawImage(
      this.maskContext.canvas,
      0,
      0,
      this.maskContext.canvas.width,
      this.maskContext.canvas.height,
      0,
      0,
      originalWidth,
      originalHeight
    );

    // Get the pixel data from the canvas
    const imageData = finalMaskContext.getImageData(0, 0, originalWidth, originalHeight);
    const data = imageData.data;

    // Loop through each pixel
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      // Check if the pixel is green. Note: Anti-aliasing might introduce other colors
      // Simple Green check: Green is dominant
      if (g > 100 && g > r && g > b) {
        // Convert green to true violet (#7F00FF)
        data[i] = 127; // R
        data[i + 1] = 0; // G
        data[i + 2] = 255; // B
        data[i + 3] = 255; // Alpha
      } else {
        // Convert everything else to white
        data[i] = 255;
        data[i + 1] = 255;
        data[i + 2] = 255;
        data[i + 3] = 255;
      }
    }

    // Put the modified pixel data back onto the canvas
    finalMaskContext.putImageData(imageData, 0, 0);

    return finalMaskCanvas.toDataURL('image/png');
  }
}
