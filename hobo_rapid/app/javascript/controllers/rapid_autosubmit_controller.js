import { Controller } from "@hotwired/stimulus"

// Submit the form when something in it changes.
//
// This is two of the old jQuery behaviours at once, because they were the same
// idea written twice: `hot-input` (an input that sends the form as you change
// it) and `filter-menu` (a select that sends the form when you pick something).
//
// Neither needs to do the request itself any more. The form goes to Turbo, which
// swaps whatever frame it targets, so all that is left here is *when* to submit.
export default class extends Controller {
  static values = { delay: { type: Number, default: 0 } }

  submit() {
    if (this.delayValue > 0) {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => this.#submitNow(), this.delayValue)
    } else {
      this.#submitNow()
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  #submitNow() {
    const form = this.element.form || this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
