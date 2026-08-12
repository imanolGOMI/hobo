import { Controller } from "@hotwired/stimulus"
// El puente que traduce el marcado neutral del catálogo (`data-rapid`) a lo
// que Stimulus espera. Lo importa cada controlador para que se cargue con el
// primero que llegue; el módulo se ejecuta una sola vez.
import "controllers/rapid_bridge"

// Ordenar una lista arrastrando.
//
// En Hobo 2 esto era jQuery UI Sortable, y por eso vivía en `hobo_jquery_ui`.
// Arrastrar y soltar es HTML desde hace años, así que aquí no hay plugin: son
// cuatro eventos del navegador y un `fetch` al terminar.
//
// El contrato con el servidor es **el de Hobo 2**, a propósito: se envía a la
// acción `reorder` del controlador una lista de ids en un parámetro que se
// llama `<modelo>_ordering`. Es lo que `acts_as_list` dejó escrito en la
// aplicación, y cambiarlo obligaría a tocar código que funciona.
export default class extends Controller {
  static targets = ["handle"]
  static values = { url: String, parameter: String }

  connect() {
    this.arrastrando = null
    this.element.addEventListener("dragstart", this.empezar)
    this.element.addEventListener("dragover", this.encima)
    this.element.addEventListener("drop", this.soltar)
    this.element.addEventListener("dragend", this.terminar)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.empezar)
    this.element.removeEventListener("dragover", this.encima)
    this.element.removeEventListener("drop", this.soltar)
    this.element.removeEventListener("dragend", this.terminar)
  }

  // La fila entera es lo que se mueve, aunque lo que se agarre sea el asa.
  fila(elemento) {
    const hijo = elemento.closest("li, tr, .item")
    return hijo && hijo.parentElement === this.element ? hijo : null
  }

  empezar = (evento) => {
    const fila = this.fila(evento.target)
    if (!fila) return
    this.arrastrando = fila
    fila.classList.add("arrastrando")
    evento.dataTransfer.effectAllowed = "move"
    // Firefox no empieza el arrastre si nadie pone datos.
    evento.dataTransfer.setData("text/plain", "")
  }

  encima = (evento) => {
    if (!this.arrastrando) return
    evento.preventDefault()

    const sobre = this.fila(evento.target)
    if (!sobre || sobre === this.arrastrando) return

    // Por delante o por detrás según de qué mitad se suelte, que es lo que hace
    // que la fila no baile mientras se pasa por encima.
    const caja = sobre.getBoundingClientRect()
    const despues = evento.clientY > caja.top + caja.height / 2
    sobre.parentElement.insertBefore(this.arrastrando, despues ? sobre.nextSibling : sobre)
  }

  soltar = (evento) => {
    if (this.arrastrando) evento.preventDefault()
  }

  terminar = () => {
    if (!this.arrastrando) return
    this.arrastrando.classList.remove("arrastrando")
    this.arrastrando = null
    this.guardar()
  }

  // El orden nuevo, contado al servidor. Los ids salen del `id` del dom, que es
  // lo que el catálogo pinta en cada fila (`libro-14`).
  guardar() {
    if (!this.hasUrlValue) return

    const ids = Array.from(this.element.children)
      .map((fila) => (fila.id || "").split("-").pop())
      .filter((id) => id !== "")

    const cuerpo = new URLSearchParams()
    ids.forEach((id) => cuerpo.append(`${this.parameterValue}[]`, id))

    const token = document.querySelector("meta[name='csrf-token']")
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token ? token.content : "",
        "Accept": "text/plain",
      },
      body: cuerpo,
    })
  }
}
