// app/javascript/controllers/upload_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['fileInput', 'dropZone', 'progressBarContainer', 'progressBar', 'form'];

  // Maximum dimension for client-side image resizing BEFORE server upload
  MAX_UPLOAD_IMAGE_WIDTH = 1024;
  MAX_UPLOAD_IMAGE_HEIGHT = 1024;

  connect() {
    console.log('Upload Controller connected.');
    this.progressBarContainerTarget.classList.add('hidden'); // Ensure hidden on connect
  }

  // --- File Input Handlers ---
  triggerFileInput() {
    this.fileInputTarget.click();
  }

  preventDefault(event) {
    event.preventDefault();
    event.stopPropagation();
    // Optional: Add/remove classes for visual feedback on dragover/dragenter
  }

  handleDrop(event) {
    this.preventDefault(event); // Prevent default browser behavior (opening file)
    const files = event.dataTransfer.files;
    if (files.length > 0) {
      this.fileInputTarget.files = files; // Assign files to the hidden input
      this.handleFileChange(); // Trigger the processing logic
    }
  }

  async handleFileChange() {
    const files = this.fileInputTarget.files;
    if (files.length === 0) {
      return;
    }

    const originalFile = files[0];
    this.showProgressBar();

    console.log(
      'Processing original file for upload (client-side resize):',
      originalFile.name,
      'Type:',
      originalFile.type,
      'Size:',
      originalFile.size
    );

    try {
      let fileForUpload = originalFile;

      // Attempt to resize image for upload if it's too large
      // This is for optimizing the file sent to the server.
      try {
        const resizedForUploadDataURL = await this._resizeImage(
          originalFile,
          this.MAX_UPLOAD_IMAGE_WIDTH,
          this.MAX_UPLOAD_IMAGE_HEIGHT,
          0.85 // Quality for JPEG/WEBP
        );
        console.log('Image successfully resized for upload.');

        // Convert Data URL back to a File object for the input
        fileForUpload = await this._dataURLtoFile(resizedForUploadDataURL, originalFile.name, originalFile.type);

        // Create a new FileList and assign it to the file input
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(fileForUpload);
        this.fileInputTarget.files = dataTransfer.files;
      } catch (resizeError) {
        console.warn('Image resizing for upload failed, using original file instead:', resizeError);
        // If resizing fails or isn't needed, fileForUpload remains originalFile
      }

      // Automatically submit the form once the file input is updated.
      // This will trigger a Rails redirect or Turbo Stream response to the editor view.
      this.formTarget.submit();
    } catch (error) {
      console.error('File processing for upload failed:', error);
      this.showMessage(`File processing failed: ${error.message}. Please try again.`);
      this.hideProgressBar();
    }
  }

  // --- UI Helpers ---
  showProgressBar() {
    this.progressBarContainerTarget.classList.remove('hidden');
    this.progressBarTarget.style.width = '0%'; // Reset progress bar
  }

  hideProgressBar() {
    this.progressBarContainerTarget.classList.add('hidden');
    this.progressBarTarget.style.width = '0%';
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

  // --- Utility Functions (moved from original controller) ---
  async _resizeImage(file, maxWidth, maxHeight, quality = 0.9) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (readerEvent) => {
        const image = new Image();
        image.onload = () => {
          let width = image.width;
          let height = image.height;

          if (width > maxWidth || height > maxHeight) {
            const aspectRatio = width / height;
            if (width > height) {
              width = maxWidth;
              height = width / aspectRatio;
            } else {
              height = maxHeight;
              width = height * aspectRatio;
            }
            if (width > maxWidth) {
              // Re-check to fit within both bounds
              const scale = maxWidth / width;
              width *= scale;
              height *= scale;
            }
            if (height > maxHeight) {
              // Re-check to fit within both bounds
              const scale = maxHeight / height;
              height *= scale;
              width *= scale;
            }
          }

          const canvas = document.createElement('canvas');
          const ctx = canvas.getContext('2d');
          canvas.width = width;
          canvas.height = height;
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'high';
          ctx.drawImage(image, 0, 0, width, height);

          const mimeType = file.type.startsWith('image/') ? file.type : 'image/png';
          resolve(canvas.toDataURL(mimeType, quality));
        };
        image.onerror = () => reject(new Error('Image loading failed during resize.'));
        image.src = readerEvent.target.result;
      };
      reader.onerror = () => reject(new Error('FileReader failed during resize.'));
      reader.readAsDataURL(file);
    });
  }

  async _dataURLtoFile(dataurl, filename, mimeType) {
    const arr = dataurl.split(',');
    const mime = mimeType || arr[0].match(/:(.*?);/)[1];
    const bstr = atob(arr[1]);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
      u8arr[n] = bstr.charCodeAt(n);
    }
    return new File([u8arr], filename, { type: mime });
  }
}
