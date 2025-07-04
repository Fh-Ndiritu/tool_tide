// import { createConsumer } from '@rails/actioncable';

// // Create the consumer
// const consumer = createConsumer();

// // Log the consumer to verify it's correctly created
// console.log(consumer);

import consumer from 'channels/consumer';
// Create a subscription to the LandscaperChannel
const subscription = consumer.subscriptions.create(
  { channel: 'LandscapeChannel' },
  {
    connected() {
      // console.log('Connected to LandscaperChannel');
    },

    disconnected() {
      // console.log('Disconnected from LandscaperChannel');
    },

    received(data) {
      // console.log('Received data from LandscaperChannel:', data);

      // Dispatch a custom event with the received data
      const event = new CustomEvent('landscape:data-received', {
        detail: data,
        bubbles: true,
        cancelable: true,
      });

      document.dispatchEvent(event);
    },
  }
);
