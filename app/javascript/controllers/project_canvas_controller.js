// app/javascript/controllers/konva_canvas_controller.js
import { Controller } from '@hotwired/stimulus';

const GREEN_COLOR = 'rgba(100 245 3 / 0.5)';
const MASK_COLOR = 'rgba(100, 245, 3, 1)';
const DEFAULT_MASK = 'rgba(12, 12, 12, 0)';
const CURSOR_COLOR = '#00fff7'; // New constant for the cursor color

export default class extends Controller {
  static targets = ['canvasContainer'];

  static values = {
    imageUrl: String,
    displayWidth: Number,
    displayHeight: Number,
    brushSize: { type: Number, default: 60 },
    layerId: Number,
  };

  get scaledBrushSize() {
    if (!this.worldHeight) return this.brushSizeValue;
    // 150 (max slider) = 20% of image height
    const maxBrushSize = this.worldHeight * 0.2;
    return (this.brushSizeValue / 150) * maxBrushSize;
  }

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
  crosshairVertical = null;
  brushHint = null;
  brushHintVisible = false;

  maskHistory = [];
  historyPointer = -1;
  MAX_HISTORY_STATES = 10;

  resizeObserver = null;

  connect() {
    console.log('Konva Canvas Controller connected.');

    this._boundHandleMouseUp = this._handleMouseUp.bind(this);
    this._boundHandleWheel = this._handleWheel.bind(this);
    this._boundHandleKeydown = this._handleKeydown.bind(this);

    // Add global event listeners for shortcuts
    window.addEventListener('keydown', this._boundHandleKeydown);
    // Add wheel listener to container (non-passive to prevent default browser zoom)
    this.canvasContainerTarget.addEventListener('wheel', this._boundHandleWheel, { passive: false });

    // Initialize ResizeObserver
    this.resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        if (entry.target === this.canvasContainerTarget) {
             // Use requestAnimationFrame to avoid ResizeObserver loop notification error
             requestAnimationFrame(() => this.resizeStage(entry.contentRect));
        }
      }
    });
    this.resizeObserver.observe(this.canvasContainerTarget);

    // Initial init
    this.initializeKonva();

    requestAnimationFrame(() => {
      if (this.hasImageUrlValue && this.imageUrlValue && this.stage) {
        this.loadImage(this.imageUrlValue);
      }
    });
  }

  disconnect() {
    console.log('Konva Canvas Controller disconnected.');
    window.removeEventListener('keydown', this._boundHandleKeydown);
    if (this.hasCanvasContainerTarget) {
      this.canvasContainerTarget.removeEventListener('wheel', this._boundHandleWheel);
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    this.destroyKonva();
  }

  resizeStage(rect) {
      const width = rect.width;
      const height = rect.height;
      if (!this.stage || width === 0 || height === 0) return;

      this.stage.width(width);
      this.stage.height(height);

      this.fitContentToView();
      this.stage.batchDraw();
  }

  fitContentToView() {
      if (!this.worldWidth || !this.worldHeight) return;

      const stageWidth = this.stage.width();
      const stageHeight = this.stage.height();

      const scaleX = stageWidth / this.worldWidth;
      const scaleY = stageHeight / this.worldHeight;
      const scale = Math.min(scaleX, scaleY); // 100% fit (contain)

      this.stage.scale({ x: scale, y: scale });

      const newWidth = this.worldWidth * scale;
      const newHeight = this.worldHeight * scale;

      const newX = (stageWidth - newWidth) / 2;
      const newY = (stageHeight - newHeight) / 2;

      this.stage.position({
          x: newX,
          y: newY
      });

      this.fitState = {
          scale: scale,
          x: newX,
          y: newY
      };
      this._dispatchTransformChangeEvent();
  }

  // Removed resizeMask as it is no longer needed (mask size is fixed to world size)

  _updateContextConfig() {
      if (!this.maskContext) return;
      this.maskContext.lineJoin = 'round';
      this.maskContext.lineCap = 'round';
  }

  // Removed displayWidth/Height change handlers

  brushSizeValueChanged() {
    if (this.crosshairHorizontal && this.crosshairVertical) {
      const halfBrushSize = this.scaledBrushSize / 2;
      this.crosshairHorizontal.points([-halfBrushSize, 0, halfBrushSize, 0]);
      this.crosshairVertical.points([0, -halfBrushSize, 0, halfBrushSize]);

      // Dynamic thickness based on scaled brush size
      const thickness = Math.max(1.5, Math.sqrt(this.scaledBrushSize) * 0.8);
      this.crosshairHorizontal.strokeWidth(thickness);
      this.crosshairVertical.strokeWidth(thickness);
      if (this.cursorCircle) this.cursorCircle.strokeWidth(Math.max(1, thickness / 2));

      this.maskLayer.batchDraw();
    }
  }

  initializeKonva() {
    const container = this.canvasContainerTarget;
    const rect = container.getBoundingClientRect();
    let width = rect.width;
    let height = rect.height;

    // Fallback logic
    if (width === 0 && this.hasDisplayWidthValue) width = this.displayWidthValue;
    if (height === 0 && this.hasDisplayHeightValue) height = this.displayHeightValue;
    if (width <= 0) width = 800;
    if (height <= 0) height = 600;

    // Use default values for World Dimensions until image loads
    // This prevents 0x0 issues
    this.worldWidth = this.hasDisplayWidthValue ? this.displayWidthValue : 800;
    this.worldHeight = this.hasDisplayHeightValue ? this.displayHeightValue : 600;

    if (this.stage) {
      console.log('Destroying existing Konva stage for re-initialization.');
      this.stage.destroy();
      this.stage = null;
      this.layer = null;
      this.maskLayer = null;
      this.imageNode = null;
      this.maskContext = null;
      this.maskImageNode = null;
      this.crosshairGroup = null;
      this.crosshairVertical = null;
      this.brushHint = null;
    }

    // Ensure container styling for Konva
    // We do NOT set fixed width/height on container style, letting CSS handle it.
    container.style.padding = '0';
    container.style.overflow = 'hidden';
    container.innerHTML = '';

    // Stage is Viewport Size
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
    maskCanvas.width = this.worldWidth;
    maskCanvas.height = this.worldHeight;
    this.maskContext = maskCanvas.getContext('2d');
    this.maskContext.fillStyle = DEFAULT_MASK;
    this.maskContext.fillRect(0, 0, this.worldWidth, this.worldHeight);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      width: this.worldWidth,
      height: this.worldHeight,
      opacity: 0.7, // Set mask opacity to 0.7
    });
    this.maskLayer.add(this.maskImageNode);

    // Fit initial default content
    this.fitContentToView();

    // Pro Cursor Group
    this.crosshairGroup = new Konva.Group({
      listening: false,
      visible: false,
    });

    // Add the new circle
    this.cursorCircle = new Konva.Circle({
      radius: this.scaledBrushSize / 2,
      stroke: CURSOR_COLOR,
      strokeWidth: 1,
      shadowColor: 'black',
      shadowBlur: 2,
      shadowOpacity: 1,
      listening: false,
    });

    this.crosshairHorizontal = new Konva.Line({
      points: [-10, 0, 10, 0],
      stroke: CURSOR_COLOR,
      strokeWidth: 3,
      lineCap: 'butt',
      shadowColor: 'black',
      shadowBlur: 2,
      shadowOpacity: 1,
      listening: false,
    });

    this.crosshairVertical = new Konva.Line({
      points: [0, -10, 0, 10],
      stroke: CURSOR_COLOR,
      strokeWidth: 3,
      lineCap: 'butt',
      shadowColor: 'black',
      shadowBlur: 2,
      shadowOpacity: 1,
      listening: false,
    });

    this.crosshairGroup.add(this.cursorCircle, this.crosshairHorizontal, this.crosshairVertical);
    this.maskLayer.add(this.crosshairGroup);

    // Brush Hint Text
    this.brushHint = new Konva.Text({
      text: 'Draw on Me',
      fontSize: 48,
      fontVariant: 'bold',
      fontFamily: 'system-ui, -apple-system, sans-serif',
      fill: 'white',
      opacity: 0.5, // Increased opacity as requested
      listening: false,
      visible: false
    });
    this.maskLayer.add(this.brushHint);
    this._syncInitialBrushHintVisibility();

    // Hide the default cursor icon
    this.canvasContainerTarget.style.cursor = 'none';

    this.setupDrawingEvents();
    this.resetMaskHistory();
    this.saveMaskState(true);

    // Initial Scale Event
    this._dispatchTransformChangeEvent();

    console.log(`Konva Stage initialized with dimensions: ${this.displayWidthValue}x${this.displayHeightValue}`);
  }

  loadImage(imageDataURL) {
    if (!this.stage) {
      console.error('loadImage called but Konva stage is not initialized.');
      return;
    }

    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'Anonymous';
      img.onload = () => {
        this.worldWidth = img.naturalWidth;
        this.worldHeight = img.naturalHeight;

        // Resize Mask Canvas to match new World Dimensions
        this.maskContext.canvas.width = this.worldWidth;
        this.maskContext.canvas.height = this.worldHeight;
        this.maskContext.fillStyle = DEFAULT_MASK;
        this.maskContext.fillRect(0, 0, this.worldWidth, this.worldHeight);
        this._updateContextConfig(); // Restore context settings

        if (this.imageNode) {
          this.imageNode.destroy();
        }
        this.imageNode = new Konva.Image({
          image: img,
          x: 0,
          y: 0,
          width: this.worldWidth,
          height: this.worldHeight,
          draggable: false,
        });

        // Update Mask Image Node Size
        if (this.maskImageNode) {
            this.maskImageNode.width(this.worldWidth);
            this.maskImageNode.height(this.worldHeight);
        }

        this.layer.add(this.imageNode);
        this.fitContentToView(); // Auto-fit new image
        this.layer.batchDraw();
        this.resetMaskHistory();
        this.saveMaskState(true);
        console.log(`Image loaded ${this.worldWidth}x${this.worldHeight}. Fitted to view.`);
        resolve();
      };
      img.onerror = (e) => {
        console.error('Failed to load image onto Konva canvas.', e);
        reject(new Error('Failed to load image onto Konva canvas.'));
      };
      img.src = imageDataURL;
    });
  }

  setupDrawingEvents() {
    if (this.stage) {
      this.stage.on('mousedown touchstart', this._handleMouseDown.bind(this));
      this.stage.on('mousemove touchmove', this._handleMouseMove.bind(this));
      this.stage.on('mouseup touchend', this._handleMouseUp.bind(this));
      this.stage.on('mouseenter', this._handleMouseEnter.bind(this));
      this.stage.on('mouseleave', this._handleMouseLeave.bind(this));
      this.stage.on('dragmove', this._dispatchTransformChangeEvent.bind(this));
      this.stage.on('dragend', this._dispatchTransformChangeEvent.bind(this));
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

    // Hide hint on first brush
    if (this.brushHint && this.brushHint.visible()) {
      this.brushHint.visible(false);
      this.maskLayer.batchDraw();
    }

    this.isDrawing = true;

    window.addEventListener('mouseup', this._boundHandleMouseUp);
    window.addEventListener('touchend', this._boundHandleMouseUp);

    const pos = this.stage.getPointerPosition();
    if (!pos) return;

    const { x, y } = this._getRelativePointerPosition(pos);

    this.maskContext.globalCompositeOperation = this.currentTool === 'eraser' ? 'destination-out' : 'source-over';
    this.maskContext.strokeStyle = this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : GREEN_COLOR;
    this.maskContext.lineWidth = this.scaledBrushSize;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
      this.lastLine = new Konva.Line({
        points: [x, y],
        stroke: this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : GREEN_COLOR,
        strokeWidth: this.scaledBrushSize,
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
      const halfBrushSize = this.scaledBrushSize / 2;
      this.crosshairHorizontal.points([-halfBrushSize, 0, halfBrushSize, 0]);
      this.crosshairVertical.points([0, -halfBrushSize, 0, halfBrushSize]);

      // Dynamic thickness based on scaled brush size
      const thickness = Math.max(1.5, Math.sqrt(this.scaledBrushSize) * 0.8);
      this.crosshairHorizontal.strokeWidth(thickness);
      this.crosshairVertical.strokeWidth(thickness);
      if (this.cursorCircle) this.cursorCircle.strokeWidth(Math.max(1, thickness / 2));

      this.crosshairGroup.visible(true);
      const crosshairColor = this.currentTool === 'eraser' ? '#FF3333' : CURSOR_COLOR;
      this.crosshairHorizontal.stroke(crosshairColor);
      this.crosshairVertical.stroke(crosshairColor);
      if(this.cursorCircle) this.cursorCircle.stroke(crosshairColor);
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
    if (!this.isDrawing) return;
    this.isDrawing = false;

    window.removeEventListener('mouseup', this._boundHandleMouseUp);
    window.removeEventListener('touchend', this._boundHandleMouseUp);

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
    this.saveMaskState(false);
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

  saveMaskState(isEmpty = false) {
    if (!this.maskContext) return;

    if (this.historyPointer < this.maskHistory.length - 1) {
      this.maskHistory = this.maskHistory.slice(0, this.historyPointer + 1);
    }

    const dataURL = this.maskContext.canvas.toDataURL();
    this.maskHistory.push({ dataURL, isEmpty });

    if (this.maskHistory.length > this.MAX_HISTORY_STATES) {
      this.maskHistory.shift();
    }

    this.historyPointer = this.maskHistory.length - 1;
    console.log('Mask state saved. History size:', this.maskHistory.length, 'Pointer:', this.historyPointer, 'Empty:', isEmpty);
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
      const originalCompositeOperation = this.maskContext.globalCompositeOperation;
      this.maskContext.globalCompositeOperation = 'source-over';
      this.maskContext.drawImage(img, 0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      this.maskContext.globalCompositeOperation = originalCompositeOperation;

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
      const entry = this.maskHistory[this.historyPointer];
      if (entry) {
        this.applyMaskState(entry.dataURL);
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
      const entry = this.maskHistory[this.historyPointer];
      if (entry) {
        this.applyMaskState(entry.dataURL);
      }
      console.log('Redo performed. History Pointer:', this.historyPointer);
    } else {
      console.log('Cannot redo: Already at the end of history.');
    }
    this._dispatchHistoryChangeEvent();
  }

  _dispatchHistoryChangeEvent() {
    const currentEntry = this.maskHistory[this.historyPointer];
    const isEmpty = currentEntry ? currentEntry.isEmpty : true;

    this.element.dispatchEvent(
      new CustomEvent('konva:mask-history-changed', {
        bubbles: true,
        detail: {
          historyPointer: this.historyPointer,
          historyLength: this.maskHistory.length,
          isEmpty: isEmpty,
        },
      })
    );
    console.log(
      'Dispatched konva:mask-history-changed event. Pointer:',
      this.historyPointer,
      'Length:',
      this.maskHistory.length,
      'isEmpty:',
      isEmpty
    );
  }

  setTool(event) {
    const toolName = event.params.tool || 'brush';
    this.currentTool = toolName;
    console.log(`Tool set to: ${this.currentTool}`);

    if (this.stage) {
       this.stage.draggable(this.currentTool === 'pan');

       if (this.currentTool === 'pan') {
         this.canvasContainerTarget.style.cursor = 'grab';
       } else {
         this.canvasContainerTarget.style.cursor = 'none';
       }
    }

    if (this.crosshairGroup) {
      if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
        this.crosshairGroup.visible(true);
        const crosshairColor = this.currentTool === 'eraser' ? '#FF3333' : CURSOR_COLOR;
        this.crosshairHorizontal.stroke(crosshairColor);
        this.crosshairVertical.stroke(crosshairColor);
        if(this.cursorCircle) this.cursorCircle.stroke(crosshairColor);
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
      this.saveMaskState(true);
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

    // Draw the original mask onto the new canvas
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

      // Check if the pixel is green (green channel is dominant)
      if (g > 100 && g > r && g > b) {
        // Convert green to true violet (#7F00FF)
        data[i] = 127; // R (true violet)
        data[i + 1] = 0; // G (true violet)
        data[i + 2] = 255; // B (true violet)
        data[i + 3] = 255; // Alpha (fully opaque)
      } else {
        // Convert everything else to white
        data[i] = 255; // R
        data[i + 1] = 255; // G
        data[i + 2] = 255; // B
        data[i + 3] = 255; // Alpha (fully opaque)
      }
    }

    // Put the modified pixel data back onto the canvas
    finalMaskContext.putImageData(imageData, 0, 0);

    // Return the modified canvas as a data URL
    return finalMaskCanvas.toDataURL('image/png');
  }

  _handleKeydown(e) {
    if (!this.stage) return;

    const isCmdOrCtrl = e.metaKey || e.ctrlKey;

    // Zoom In: Cmd + "+" or Cmd + "="
    if (isCmdOrCtrl && (e.key === '+' || e.key === '=')) {
      e.preventDefault();
      this.zoomIn();
    }

    // Zoom Out: Cmd + "-"
    if (isCmdOrCtrl && e.key === '-') {
      e.preventDefault();
      this.zoomOut();
    }

    // Reset Zoom: Cmd + "0"
    if (isCmdOrCtrl && e.key === '0') {
      e.preventDefault();
      this.resetZoom();
    }
  }

  _handleWheel(e) {
    if (!this.stage) return;

    // Check for Cmd/Ctrl key for zooming (standard behavior in many design tools)
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();

      const oldScale = this.stage.scaleX();
      const pointer = this.stage.getPointerPosition();

      if (!pointer) return;

      const scaleBy = 1.05;
      const direction = e.deltaY > 0 ? -1 : 1;
      const newScale = direction > 0 ? oldScale * scaleBy : oldScale / scaleBy;

      this.setScaleCentered(newScale, pointer);
    }
  }

  setScaleCentered(newScale, centerPoint) {
     const MIN_SCALE = 0.5;
     const MAX_SCALE = 5;
     newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, newScale));

     const oldScale = this.stage.scaleX();

     const mousePointTo = {
       x: (centerPoint.x - this.stage.x()) / oldScale,
       y: (centerPoint.y - this.stage.y()) / oldScale,
     };

     this.stage.scale({ x: newScale, y: newScale });

     const newPos = {
       x: centerPoint.x - mousePointTo.x * newScale,
       y: centerPoint.y - mousePointTo.y * newScale,
     };

     this.stage.position(newPos);

     this.stage.batchDraw();
     this._dispatchTransformChangeEvent();
  }

  zoomIn() {
    this.setScale(this.stage.scaleX() * 1.2);
  }

  zoomOut() {
    this.setScale(this.stage.scaleX() / 1.2);
  }

  resetZoom() {
    if (!this.stage) return;
    this.fitContentToView();
    this.stage.batchDraw();
    this._dispatchTransformChangeEvent();
  }

  setScale(newScale) {
    if (!this.stage) return;

    // Clamp scale relative to fitted state
    let minScale = 0.5;
    let maxScale = 5;

    if (this.fitState && this.fitState.scale > 0) {
      minScale = this.fitState.scale * 0.5; // 50% of fitted size
      maxScale = this.fitState.scale * 5.0; // 500% of fitted size
    }

    newScale = Math.max(minScale, Math.min(maxScale, newScale));

    const oldScale = this.stage.scaleX();

    // Center zoom (simplified: zoom to center of view)
    // To do it properly:
    // pointer = (stage.x, stage.y)
    // newPos = oldPos * (newScale / oldScale) - centerOffset...
    // Let's stick to centering on the viewport center for now.

    const center = {
      x: this.stage.width() / 2,
      y: this.stage.height() / 2,
    };

    const relatedTo = {
      x: (center.x - this.stage.x()) / oldScale,
      y: (center.y - this.stage.y()) / oldScale,
    };

    this.stage.scale({ x: newScale, y: newScale });

    const newPos = {
      x: center.x - relatedTo.x * newScale,
      y: center.y - relatedTo.y * newScale,
    };

    this.stage.position(newPos);
    this.stage.batchDraw();

    this._dispatchTransformChangeEvent();
  }

  _dispatchTransformChangeEvent() {
    if (!this.stage) return;
    const scale = this.stage.scaleX();
    const x = this.stage.x();
    const y = this.stage.y();

    // Determine if we are at the "Reset" / "Fitted" state
    let isReset = false;
    if (this.fitState) {
        // Use a small epsilon for float comparison
        const epsilon = 0.001;
        isReset = Math.abs(scale - this.fitState.scale) < epsilon &&
                  Math.abs(x - this.fitState.x) < 1 && // 1px tolerance for position
                  Math.abs(y - this.fitState.y) < 1;
    } else {
        // Fallback checks if fitState isn't set yet (though it should be initialized early)
        isReset = (scale === 1 && x === 0 && y === 0);
    }

    let relativeScale = 1;
    if (this.fitState && this.fitState.scale > 0) {
      relativeScale = scale / this.fitState.scale;
    }

    this.element.dispatchEvent(
      new CustomEvent('project-canvas:transform-changed', {
        bubbles: true,
        detail: {
          scale: scale,
          relativeScale: relativeScale,
          x: x,
          y: y,
          isReset: isReset
        },
      })
    );
    this._centerBrushHint();
  }

  // --- Brush Hint Logic ---

  updateBrushHintVisibility(activeTabName) {
    if (!this.brushHint) return;

    const shouldShow = ["Style Presets", "SmartFix"].includes(activeTabName.trim());
    this.brushHint.visible(shouldShow);
    this._centerBrushHint();
    this.maskLayer.batchDraw();
  }

  _centerBrushHint() {
    if (!this.brushHint || !this.stage) return;

    const stageWidth = this.stage.width();
    const stageHeight = this.stage.height();
    const scale = this.stage.scaleX();
    const x = this.stage.x();
    const y = this.stage.y();

    // Calculate center in stage coordinates
    // We want the text to stay centered in the viewport even when zoomed/panned
    const centerX = (stageWidth / 2 - x) / scale;
    const centerY = (stageHeight / 2 - y) / scale;

    this.brushHint.setAttrs({
      x: centerX - (this.brushHint.width() / 2),
      y: centerY - (this.brushHint.height() / 2)
    });
  }

  _syncInitialBrushHintVisibility() {
    // Look for the active tab in the DOM
    const activeTab = document.querySelector('[data-tools-target="tab"].text-blue-400');
    if (activeTab) {
      this.updateBrushHintVisibility(activeTab.innerText.trim());
    }
  }

  toggleZoom() {
    if (!this.stage) return;

    const currentScale = this.stage.scaleX();
    const newScale = currentScale === 1 ? 1.5 : 1;

    this.stage.scale({ x: newScale, y: newScale });

    // Optional: Center if zooming out, or follow mouse if zooming in (too complex for now).
    // Just reset position if going back to 1.
    if (newScale === 1) {
      this.stage.position({ x: 0, y: 0 });
    } else {
        // Center zoom relative to stage center
        const width = this.stage.width();
        const height = this.stage.height();
        this.stage.x( - (width * newScale - width) / 2);
        this.stage.y( - (height * newScale - height) / 2);
    }

    this.stage.batchDraw();
    console.log(`Zoom toggled to ${newScale}x`);
    this._dispatchTransformChangeEvent();
  }
}
