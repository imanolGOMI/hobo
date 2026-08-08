import { Controller } from "@hotwired/stimulus"

// <input-many>: a list of form rows the user can add to and remove from.
//
// This is the jQuery behaviour hjq-input-many.js rewritten as a Stimulus
// controller. What it does has not changed:
//
//   - a hidden template row, whose inputs are disabled so they are never sent
//   - "add" clones the template, enables its inputs and inserts it
//   - "remove" takes a row out
//   - after either, every row is renumbered so the names Rails receives are
//     prefix[0], prefix[1], ... with no gaps
//   - only the last row shows "add"; "remove" hides when at the minimum; and an
//     "empty" row shows only while there are no rows at all
//
// What has changed is that nobody has to call an init function after the DOM
// changes. Stimulus connects and disconnects on its own, which is most of what
// hjq.js was for.
export default class extends Controller {
  static targets = ["item", "template", "empty"]
  static values = { prefix: String, minimum: { type: Number, default: 0 } }

  connect() {
    this.#disable(this.templateTarget)
    this.#refresh()
  }

  add(event) {
    event.preventDefault()

    const row = this.templateTarget.cloneNode(true)
    row.removeAttribute("hidden")
    row.dataset.rapidInputManyTarget = "item"
    this.#enable(row)

    const after = event.target.closest("[data-rapid-input-many-target='item']")
    after ? after.after(row) : this.templateTarget.before(row)

    this.#refresh()
    row.dispatchEvent(new CustomEvent("rapid:add", { bubbles: true }))
  }

  remove(event) {
    event.preventDefault()

    const row = event.target.closest("[data-rapid-input-many-target='item']")
    if (!row) return

    const removal = new CustomEvent("rapid:remove", { bubbles: true, cancelable: true })
    if (!row.dispatchEvent(removal)) return

    row.remove()
    this.#refresh()
    this.element.dispatchEvent(new CustomEvent("rapid:change", { bubbles: true }))
  }

  // --- keeping the list consistent -------------------------------------------

  #refresh() {
    this.#renumber()
    this.#updateVisibility()
  }

  // Rails reads the index out of the name, so a gap after a removal would make
  // it build the wrong records. Every row is renumbered from zero.
  #renumber() {
    this.itemTargets.forEach((row, index) => {
      this.#renumberOne(row, index)
      row.querySelectorAll("*").forEach((node) => this.#renumberOne(node, index))
    })
  }

  #renumberOne(node, index) {
    const prefix = this.prefixValue
    const idPrefix = prefix.replaceAll("[", "_").replaceAll("]", "")

    if (node.name) {
      node.name = node.name.replace(this.#indexed(prefix, "\\[-?\\d+\\]"), `${prefix}[${index}]`)
    }
    // A <select-one-or-new> that is busy creating has parked its name here, so
    // it has to be renumbered too -- otherwise changing your mind after moving
    // rows restores the name the row had before it moved.
    if (node.dataset && node.dataset.rapidName) {
      node.dataset.rapidName = node.dataset.rapidName.replace(
        this.#indexed(prefix, "\\[-?\\d+\\]"), `${prefix}[${index}]`)
    }
    if (node.id) {
      node.id = node.id.replace(this.#indexed(idPrefix, "_-?\\d+"), `${idPrefix}_${index}`)
    }
    if (node.htmlFor) {
      node.htmlFor = node.htmlFor.replace(this.#indexed(idPrefix, "_-?\\d+"), `${idPrefix}_${index}`)
    }
  }

  #indexed(prefix, suffix) {
    return new RegExp("^" + prefix.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&") + suffix)
  }

  #updateVisibility() {
    const rows = this.itemTargets
    const last = rows.length - 1

    rows.forEach((row, index) => {
      this.#toggle(row.querySelector("[data-action*='#add']"), index === last)
      this.#toggle(row.querySelector("[data-action*='#remove']"), rows.length > this.minimumValue)
    })

    if (this.hasEmptyTarget) {
      this.#toggle(this.emptyTarget, rows.length === 0)
      rows.length === 0 ? this.#enable(this.emptyTarget) : this.#disable(this.emptyTarget)
    }
  }

  #toggle(node, shown) {
    if (node) node.hidden = !shown
  }

  // A disabled input is not submitted, which is what keeps the template row and
  // the empty row out of the parameters.
  #disable(row) {
    row.querySelectorAll("input, select, textarea").forEach((input) => (input.disabled = true))
  }

  #enable(row) {
    row.querySelectorAll("input, select, textarea").forEach((input) => (input.disabled = false))
  }
}
