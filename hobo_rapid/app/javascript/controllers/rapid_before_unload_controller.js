import { Controller } from "@hotwired/stimulus"

// Warn before leaving a page with unsaved changes.
//
// The browser decides what to say -- it has ignored custom messages since 2016,
// because they were used to trap people -- so the old `message` option is gone.
// What matters is only whether to ask at all.
export default class extends Controller {
  connect() {
    this.dirty = false
    this.onBeforeUnload = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = ""
    }
    window.addEventListener("beforeunload", this.onBeforeUnload)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
  }

  // Bound to `change` on the form, and to `submit`: sending the form is not
  // leaving with unsaved changes.
  touch() { this.dirty = true }
  release() { this.dirty = false }
}
