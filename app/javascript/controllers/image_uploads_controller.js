// app/javascript/controllers/image_uploads_controller.js
import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="image-uploads"
export default class extends Controller {
  static targets = ['input', 'preview', 'inputTrigger', 'submit', 'contentWrapper'];

  allFiles = [];
  maxImages = 10;

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
      if (!currentFileIds.has(fileId) && this.allFiles.length + filesToAdd.length < this.maxImages) {
        filesToAdd.push(file);
        currentFileIds.add(fileId);
      } else if (currentFileIds.has(fileId)) {
        console.warn(`Skipped duplicate file: ${file.name}`);
      } else if (this.allFiles.length + filesToAdd.length >= this.maxImages) {
        console.warn(`Skipped ${file.name}: Maximum of ${this.maxImages} images already selected.`);
      }
    });

    this.allFiles = this.allFiles.concat(filesToAdd);

    // ************* CRUCIAL: Update the actual file input *************
    // This is the key change. Whenever `allFiles` is updated, we must
    // ensure the `inputTarget.files` property reflects it.
    this.updateFileInput();

    if (this.allFiles.length > 0) {
      this.showPreview();
    }

    this.renderPreviews();
    this.updateSubmitButtonVisibility();
  }

  // Handles the start of a Turbo form submission
  handleTurboSubmitStart() {
    this.submitTarget.disabled = true;
    this.submitTarget.textContent = 'Uploading...';
  }

  // Handles the end of a Turbo form submission (whether success or failure)
  handleTurboSubmitEnd(event) {
    // Re-enable submit button
    this.submitTarget.disabled = false;
    this.submitTarget.textContent = 'Upload';

    if (event.detail.success) {
      console.log('Turbo upload successful!');
      this.allFiles = []; // Clear files on success
      this.renderPreviews(); // Clear previews
      this.updateFileInput(); // Important: Clear the actual file input too!
      this.updateSubmitButtonVisibility();
    } else {
      console.error('Turbo upload failed.');
      // Turbo will handle rendering error responses.
      // You might inspect `event.detail.fetchResponse` for more details if needed
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
    // When files are selected via the file input, they are initially in event.target.files.
    // We add them to allFiles, and then updateFileInput will push them back to inputTarget.files.
    this.addFiles(Array.from(event.target.files));
    // No need to clear event.target.value here; updateFileInput handles it
  }

  // Handles drag over event for visual feedback
  handleDragOver(event) {
    event.preventDefault();
    event.stopPropagation();
    this.contentWrapperTarget.classList.add('border-dashed', 'border-primary', 'border-2');
  }

  // Handles drag leave event to remove visual feedback
  handleDragLeave() {
    this.contentWrapperTarget.classList.remove('border-dashed', 'border-primary', 'border-2');
  }

  // Handles drop event to process dropped files
  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    this.contentWrapperTarget.classList.remove('border-dashed', 'border-primary', 'border-2');

    const droppedFiles = Array.from(event.dataTransfer.files);
    this.addFiles(droppedFiles);
  }

  // Handles paste event to process pasted images
  handlePaste(event) {
    if (event.clipboardData && event.clipboardData.items) {
      const pastedFiles = [];
      for (let i = 0; i < event.clipboardData.items.length; i++) {
        const item = event.clipboardData.items[i];
        if (item.type.startsWith('image/')) {
          pastedFiles.push(item.getAsFile());
        }
      }
      if (pastedFiles.length > 0) {
        this.addFiles(pastedFiles);
        event.preventDefault();
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
    previewContainer.innerHTML = '';
    previewContainer.classList.add('flex', 'flex-wrap', 'gap-4', 'mt-4');

    if (this.allFiles.length === 0) {
      previewContainer.classList.remove('flex', 'flex-wrap', 'gap-4', 'mt-4');
      return;
    }

    const ul = document.createElement('ul');
    ul.classList.add('flex', 'flex-wrap', 'gap-4', 'w-full');

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
          'flex-shrink-0'
        );

        const img = document.createElement('img');
        img.src = e.target.result;
        img.classList.add('w-16', 'h-16', 'object-cover', 'rounded-lg', 'border', 'border-gray-300');
        img.alt = file.name;

        const infoContainer = document.createElement('div');
        infoContainer.classList.add('flex', 'flex-col', 'justify-center', 'flex-grow');

        const fileNameSpan = document.createElement('span');
        fileNameSpan.classList.add('text-sm', 'font-medium', 'text-gray-800', 'truncate', 'max-w-[120px]');
        fileNameSpan.textContent = file.name;

        const fileSizeSpan = document.createElement('span');
        fileSizeSpan.classList.add('text-xs', 'text-gray-500');
        fileSizeSpan.textContent = this.formatFileSize(file.size);

        infoContainer.appendChild(fileNameSpan);
        infoContainer.appendChild(fileSizeSpan);

        const deleteButton = document.createElement('button');
        deleteButton.type = 'button';
        deleteButton.classList.add(
          'text-gray-500',
          'hover:text-red-600',
          'focus:outline-none',
          'transition-colors',
          'duration-200',
          'p-1',
          'rounded-full',
          'hover:bg-gray-100',
          'ml-auto'
        );
        deleteButton.setAttribute('data-action', 'click->image-uploads#removeImage');
        deleteButton.setAttribute('data-index', index);

        deleteButton.innerHTML = `
          <svg class="w-5 h-5 cursor-pointer" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        `;

        li.appendChild(img);
        li.appendChild(infoContainer);
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

    this.allFiles.splice(indexToRemove, 1);

    this.renderPreviews();
    // ************* CRUCIAL: Update the actual file input after removal *************
    this.updateFileInput();
    this.updateSubmitButtonVisibility();
  }

  // This function is crucial for Turbo submission.
  // It ensures the actual file input's `files` property matches `this.allFiles`.
  updateFileInput() {
    const dataTransfer = new DataTransfer();
    this.allFiles.forEach((file) => dataTransfer.items.add(file));
    this.inputTarget.files = dataTransfer.files;
    // Clearing the original input's value might also be helpful
    // this.inputTarget.value = ''; // This would clear the displayed file name if not already cleared
  }

  // Controls the visibility of the submit button
  updateSubmitButtonVisibility() {
    if (this.allFiles.length > 0) {
      this.submitTarget.classList.remove('hidden');
    } else {
      this.hidePreview();
      this.submitTarget.classList.add('hidden');
    }
  }
}
