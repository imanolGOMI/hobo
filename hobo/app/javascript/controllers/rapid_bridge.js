// El puente entre el contrato de Hobo y Stimulus.
//
// El catálogo pinta un marcado que no es de nadie:
//
//   <div data-rapid='{"input-many":{"prefix":"book[tags]"}}'>
//     <div data-rapid-target="input-many:item">…</div>
//     <button data-rapid-action="input-many:add">+</button>
//
// y esto lo traduce a lo que Stimulus espera: `data-controller`,
// `data-<controlador>-target` y `data-action`. Son treinta líneas, y a cambio
// el comportamiento se puede implementar con otra cosa -- `hobo_jquery` lee
// exactamente los mismos atributos y no necesita este fichero.
//
// Stimulus vigila el DOM por su cuenta, así que en cuanto se le ponen los
// atributos conecta solo. Lo que hay que vigilar es la aparición de marcado
// nuevo -- una fila clonada del `input-many` lleva dentro su propio
// comportamiento --, y de eso se encarga el observador del final. Hobo 2 hacía
// esto mismo a mano: `me.next().hjq()` después de clonar.

const CONTROLADOR = (nombre) => `rapid-${nombre}`

function guion(texto) {
  return texto.replace(/_/g, "-")
}

// data-rapid='{"input-many":{…}}' -> data-controller + los valores
function declarar(elemento) {
  let configuracion
  try {
    configuracion = JSON.parse(elemento.dataset.rapid)
  } catch (error) {
    console.warn("[hobo] data-rapid no es JSON válido:", elemento.dataset.rapid)
    return
  }

  const controladores = new Set((elemento.getAttribute("data-controller") || "").split(/\s+/).filter(Boolean))

  for (const [nombre, opciones] of Object.entries(configuracion)) {
    controladores.add(CONTROLADOR(nombre))
    for (const [clave, valor] of Object.entries(opciones || {})) {
      elemento.setAttribute(`data-${CONTROLADOR(nombre)}-${guion(clave)}-value`, valor)
    }
  }

  elemento.setAttribute("data-controller", [...controladores].join(" "))
}

// data-rapid-target="input-many:item" -> data-rapid-input-many-target="item"
function apuntar(elemento) {
  for (const declaracion of elemento.dataset.rapidTarget.split(/\s+/).filter(Boolean)) {
    const [nombre, papel] = declaracion.split(":")
    if (nombre && papel) elemento.setAttribute(`data-${CONTROLADOR(nombre)}-target`, papel)
  }
}

// data-rapid-action="input-many:add" -> data-action="rapid-input-many#add"
//
// Y `click->` no se escribe: cada elemento tiene su evento natural -- un botón
// se pulsa, un select cambia --, que es justo lo que Stimulus supone cuando no
// se lo dices.
function accionar(elemento) {
  const acciones = new Set((elemento.getAttribute("data-action") || "").split(/\s+/).filter(Boolean))

  for (const declaracion of elemento.dataset.rapidAction.split(/\s+/).filter(Boolean)) {
    const [nombre, metodo] = declaracion.split(":")
    if (nombre && metodo) acciones.add(`${CONTROLADOR(nombre)}#${metodo}`)
  }

  elemento.setAttribute("data-action", [...acciones].join(" "))
}

function traducir(raiz) {
  const dentro = (selector) => [
    ...(raiz.matches?.(selector) ? [raiz] : []),
    ...(raiz.querySelectorAll?.(selector) || []),
  ]

  dentro("[data-rapid]").forEach(declarar)
  dentro("[data-rapid-target]").forEach(apuntar)
  dentro("[data-rapid-action]").forEach(accionar)
}

function arrancar() {
  traducir(document.documentElement)

  // Lo que aparezca después: una fila nueva del input-many, una respuesta de
  // Turbo, cualquier cosa que alguien inserte.
  new MutationObserver((cambios) => {
    for (const cambio of cambios) {
      for (const nodo of cambio.addedNodes) {
        if (nodo.nodeType === Node.ELEMENT_NODE) traducir(nodo)
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", arrancar)
} else {
  arrancar()
}

// Y al navegar con Turbo, que no recarga la página.
document.addEventListener("turbo:load", () => traducir(document.documentElement))

export { traducir }
