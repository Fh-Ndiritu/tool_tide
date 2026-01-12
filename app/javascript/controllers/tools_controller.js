import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static classes = ["active", "inactive"]

  connect() {
    this.showTab(0)
  }

  switch(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.showTab(index)
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      const isActive = i === index
      const panel = this.panelTargets[i]

      if (isActive) {
        tab.classList.add(...this.activeClasses)
        tab.classList.remove(...this.inactiveClasses)
        panel.classList.remove("hidden")
      } else {
        tab.classList.remove(...this.activeClasses)
        tab.classList.add(...this.inactiveClasses)
        panel.classList.add("hidden")
      }
    })
  }
}
