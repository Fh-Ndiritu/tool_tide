// app/javascript/controllers/upload_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['fileInput', 'dropZone', 'progressBarContainer', 'progressBar', 'form', 'deviceWidthInput'];

  MAX_UPLOAD_IMAGE_WIDTH = 1024;
  MAX_UPLOAD_IMAGE_HEIGHT = 1024;

  // --- File Input Handlers ---
  triggerFileInput() {
    this.fileInputTarget.click();
  }

  preventDefault(event) {
    event.preventDefault();
    event.stopPropagation();
    // Optional: Add/remove classes for visual feedback on dragover/dragenter
  }

  drop(event) {
    this.preventDefault(event); // Prevent default browser behavior (opening file)
    const files = event.dataTransfer.files;
    if (files.length > 0) {
      this.fileInputTarget.files = files; // Assign files to the hidden input
      this.handleFileChange(); // Trigger the processing logic
    }
  }

  // Handles drag over event for visual feedback
  dragOver(event) {
    event.preventDefault();
    event.stopPropagation();
    this.dropZoneTarget.classList.add('border-dashed', 'border-primary', 'border-2');
  }

  // Handles drag leave event to remove visual feedback
  dragLeave() {
    this.dropZoneTarget.classList.remove('border-dashed', 'border-primary', 'border-2');
  }

  async handleFileChange() {
    const files = this.fileInputTarget.files;
    if (files.length === 0) {
      return;
    }

    const originalFile = files[0];
    // this.showProgressBar();

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

      // Attempt to resize image for upload to the fixed MAX_UPLOAD_IMAGE_WIDTH/HEIGHT.
      // This is for optimizing the file sent to the server to a consistent max size.
      try {
        const resizedForUploadDataURL = await this._resizeImage(
          originalFile,
          this.MAX_UPLOAD_IMAGE_WIDTH, // Use the fixed constant for upload resize
          this.MAX_UPLOAD_IMAGE_HEIGHT, // Use the fixed constant for upload resize
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
}
