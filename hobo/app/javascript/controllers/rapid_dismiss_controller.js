import { Controller } from "@hotwired/stimulus"
// El puente que traduce el marcado neutral del catalogo (`data-rapid`) a lo
// que Stimulus espera. Lo importa cada controlador para que se cargue con el
// primero que llegue; el modulo se ejecuta una sola vez.
import "controllers/rapid_bridge"

// Take this away.
//
// It is the × of a flash message, and it is here rather than in the theme
// because a message you cannot get rid of is a bug, not a matter of taste:
// Bootstrap's own dismissible alerts need Bootstrap's JavaScript, which an
// application on the `clean` theme does not have and never will.
//
// The button ships hidden and this shows it, for the same reason the autosubmit
// controller hides its fallback: without JavaScript a × that does nothing is
// worse than no ×.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.buttonTargets.forEach((button) => (button.hidden = false))
  }

  dismiss() {
    this.element.remove()
  }
}
