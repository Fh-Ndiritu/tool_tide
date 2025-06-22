import consumer from './consumer';

consumer.subscriptions.create('LandscaperChannel', {
  connected() {
    console.log('Connected to LandscaperChannel');
  },

  disconnected() {
    console.log('Disconnected from LandscaperChannel');
  },

  received(data) {
    console.log('Received data from LandscaperChannel:', data);
    // Find the Stimulus controller instance and call a method to update UI
    const controller = document.querySelector('[data-controller="landscaper"]')._stimulusController;
    if (controller) {
      if (data.modified_image_url) {
        controller.modifiedImageUrlValue = data.modified_image_url;
        controller.displayResults();
      } else if (data.error) {
        alert(`AI processing error: ${data.error}`);
        controller.showSection('editor'); // Go back to editor on error
      }
    }
  },
});
