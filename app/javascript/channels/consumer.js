// app/javascript/channels/consumer.js or wherever your consumer is defined

import { createConsumer } from '@rails/actioncable';

// Look for the Action Cable meta tag in the HTML
// Rails automatically generates this if you use <%= action_cable_meta_tag %> in your layout
const cableUrl = document.querySelector('meta[name="action-cable-url"]')?.content;

let consumer;
if (cableUrl) {
  consumer = createConsumer(cableUrl);
  // console.log('Action Cable consumer created with URL:', cableUrl);
} else {
  console.warn('Action Cable meta tag not found. Falling back to default or development URL.');
  // Fallback for development or if meta tag is not used
  consumer = createConsumer('wss://localhost:3000/cable');
}

// console.log(consumer);

export default consumer;
