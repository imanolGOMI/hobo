import { Controller } from "@hotwired/stimulus"
// El puente que traduce el marcado neutral del catalogo (`data-rapid`) a lo
// que Stimulus espera. Lo importa cada controlador para que se cargue con el
// primero que llegue; el modulo se ejecuta una sola vez.
import "controllers/rapid_bridge"

// Avisar antes de salir de una pagina con cambios sin guardar.
//
// El dialogo lo decide el navegador -- los mensajes propios se ignoran desde
// 2016, porque se usaban para atrapar a la gente -- asi que lo unico que se
// decide aqui es **si preguntar**.
//
// Se escucha solo, sin `data-rapid-action` en el marcado. Antes hacia falta
// escribir `change->…#touch submit->…#release`, y eso el contrato neutro no lo
// sabe decir: `data-rapid-action="before-unload:touch"` no lleva evento, y en
// un formulario el evento que Stimulus supone es `submit` -- justo el
// contrario del que hace falta. En vez de complicar el contrato para un caso,
// el comportamiento se ata sus propios eventos: el marcado solo dice
//
//   <form data-rapid='{"before-unload":{}}'>
//
// que es lo unico que hay que decir de verdad.
export default class extends Controller {
  connect() {
    this.dirty = false

    this.onChange = () => { this.dirty = true }
    this.onSubmit = () => { this.dirty = false }
    this.onBeforeUnload = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = ""
    }

    this.element.addEventListener("change", this.onChange)
    this.element.addEventListener("submit", this.onSubmit)
    window.addEventListener("beforeunload", this.onBeforeUnload)
  }

  disconnect() {
    this.element.removeEventListener("change", this.onChange)
    this.element.removeEventListener("submit", this.onSubmit)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
  }

  // Siguen publicos porque una pagina puede querer decirlo a mano: un boton que
  // guarda por su cuenta y deja el formulario limpio.
  touch() { this.dirty = true }
  release() { this.dirty = false }
}
