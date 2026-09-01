import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label"]

  connect() {
    this.syncControl()
  }

  toggle() {
    const root = document.documentElement
    const theme = root.dataset.theme === "dark" ? "light" : "dark"
    root.dataset.theme = theme
    localStorage.setItem("ledgerly-theme", theme)
    this.syncControl()
  }

  syncControl() {
    if (!this.hasButtonTarget || !this.hasLabelTarget) return

    const dark = document.documentElement.dataset.theme === "dark"
    this.buttonTarget.setAttribute("aria-pressed", dark.toString())
    this.buttonTarget.setAttribute("aria-label", `Switch to ${dark ? "light" : "dark"} theme`)
    this.labelTarget.textContent = dark ? "Light theme" : "Dark theme"
  }
}
