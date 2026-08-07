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

## Decisión

**Opción A**, tomada por Imanol el 2026-08-07 con este spike delante.

---

# Spike C — un tag real y grande: `<table-plus>`

`ruby spike/dryml/c_table_plus.rb` · runtime en `runtime.rb`

Se eligió `<table-plus>` (`hobo_rapid/taglibs/plus/table_plus.dryml`, 58 líneas)
porque es el peor caso del catálogo: usa **nombres de param calculados en
tiempo de ejecución**, `merge-params`, `all_parameters`, `attrs_for`, variables
de `scope`, atributos con guiones y atributos de control.

## Lo que funcionó a la primera

- `attrs="sort-field, sort-direction"` → guiones a guiones bajos
- `param` con nombre estático (`header`) y **con nombre calculado**
  (`param="#{scope.field_name}-heading"` → `param(:"#{scope.field_name}_heading")`)
- `attrs_for(:table)` para repartir atributos entre los tags a los que se reenvían
- `scope.field_name` / `scope.field_path`
- **`all_parameters[:controls]`** — preguntar si quien llama pasó un param.
  Verificado: el `<th class="controls">` aparece solo cuando se pasa
- `call_tag(..., as: :search_filter)` — que el propio sitio de llamada sea un
  punto de extensión, que es el `<search-filter param/>` pelado
- La lógica de ordenación, incluido el `?sort=-title` cuando ya está ascendente

## EL HALLAZGO: un `param` se perdió **en silencio**

La segunda salida del script salía **idéntica** a la primera: el override del
param dinámico `:title_heading` **no se aplicaba, y no fallaba nada**.

Es exactamente la clase de fallo que arruinó el primer intento y que está en
`HALLAZGOS.md`: *la página se pinta, con el valor por defecto donde iba lo tuyo.*

### Por qué

En DRYML, un `param` declarado dentro de un bloque que le pasas a **otro** tag
pertenece al tag **que lo escribió**, no al que lo ejecuta:

```dryml
<def tag="table-plus">
  <with-field-names>              <!-- otro tag -->
    <th param="#{scope.field_name}-heading">   <!-- pero este param es de table-plus -->
```

El spike hacía `instance_exec(&override)` **en el tag que ejecuta**, así que
`self` pasaba a ser `with-field-names` y el `param` se buscaba en *sus* params,
donde no está. Nadie protesta: simplemente se renderiza el valor por defecto.

### Cómo se arregla, y qué implica

Los bloques de Ruby **capturan `self` léxicamente**. Un `proc` creado dentro del
`content` de `table-plus` ya lleva dentro el tag correcto. Basta con
`override.call` en vez de `instance_exec(&override)`.

**Pero eso arrastra dos cambios de arquitectura**, y son la lección del spike:

1. **El buffer de salida no puede ser del tag.** Si el bloque se ejecuta con el
   `self` del que lo definió, escribiría en *su* buffer y no en el del que lo
   llama, y el HTML saldría desordenado. → **Los tags tienen que devolver
   cadenas**, no escribir en un buffer compartido.
2. **`this` y `scope` no pueden ser estado de instancia.** El bloque necesita el
   `this` y el `scope` de **quien lo ejecuta**, no de quien lo escribió. → Tienen
   que ser una **pila dinámica**, no variables del objeto.

Y ahí está la explicación de algo que dábamos por complejidad gratuita: **para
esto existen `part_context.rb` y la pila de `scoped_variables` de DRYML.** No
eran barroquismo, eran esta misma necesidad.

## Conclusión del spike C

La opción A **sí sostiene un tag real y grande** — pero el runtime ingenuo de 50
líneas **no**. Hace falta el de verdad: valores de retorno en vez de buffer, y
contexto dinámico. Sigue siendo mucho menos que las 1.700 líneas del compilador
de DRYML, pero **no son 50 líneas**, y hay que entrar sabiéndolo.

**Lo más importante que deja este spike no es el código: es que el modo de fallo
del primer intento reaparece solo, en cuanto te descuidas.** Cualquier diseño que
se elija necesita **una prueba que exija que todo `param` declarado sigue siendo
alcanzable**, o lo volveremos a perder de uno en uno y en silencio.

---

# La prueba de contrato

```sh
cd spike/dryml && rake test     # tambien entra en el `rake test` de la raiz
```

`test/param_contract.rb` es la comprobación; `test/param_contract_test.rb` la
usa. **No hay ninguna lista de params escrita a mano**, porque esa lista es lo
que se queda vieja: renderiza el tag, **apunta cada `param` que la ejecución
alcanza** —incluidos los de nombre calculado— y vuelve a renderizar uno por uno
con un centinela, exigiendo que salga.

```ruby
assert_every_param_overridable(:table_plus, scenarios, :except => EXCEPTIONS)
```

- **Varios escenarios**, porque hay params detrás de un `if`.
- **`except:` se audita en las dos direcciones**: una excepción que ya se puede
  sobreescribir, o que nombra un param que ya nadie declara, **falla**.
- **`ParamContractTeethTest` demuestra que la comprobación falla** cuando se le
  pone delante el runtime ingenuo de spike C. Una comprobación que nunca falla es
  peor que ninguna.

## Lo que cazó el primer día

`old` —el `<old-x>`— **no emitía nada**. `@old_stack` era estado de instancia del
tag que ejecuta el `param`, pero `old` se llama desde el override, que corre con
el `self` de quien lo escribió. **El mismo error de spike C, a un metro de donde
lo habíamos arreglado.** La pila vive ahora en `Rapid::Context`, con el buffer,
`this` y `scope`.

## Lo que dejó anotado, y que ya está hecho

`<table-plus>` pasaba con dos excepciones, porque no había forma de alcanzar los
params de los tags a los que llama. Eso son los **params anidados**, y ya están.

---

# Params anidados y el modelo de parámetro

Un parámetro **no es un bloque de contenido**. Los `.feature` de `dryml/` son la
especificación, y dicen que lleva cuatro cosas:

| DRYML | Ruby |
|---|---|
| `<heading:>Title</heading:>` | `Rapid.parameter { text "Title" }` |
| `<heading: class="big">` | `Rapid.parameter(:attributes => { :class => "big" })` |
| `<heading: replace>` | `Rapid.parameter(:replace => true)` |
| `<table:><row:>…</row:></table:>` | `Rapid.parameter(:params => { :row => … })` |

Las reglas que salen de ahí:

1. **Rellenar conserva el elemento.** `<h3 param="heading">` con `<heading:>X`
   da `<h3>X</h3>`. **`replace` es lo que se lleva el elemento**, y entonces
   `old` emite el original — el `<x: restore/>` de DRYML, gratis.
2. **Los atributos se fusionan**, y `class` se concatena: `card` + `odd`.
3. **Un parámetro sin contenido deja el defecto en paz.**
4. **Anidar solo tiene sentido en una llamada a otro tag.** En un elemento no
   hay params a los que pasarlos, así que **se lanza un error** en vez de
   tragárselos.
5. **Los params anidados del que llama ganan** a los que el tag rellena solo.

Un tag expone una llamada con `as:` (el `<search-filter param/>` pelado). Sin
eso no hay camino hasta los params del tag llamado.

## La prueba aprendió a navegar

Cada tag conoce **su dirección** (`param_path`), y el barrido **construye el
anidamiento solo**, a la profundidad que haga falta. Usa **dos sondas**:
`replace` se le exige a todos los params; **rellenar** solo a los de elemento y
a los pelados, porque el tag llamado es libre de ignorar el contenido que le den
—`<search-filter>` lo ignora— y exigírselo sería mentir.

El gancho pasó de `param` a `parameter_for`, lo único que comparten los tres
tipos de sitio. Enganchado a `param` se perdía dos de los tres.

**Queda una sola excepción en `<table-plus>`**, y no es del runtime:
`<table-plus>` llama a `<with-field-names>` sin exponer la llamada.

## Lo que falta de la sintaxis de parámetros

Pseudo-params (`append-`, `prepend-`, `before-`, `after-`, `without-`), `<x:
param>` para reexponer con otro nombre, `merge-params="lista"`, y el nombre del
param como clase CSS.
