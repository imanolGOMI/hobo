# Spike: ¿sobre qué se reconstruye DRYML?

Este spike existe para contestar **una** pregunta con código delante, no con
corazonadas. Es lo que abre la capa 3 del `PLAN.md`.

> **¿Cuál de los sustratos candidatos puede expresar `param` y `<extend>` sin
> inventarse un parser?**

No es «cuál se lee mejor». Es cuál soporta las cuatro propiedades de DRYML que
ya decidimos conservar:

1. **`param`** — puntos de extensión declarados **en el marcado**, sin API previa
2. **`<extend>` / `<old-x>`** — extender un tag desde otra gema, sin saber su clase
3. **Despacho polimórfico** por el tipo del valor
4. **El contexto implícito `this`**

## Cómo ejecutarlo

```sh
ruby spike/dryml/a_ruby_dsl.rb     # funciona, sin dependencias
# spike/dryml/b_view_component.rb  # no arranca sin Rails; es analisis estructural
```

## Resultado

| Propiedad | A · DSL en Ruby | B · ViewComponent + ERB |
|---|---|---|
| `param` | Sí. Un método con bloque | Slots, pero **declarados en Ruby por adelantado** |
| `param` anidado | Sí, sale solo | **No.** Los slots son una lista plana |
| `<old-x>` (envolver el defecto) | Sí, con una pila | **No.** Un slot solo sustituye |
| `<extend>` desde otra gema | Sí, `Module#prepend` + `super` | **No.** Subclase, pero no alcanza a quien ya usa la clase original |
| Polimórfico por tipo | Registro de ~10 líneas | Hay que escribir el mismo registro |
| `this` implícito | Sí | Va contra su diseño |
| **Dependencias** | **Ninguna** | Rails entero arrancado |
| **Tamaño del runtime** | **~50 líneas** | ViewComponent + ActionView |

### Lo que salió al ejecutar A

```
--- page con dos params sobreescritos ---
<html><head><title>Home</title></head><body><div class="navbar">
<header class="container"><b>My App</b></header></div>
<div class="container">Hello</div><footer></footer></body></html>

--- un param que ENVUELVE el defecto en vez de sustituirlo (<old-x>) ---
...<div class="navbar"><div class="wrap"><header class="container">
<a href="/">Hobo</a></header></div></div>...

--- view polimorfico ---
07/08/2026
a &lt;script&gt; tag
42
```

Las tres cosas, correctas. **El runtime entero son unas 50 líneas de Ruby sin
dependencias.**

## Los tres puntos donde B se rompe

**a) Un slot se declara en Ruby.** En DRYML `param` es un atributo en cualquier
elemento, y eso es justo lo que hace que el contrato de un tema sea *abierto*:
un tema puede exponer un punto de extensión que la base no previó. Con slots,
no.

**b) Los slots no anidan.** `<header param>` conteniendo `<div param="app-name">`
son dos puntos de extensión, uno dentro de otro, y el de fuera tiene que seguir
funcionando cuando sobreescribes el de dentro. Los slots son una lista plana.

**c) Un slot solo sustituye, no envuelve.** No hay `<old-x>`. Y eso **es
exactamente el fallo del primer intento**, el que está documentado en
`HALLAZGOS.md`: `replace` se lleva por delante lo que había debajo, la página se
pinta igual, y el diseño se pierde en silencio.

Es decir: **elegir B nos volvería a meter en el problema del que veníamos.**

## Lo que este spike NO dice

- No dice que ViewComponent sea malo. Es excelente para componentes escritos a
  mano. Dice que **no encaja con un motor que genera marcado**, que es lo que
  Hobo es.
- No mide ergonomía ni familiaridad. Escribir vistas en Ruby en vez de en
  marcado es un cambio real para quien viene de DRYML o de ERB, y eso es una
  decisión de producto, no técnica.
- No cubre Slim ni Haml, porque comparten el problema de B: son lenguajes de
  plantilla sin extensión con nombre ni herencia entre ficheros.

## Recomendación

**Opción A**, con una condición: que la capa de marcado se pueda leer. Un DSL de
Ruby que construye HTML a base de llamadas es potente pero denso, y el catálogo
de RAPID son 111 tags. Antes de comprometerse conviene ver **un tag real y
grande** escrito así — `<table-plus>` o `<field-list>`— y decidir si se sostiene.

Eso es lo primero que haría la capa 3.
