export default class extends Controller {
  connect() {
    this.masonry = new Masonry(this.element, {
      itemSelector: '.grid-item',
    });
  }

  layout() {
    this.masonry.layout();
  }
}
