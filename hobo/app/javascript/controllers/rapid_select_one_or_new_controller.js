import { Controller } from "@hotwired/stimulus"
// El puente que traduce el marcado neutral del catalogo (`data-rapid`) a lo
// que Stimulus espera. Lo importa cada controlador para que se cargue con el
// primero que llegue; el modulo se ejecuta una sola vez.
import "controllers/rapid_bridge"

// <select-one-or-new>: choose an existing record, or make one right here.
//
// Hobo 2 did this with a modal, and its own documentation admitted the price:
// you had to patch the controller's `create` action for xhr and inject
// JavaScript to re-select the record afterwards. None of that is needed when
// the new record's fields travel in the parent form -- `:accessible => true`
// creates it on save, which is the same road <input-many> takes.
//
// So the only thing left for the browser is: exactly one of the two is
// submitted. The select while you are choosing, the fields while you are
// creating, never both -- because both would reach `attributes=` and the
// second would quietly win.
export default class extends Controller {
  static targets = ["select", "fields"]
  static values = { newOption: { type: String, default: "__new__" } }

  connect() {
    this.#refresh()
  }

  change() {
    this.#refresh()
  }

  #refresh() {
    const creating = this.selectTarget.value === this.newOptionValue

    this.fieldsTarget.hidden = !creating
    this.fieldsTarget
      .querySelectorAll("input, select, textarea")
      .forEach((input) => (input.disabled = !creating))

    // The select keeps working -- you can change your mind -- so it is its
    // *name* that goes, not the control: an input with no name is not
    // submitted. The name is parked on the element so <input-many> can renumber
    // it along with everything else when rows move.
    if (creating) {
      if (this.selectTarget.name) {
        this.selectTarget.dataset.rapidName = this.selectTarget.name
        this.selectTarget.removeAttribute("name")
      }
    } else if (this.selectTarget.dataset.rapidName) {
      this.selectTarget.name = this.selectTarget.dataset.rapidName
      delete this.selectTarget.dataset.rapidName
    }
  }
}
