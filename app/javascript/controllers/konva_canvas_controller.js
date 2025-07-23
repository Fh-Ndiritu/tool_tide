// app/javascript/controllers/konva_canvas_controller.js
import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="konva-canvas"
export default class extends Controller {
  static targets = [
    'canvasContainer', // The div where Konva stage will be rendered
    // No direct UI targets here; they will be handled by the parent controller
  ];

  static values = {
    imageUrl: String, // The Data URL of the image to load
    displayWidth: Number, // Calculated display width for the canvas
    displayHeight: Number, // Calculated display height for the canvas
    brushSize: { type: Number, default: 40 }, // Initial brush size
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
  // New property for the cursor circle
  cursorCircle = null;

  maskHistory = [];
  historyPointer = -1;
  MAX_HISTORY_STATES = 10; // Max states to keep in history

  connect() {
    console.log('Konva Canvas Controller connected.');
    console.log('Image URL:', this.imageUrlValue);
    console.log('Display Width:', this.displayWidthValue);
    console.log('Display Height:', this.displayHeightValue);

    // Always try to initialize Konva if we have the dimensions.
    // This ensures that even if imageUrl isn't immediately available,
    // the stage is prepared for when it does arrive (e.g., via a value change).
    if (
      this.hasDisplayWidthValue &&
      this.hasDisplayHeightValue &&
      this.displayWidthValue > 0 &&
      this.displayHeightValue > 0
    ) {
      this.initializeKonva();
    } else {
      console.warn('Initial displayWidth or displayHeight not valid. Konva stage will not be initialized immediately.');
    }

    // --- IMPORTANT CHANGE HERE ---
    // Defer loadImage call to ensure DOM has settled after initialization
    // requestAnimationFrame is generally preferred for rendering-related tasks
    // as it runs just before the browser's next repaint.
    requestAnimationFrame(() => {
      if (this.hasImageUrlValue && this.imageUrlValue && this.stage) {
        this.loadImage(this.imageUrlValue);
      } else {
        console.log('Image URL not yet set, or Konva stage not ready after RAF. Skipping initial image load.');
      }
    });
  }

  disconnect() {
    console.log('Konva Canvas Controller disconnected.');
    this.destroyKonva();
  }

  // Called when displayWidthValue changes
  displayWidthValueChanged() {
    // Check for stage existence and dimension changes
    if (
      this.stage &&
      (this.stage.width() !== this.displayWidthValue || this.stage.height() !== this.displayHeightValue)
    ) {
      console.log('Konva stage dimensions changed, re-initializing.');
      this.initializeKonva(); // Re-initialize Konva with new dimensions

      // After re-initialization, if an image URL exists, load it
      if (this.hasImageUrlValue && this.imageUrlValue) {
        // Defer loadImage after re-initialization as well
        requestAnimationFrame(() => {
          this.loadImage(this.imageUrlValue);
        });
      }
    }
  }

  // Called when displayHeightValue changes
  displayHeightValueChanged() {
    // Similar logic as displayWidthValueChanged to avoid duplication,
    // you could abstract this if multiple valueChange methods trigger the same re-init/reload.
    if (
      this.stage &&
      (this.stage.width() !== this.displayWidthValue || this.stage.height() !== this.displayHeightValue)
    ) {
      console.log('Konva stage dimensions changed, re-initializing.');
      this.initializeKonva();

      if (this.hasImageUrlValue && this.imageUrlValue) {
        requestAnimationFrame(() => {
          this.loadImage(this.imageUrlValue);
        });
      }
    }
  }

  // Called when brushSizeValue changes
  brushSizeValueChanged() {
    this.brushSize = this.brushSizeValue;
    // Update the cursor circle size if it exists
    if (this.cursorCircle) {
      this.cursorCircle.radius(this.brushSizeValue / 2);
      this.maskLayer.batchDraw();
    }
  }

  initializeKonva() {
    if (
      !this.hasDisplayWidthValue ||
      !this.hasDisplayHeightValue ||
      this.displayWidthValue <= 0 ||
      this.displayHeightValue <= 0
    ) {
      console.warn('Cannot initialize Konva: displayWidth or displayHeight values are not valid.');
      return;
    }

    if (this.stage) {
      console.log('Destroying existing Konva stage for re-initialization.');
      this.stage.destroy();
      this.stage = null;
      this.layer = null;
      this.maskLayer = null;
      this.imageNode = null;
      this.maskContext = null;
      this.maskImageNode = null;
      this.cursorCircle = null; // Reset cursor circle
    }

    const container = this.canvasContainerTarget;
    container.style.width = `${this.displayWidthValue}px`;
    container.style.height = `${this.displayHeightValue}px`;
    container.style.maxWidth = '100%';
    container.style.margin = '0 auto';
    container.style.overflow = 'hidden';
    container.innerHTML = '';

    this.stage = new Konva.Stage({
      container: container,
      width: this.displayWidthValue,
      height: this.displayHeightValue,
    });

    this.layer = new Konva.Layer();
    this.stage.add(this.layer);

    this.maskLayer = new Konva.Layer();
    this.stage.add(this.maskLayer);

    const maskCanvas = document.createElement('canvas');
    maskCanvas.width = this.displayWidthValue;
    maskCanvas.height = this.displayHeightValue;
    this.maskContext = maskCanvas.getContext('2d');
    this.maskContext.fillStyle = 'white';
    this.maskContext.fillRect(0, 0, this.displayWidthValue, this.displayHeightValue);

    this.maskImageNode = new Konva.Image({
      image: maskCanvas,
      x: 0,
      y: 0,
      opacity: 0.4,
    });
    this.maskLayer.add(this.maskImageNode);

    // Initialize cursor circle
    this.cursorCircle = new Konva.Circle({
      radius: this.brushSizeValue / 2,
      fill: 'rgba(0,128,0, 0.7)', // Same color as brush stroke
      listening: false, // Make sure it doesn't interfere with drawing events
      visible: false, // Initially hidden
    });
    this.maskLayer.add(this.cursorCircle);

    this.setupDrawingEvents();
    this.resetMaskHistory();
    this.saveMaskState();
    console.log(`Konva Stage initialized with dimensions: ${this.displayWidthValue}x${this.displayHeightValue}`);
  }

  // --- Image Loading for Canvas Display ---
  loadImage(imageDataURL) {
    if (!this.stage) {
      console.error('loadImage called but Konva stage is not initialized.');
      // This log should ideally not appear with the requestAnimationFrame fix.
      return;
    }

    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'Anonymous';
      img.onload = () => {
        if (this.imageNode) {
          this.imageNode.destroy();
        }
        this.imageNode = new Konva.Image({
          image: img,
          x: 0,
          y: 0,
          width: this.stage.width(),
          height: this.stage.height(),
          draggable: false,
        });

        this.layer.add(this.imageNode);
        this.layer.batchDraw();
        this.resetMaskHistory();
        this.saveMaskState();
        console.log('Image loaded onto Konva canvas.');
        resolve();
      };
      img.onerror = (e) => {
        console.error('Failed to load image onto Konva canvas.', e);
        reject(new Error('Failed to load image onto Konva canvas.'));
      };
      img.src = imageDataURL;
    });
  }

  // --- Drawing and Selection Logic ---
  setupDrawingEvents() {
    if (this.stage) {
      this.stage.on('mousedown touchstart', this._handleMouseDown.bind(this));
      this.stage.on('mousemove touchmove', this._handleMouseMove.bind(this));
      this.stage.on('mouseup touchend', this._handleMouseUp.bind(this));
      // Add events for cursor visibility
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
    if (this.cursorCircle && (this.currentTool === 'brush' || this.currentTool === 'eraser')) {
      this.cursorCircle.visible(true);
      this.maskLayer.batchDraw();
    }
  }

  _handleMouseLeave() {
    if (this.cursorCircle) {
      this.cursorCircle.visible(false);
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
    this.maskContext.strokeStyle = 'green';
    this.maskContext.lineWidth = this.brushSizeValue;
    this.maskContext.lineJoin = 'round';
    this.maskContext.lineCap = 'round';

    if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
      this.maskContext.beginPath();
      this.maskContext.moveTo(x, y);
      this.lastLine = new Konva.Line({
        points: [x, y],
        stroke: this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : 'rgba(0,128,0, 0.7)',
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
        fill: 'rgba(0,128,0, 0.7)',
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
      // Hide cursor if pointer is not available (e.g., mouse moved off stage quickly)
      if (this.cursorCircle) {
        this.cursorCircle.visible(false);
        this.maskLayer.batchDraw();
      }
      return;
    }

    const { x, y } = this._getRelativePointerPosition(pos);

    // Update cursor circle position and visibility
    if (this.cursorCircle && (this.currentTool === 'brush' || this.currentTool === 'eraser')) {
      this.cursorCircle.x(x);
      this.cursorCircle.y(y);
      this.cursorCircle.visible(true);
      // Set fill color based on tool
      this.cursorCircle.fill(this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : 'rgba(0,128,0, 0.7)');
    } else if (this.cursorCircle) {
      // Hide cursor if tool is not brush or eraser
      this.cursorCircle.visible(false);
    }

    if (!this.isDrawing) {
      this.maskLayer.batchDraw(); // Only redraw for cursor movement if not drawing
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
      this.maskContext.fillStyle = 'green';
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

  // --- Undo/Redo Logic ---
  resetMaskHistory() {
    this.maskHistory = [];
    this.historyPointer = -1;
    // Clear mask canvas to white
    if (this.maskContext) {
      this.maskContext.clearRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);
      this.maskContext.fillStyle = 'white';
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

    // If we're not at the end of history (meaning undo was performed),
    // truncate history from current pointer + 1
    if (this.historyPointer < this.maskHistory.length - 1) {
      this.maskHistory = this.maskHistory.slice(0, this.historyPointer + 1);
    }

    const dataURL = this.maskContext.canvas.toDataURL();
    this.maskHistory.push(dataURL);

    // Enforce MAX_HISTORY_STATES, shifting if necessary
    if (this.maskHistory.length > this.MAX_HISTORY_STATES) {
      this.maskHistory.shift();
      // If we shifted, the pointer's *index* needs to be decremented to point to the same state
      // This is crucial only if the pointer was not already at the last element
      // However, after a push, pointer should always be at the last element regardless of shift.
      // So, simpler to just set it.
    }

    // Always ensure pointer points to the last (newly added) state
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
    this._dispatchHistoryChangeEvent(); // Always dispatch after attempting an action
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
    this._dispatchHistoryChangeEvent(); // Always dispatch after attempting an action
  }

  _dispatchHistoryChangeEvent() {
    // IMPORTANT: Dispatch the event on the element that the parent controller is listening to.
    // In editor_controller.js, it's listening on this.konvaCanvasWrapperTarget.
    // Since konva-canvas controller is mounted ON konvaCanvasWrapperTarget,
    // this.element refers to the correct element.
    this.element.dispatchEvent(
      new CustomEvent('konva:mask-history-changed', {
        bubbles: true, // Allow event to bubble up to parent controllers
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

  // --- Tool Management (actions that can be called from parent controller) ---
  setTool(event) {
    const toolName = event.params.tool || 'brush';
    this.currentTool = toolName;
    console.log(`Tool set to: ${this.currentTool}`);

    // Update cursor visibility based on the new tool
    if (this.cursorCircle) {
      if (this.currentTool === 'brush' || this.currentTool === 'eraser') {
        this.cursorCircle.visible(true);
        // Ensure cursor color matches the tool
        this.cursorCircle.fill(this.currentTool === 'eraser' ? 'rgba(255,255,255, 0.7)' : 'rgba(0,128,0, 0.7)');
      } else {
        this.cursorCircle.visible(false);
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
      this.maskContext.fillStyle = 'white';
      this.maskContext.fillRect(0, 0, this.maskContext.canvas.width, this.maskContext.canvas.height);

      if (this.maskImageNode) {
        this.maskImageNode.image(this.maskContext.canvas);
        this.maskLayer.batchDraw();
      }
      console.log('Selections cleared.');
      this.saveMaskState(); // Save state after clearing
    }
  }

  // --- Mask Data Generation ---
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

    // Draw the current state of the display mask onto the finalMaskCanvas,
    // scaling it to the original image's dimensions
    finalMaskContext.drawImage(
      this.maskContext.canvas,
      0,
      0,
      this.maskContext.canvas.width, // Source width (display canvas)
      this.maskContext.canvas.height, // Source height (display canvas)
      0,
      0,
      originalWidth, // Destination width (original image size)
      originalHeight // Destination height (original image size)
    );

    this._convertGreenToBlack(finalMaskCanvas, finalMaskContext);

    return finalMaskCanvas.toDataURL('image/png');
  }

  _convertGreenToBlack(canvas, context) {
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;

    for (let i = 0; i < data.length; i += 4) {
      const red = data[i];
      const green = data[i + 1];
      const blue = data[i + 2];
      const alpha = data[i + 3];

      // Convert semi-transparent green (from opacity 0.4) to fully opaque black
      // and everything else to fully opaque white.
      // A common way to check for drawn "green" on a white background:
      // If red and blue are significantly lower than green, or if it's not pure white.
      // Consider the opacity that was applied (0.4), so the actual green component on the canvas
      // would be `green_color * 0.4 + white_background * 0.6`.
      // A simpler check might be if it's not near white.
      if (red < 200 || green < 200 || blue < 200) {
        // If it's not predominantly white
        // Check for 'green-ish' color that was drawn.
        // This threshold might need adjustment depending on your exact green and background.
        // If the drawn color is R:0, G:128, B:0, with 0.4 opacity on white (255,255,255),
        // the resulting pixel would be:
        // R: 0*0.4 + 255*0.6 = 153
        // G: 128*0.4 + 255*0.6 = 51.2 + 153 = 204.2
        // B: 0*0.4 + 255*0.6 = 153
        // So, (153, 204, 153) roughly.
        if (green > red + 20 && green > blue + 20) {
          // If green is significantly higher than red/blue
          data[i] = 0; // Red
          data[i + 1] = 0; // Green
          data[i + 2] = 0; // Blue
          data[i + 3] = 255; // Alpha (fully opaque black)
        } else {
          // Everything else becomes white
          data[i] = 255;
          data[i + 1] = 255;
          data[i + 2] = 255;
          data[i + 3] = 255;
        }
      } else {
        // Pure white pixels remain white
        data[i] = 255;
        data[i + 1] = 255;
        data[i + 2] = 255;
        data[i + 3] = 255;
      }
    }
    context.putImageData(imageData, 0, 0);
  }

  // --- Cleanup ---
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
    this.cursorCircle = null; // Ensure cursor circle is cleaned up
    this.maskHistory = [];
    this.historyPointer = -1;
    if (this.hasCanvasContainerTarget) {
      this.canvasContainerTarget.innerHTML = '';
      this.canvasContainerTarget.style.width = '';
      this.canvasContainerTarget.style.height = '';
    }
    console.log('Konva Stage destroyed and resources cleaned.');
  }
}
