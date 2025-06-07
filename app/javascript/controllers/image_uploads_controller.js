// app/javascript/controllers/image_uploads_controller.js
import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="image-uploads"
export default class extends Controller {
  static targets = ['input', 'preview', 'inputTrigger', 'submit', 'contentWrapper', 'form']; // Added 'form' target

  // Internal array to keep track of files selected for upload
  // This is necessary because FileList objects are immutable.
  allFiles = [];
  maxImages = 10; // New: Define the maximum number of images allowed

  connect() {
    console.log('ImageUploads controller connected.');
    // When file is attached, we run handleFileChange function
    this.inputTarget.addEventListener('change', this.handleFileChange.bind(this));

    // Simulate click on hidden file input when trigger button is clicked
    this.inputTriggerTarget.addEventListener('click', () => {
      this.inputTarget.click();
    });

    // Add drag and drop event listeners to the designated contentWrapper element
    this.contentWrapperTarget.addEventListener('dragover', this.handleDragOver.bind(this));
    this.contentWrapperTarget.addEventListener('dragleave', this.handleDragLeave.bind(this));
    this.contentWrapperTarget.addEventListener('drop', this.handleDrop.bind(this));

    // Add paste event listener to the designated contentWrapper element
    this.contentWrapperTarget.addEventListener('paste', this.handlePaste.bind(this));

    // New: Intercept form submission
    this.formTarget.addEventListener('submit', this.handleSubmit.bind(this));

    // Initialize submit button and preview visibility
    this.updateSubmitButtonVisibility();
  }

  // Generates a unique ID for a file to check for duplicates
  _getFileId(file) {
    return `${file.name}-${file.size}-${file.lastModified}`;
  }

  // Handles adding new files from any source (input, drag/drop, paste)
  addFiles(newFiles) {
    const currentFileIds = new Set(this.allFiles.map((file) => this._getFileId(file)));
    const imageFiles = newFiles.filter((file) => file.type.startsWith('image/'));

    const filesToAdd = [];

    imageFiles.forEach((file) => {
      const fileId = this._getFileId(file);
      // New: Check for duplicates and max image limit
      if (!currentFileIds.has(fileId) && this.allFiles.length + filesToAdd.length < this.maxImages) {
        filesToAdd.push(file);
        currentFileIds.add(fileId); // Add to set to prevent subsequent duplicates within the same batch
      } else if (currentFileIds.has(fileId)) {
        console.warn(`Skipped duplicate file: ${file.name}`);
      } else if (this.allFiles.length + filesToAdd.length >= this.maxImages) {
        console.warn(`Skipped ${file.name}: Maximum of ${this.maxImages} images already selected.`);
      }
    });

    this.allFiles = this.allFiles.concat(filesToAdd); // Append only unique and allowed files

    // New: If no files were added and there are existing files, don't hide preview unnecessarily
    if (this.allFiles.length > 0) {
      this.showPreview(); // Show the preview section when files are added
    }

    this.renderPreviews(); // Render all current files in the preview
    // No longer need to update `inputTarget.files` here for submission, as we'll use FormData
    this.updateSubmitButtonVisibility(); // Show the submit button
  }

  // New: Handles the form submission
  async handleSubmit(event) {
    event.preventDefault(); // Prevent default form submission

    if (this.allFiles.length === 0) {
      console.warn('No images selected for upload.');
      return;
    }

    const formData = new FormData(this.formTarget); // Initialize with existing form data (like authenticity token)

    // Append each image file to the FormData
    this.allFiles.forEach((file) => {
      formData.append('images[]', file); // Use 'images[]' to match Rails' expected array parameter
    });

    // Disable submit button and show loading state if desired
    this.submitTarget.disabled = true;
    this.submitTarget.textContent = 'Uploading...'; // Or add a spinner

    try {
      const response = await fetch(this.formTarget.action, {
        method: this.formTarget.method,
        body: formData,
        // Don't set Content-Type header; fetch will set it correctly for FormData
      });

      if (response.ok) {
        const result = await response.json(); // Assuming JSON response from Rails
        console.log('Upload successful:', result);
        // Clear files and hide preview after successful upload
        this.allFiles = [];
        this.renderPreviews();
        this.updateSubmitButtonVisibility();
        // You might want to display a success message to the user
      } else {
        const errorData = await response.json(); // Assuming JSON error response
        console.error('Upload failed:', response.status, errorData);
        // Display an error message to the user
      }
    } catch (error) {
      console.error('Network error during upload:', error);
      // Display a network error message
    } finally {
      // Re-enable submit button
      this.submitTarget.disabled = false;
      this.submitTarget.textContent = 'Upload';
    }
  }

  // Shows the preview area and makes it visible
  showPreview() {
    this.contentWrapperTarget.classList.add('preview-visible');
    this.contentWrapperTarget.classList.remove('preview-hidden');
    this.previewTarget.classList.remove('hidden');
  }

  // Hides the preview area when no images are selected
  hidePreview() {
    this.contentWrapperTarget.classList.remove('preview-visible');
    this.contentWrapperTarget.classList.add('preview-hidden');
    this.previewTarget.classList.add('hidden');
  }

  // Handles the change event from the file input
  handleFileChange(event) {
    this.addFiles(Array.from(event.target.files));
    // Clear the input's files after processing to allow selecting the same file again
    // (though our internal logic will prevent duplicates)
    event.target.value = '';
  }

  // Handles drag over event for visual feedback
  handleDragOver(event) {
    event.preventDefault(); // Prevent default to allow drop
    event.stopPropagation();
    // Apply visual indicator to the contentWrapper
    this.contentWrapperTarget.classList.add('border-dashed', 'border-primary', 'border-2');
  }

  // Handles drag leave event to remove visual feedback
  handleDragLeave() {
    // Remove visual indicator from the contentWrapper
    this.contentWrapperTarget.classList.remove('border-dashed', 'border-primary', 'border-2');
  }

  // Handles drop event to process dropped files
  handleDrop(event) {
    event.preventDefault(); // Prevent default to get files from dataTransfer
    event.stopPropagation();
    // Remove visual indicator from the contentWrapper
    this.contentWrapperTarget.classList.remove('border-dashed', 'border-primary', 'border-2');

    const droppedFiles = Array.from(event.dataTransfer.files);
    this.addFiles(droppedFiles);
  }

  // Handles paste event to process pasted images
  handlePaste(event) {
    // Check if there are any items in the clipboard
    if (event.clipboardData && event.clipboardData.items) {
      const pastedFiles = [];
      for (let i = 0; i < event.clipboardData.items.length; i++) {
        const item = event.clipboardData.items[i];
        // If the item is an image, get it as a File object
        if (item.type.startsWith('image/')) {
          pastedFiles.push(item.getAsFile());
        }
      }
      if (pastedFiles.length > 0) {
        this.addFiles(pastedFiles);
        event.preventDefault(); // Prevent default paste behavior if images are handled
      }
    }
  }

  // Helper function to format file size into a human-readable string
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  // Renders all images currently in the allFiles array to the preview container
  renderPreviews() {
    const previewContainer = this.previewTarget;
    previewContainer.innerHTML = ''; // Clear existing previews before re-rendering
    previewContainer.classList.add('flex', 'flex-wrap', 'gap-4', 'mt-4'); // Ensure flex display for cards

    if (this.allFiles.length === 0) {
      previewContainer.classList.remove('flex', 'flex-wrap', 'gap-4', 'mt-4'); // Remove flex if no files
      return;
    }

    // Create an unordered list to hold image cards
    const ul = document.createElement('ul');
    ul.classList.add('flex', 'flex-wrap', 'gap-4', 'w-full'); // Flex wrap for the ul itself

    this.allFiles.forEach((file, index) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const li = document.createElement('li');
        li.classList.add(
          'flex',
          'items-center',
          'space-x-3',
          'p-3',
          'bg-white',
          'rounded-xl',
          'shadow-md',
          'border',
          'border-gray-200',
          'flex-shrink-0' // Ensure cards don't shrink too much
        );

        // Image element
        const img = document.createElement('img');
        img.src = e.target.result;
        img.classList.add('w-16', 'h-16', 'object-cover', 'rounded-lg', 'border', 'border-gray-300');
        img.alt = file.name;

        // Container for file name and size
        const infoContainer = document.createElement('div');
        infoContainer.classList.add('flex', 'flex-col', 'justify-center', 'flex-grow');

        // File name element
        const fileNameSpan = document.createElement('span');
        fileNameSpan.classList.add('text-sm', 'font-medium', 'text-gray-800', 'truncate', 'max-w-[120px]'); // Truncate long names
        fileNameSpan.textContent = file.name;

        // File size element
        const fileSizeSpan = document.createElement('span');
        fileSizeSpan.classList.add('text-xs', 'text-gray-500');
        fileSizeSpan.textContent = this.formatFileSize(file.size);

        // Append name and size to info container
        infoContainer.appendChild(fileNameSpan);
        infoContainer.appendChild(fileSizeSpan);

        // Delete button (icon)
        const deleteButton = document.createElement('button');
        deleteButton.type = 'button'; // Important for forms
        deleteButton.classList.add(
          'text-gray-500',
          'hover:text-red-600',
          'focus:outline-none',
          'transition-colors',
          'duration-200',
          'p-1',
          'rounded-full',
          'hover:bg-gray-100',
          'ml-auto' // Push delete button to the right
        );
        deleteButton.setAttribute('data-action', 'click->image-uploads#removeImage');
        deleteButton.setAttribute('data-index', index); // Store index to identify which file to remove

        // SVG for delete icon (simple 'x' icon)
        deleteButton.innerHTML = `
          <svg class="w-5 h-5 cursor-pointer" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        `;

        // Append elements to the list item
        li.appendChild(img);
        li.appendChild(infoContainer); // Append the new info container
        li.appendChild(deleteButton);
        ul.appendChild(li);
      };
      reader.readAsDataURL(file);
    });
    previewContainer.appendChild(ul);
  }

  // Removes an image from the preview and the internal file list
  removeImage(event) {
    const indexToRemove = parseInt(event.currentTarget.dataset.index, 10);
    if (isNaN(indexToRemove) || indexToRemove < 0 || indexToRemove >= this.allFiles.length) {
      console.warn('Attempted to remove image with invalid index.');
      return;
    }

    // Remove the file from our internal array
    this.allFiles.splice(indexToRemove, 1);

    this.renderPreviews(); // Re-render the entire preview to update indices
    this.updateFileInput(); // Update the actual file input's FileList
    this.updateSubmitButtonVisibility(); // Update submit button visibility
  }

  // This function is no longer solely for updating the hidden file input's files property.
  // It's still used to keep the `inputTarget.files` consistent with `allFiles`,
  // which might be useful for other browser behaviors, even if not directly for form submission.
  updateFileInput() {
    const dataTransfer = new DataTransfer();
    this.allFiles.forEach((file) => dataTransfer.items.add(file));
    this.inputTarget.files = dataTransfer.files;
  }

  // Controls the visibility of the submit button
  // Also hides the preview if there are no files
  updateSubmitButtonVisibility() {
    if (this.allFiles.length > 0) {
      this.submitTarget.classList.remove('hidden');
    } else {
      this.hidePreview(); // Hide the preview if no files are present
      this.submitTarget.classList.add('hidden');
    }
  }
}
