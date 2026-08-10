import { Controller } from "@hotwired/stimulus"
// El puente que traduce el marcado neutral del catalogo (`data-rapid`) a lo
// que Stimulus espera. Lo importa cada controlador para que se cargue con el
// primero que llegue; el modulo se ejecuta una sola vez.
import "controllers/rapid_bridge"

// <select-many>: pick from a select, and each choice becomes a row with a hidden
// input; remove a row and the option comes back to the select.
//
// The jQuery version turned the chosen <option> into an <optgroup> to hide it
// and turned it back on removal, which is a trick that stops working the moment
// anything else looks at the select. Here the option is simply disabled and
// hidden, which is what those attributes are for.
export default class extends Controller {
  static targets = ["select", "items", "template"]

  add() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option || !option.value) return

    const row = this.templateTarget.content
      ? this.templateTarget.content.firstElementChild.cloneNode(true)
      : this.templateTarget.cloneNode(true)

    row.removeAttribute("hidden")
    row.dataset.value = option.value
    row.querySelectorAll("[data-rapid-select-many-label]").forEach((node) => (node.textContent = option.text))
    row.querySelectorAll("input[type=hidden]").forEach((input) => {
      input.value = option.value
      input.disabled = false
    })

    this.itemsTarget.appendChild(row)
    this.#takeOut(option)
    this.selectTarget.value = ""

    row.dispatchEvent(new CustomEvent("rapid:add", { bubbles: true }))
  }

  remove(event) {
    event.preventDefault()

    const row = event.target.closest("[data-value]")
    if (!row) return

    this.#putBack(row.dataset.value)
    row.remove()
    this.element.dispatchEvent(new CustomEvent("rapid:change", { bubbles: true }))
  }

  // An option already chosen is disabled and hidden rather than removed, so it
  // is still there to come back, and so nothing else that reads the select sees
  // a different list.
  #takeOut(option) {
    option.disabled = true
    option.hidden = true
    option.selected = false
  }

  #putBack(value) {
    const option = Array.from(this.selectTarget.options).find((o) => o.value === value)
    if (!option) return
    option.disabled = false
    option.hidden = false
  }
}
