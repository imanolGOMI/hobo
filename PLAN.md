# Plan de trabajo — Hobo 2027, segundo intento

> **Si retomas la sesión, lee este fichero primero y no reconstruyas nada de la
> conversación.** Aquí está el estado, las decisiones ya tomadas y lo que queda
> abierto. El complemento es `HALLAZGOS.md`, que cuenta lo que salió mal en el
> primer intento y no hay que repetir.

---

## Dónde estamos

| | |
|---|---|
| Rama | `hobo_2027_v2` |
| Punto de partida | `master` = Hobo 2.2.6 (Rails 4.2), **intacto** |
| Objetivo | Rails 8.1 / Ruby 3.4 |
| Primer intento | rama `hobo_2027`, tag **`intento-1-update`**. Descartado, se conserva |
| Método | De abajo arriba, por capas. **Parar, probar y preguntar en cada capa** |

En el repo hay ahora, además de las gemas de siempre:

- `hobo_bootstrap/` y `hobo_bootstrap_ui/` — copias de los repos externos
  (no submódulos), cada una con su `ORIGEN.md`. Faltaban y son piezas clave.

---

## Decisiones tomadas

Fecha: 2026-08-07. No volver a discutirlas salvo que aparezca información nueva.

1. **Empezar de cero** sobre `master`, no continuar el primer intento.
2. **De abajo arriba, por capas**, no en rebanada vertical. Con parada, prueba y
   preguntas al final de cada capa.
3. **Objetivo de la primera fase: solo aplicación nueva.** `hobo new` tiene que
   dejar una app Rails 8 que arranque, con su modelo, su CRUD y su login.
   Actualizar aplicaciones viejas es **otra fase y otra rama**.
4. **La compatibilidad va por ramas, no por condicionales**: `master` para lo
   nuevo, una rama por versión antigua (`2.1`, etc.). Mezclar las dos cosas fue
   una de las causas del lío anterior.
5. **DRYML: se migra a Ruby, con remix.** Se conserva la *semántica*, no el
   lenguaje. Ver «La duda abierta» más abajo: falta elegir el sustrato.
6. **El parser de DRYML no se tira**: se reutiliza como front-end del
   actualizador que migrará las plantillas de las apps existentes.
7. **`will_paginate` no se toca** al actualizar. Pagy no parchea nada y convive.
8. **Se conserva el pipeline de assets que la app tenga.** Propshaft fue un error.
9. **Las pruebas se portan todas a minitest.** Se acaba la dependencia de
   `rubydoctest` (abandonada en 2014) y de `irt` (2015). El estándar de Rails,
   que corre en paralelo y da fallos legibles. La capa 0 monta el andamiaje; el
   port de cada gema se hace en su capa, no todo de golpe.
10. **No se vendorizan más repos de la organización por ahora.** Quedan
    inventariados aquí abajo y clonables cuando toque la capa que los necesite.
11. **El resultado final es UNA SOLA GEMA `hobo`**, no cinco. `hobo_support`,
    `hobo_fields`, `dryml`, `hobo` y `hobo_rapid` se funden. Los plugins siguen
    siendo gemas aparte (pieza 17), pero dependerán de una sola.
    Las capas del plan siguen valiendo como **unidades de trabajo**; lo que
    cambia es que el resultado se empaqueta junto.
12. **La fusión se hace al final, en la capa 7.** Hasta entonces se conservan las
    fronteras actuales para que el diff de cada capa sea legible. El precio
    aceptado: el andamiaje (gemspec, Gemfile, Rakefile, `test_helper`) se repite
    en cada gema y luego se tira.
14. **El JavaScript se migra a Stimulus y Turbo** (decidido el 2026-08-07, en la
    capa 5). Hobo trae hoy 1.045 líneas de jQuery propio (`hobo_jquery`) que
    **no son un adorno**: son la mitad interactiva —formularios ajax,
    `input-many`, editores en línea, búsqueda en vivo, borrado con
    confirmación—. Rails 8 trae Stimulus y Turbo de serie, y **se migra antes de
    portar los tags**, para que el contrato con el navegador nazca ya con la
    forma nueva en vez de portarse dos veces.
    > Esta decisión es **distinta** de la del sustrato de DRYML (decisión 5). Esa
    > era sobre el servidor —DSL en Ruby frente a ViewComponent— y está tomada.
    > Ésta es sobre el navegador, y jQuery no competía con ViewComponent sino con
    > Stimulus. No estaba escrita en ningún sitio.
15. **El protocolo de «partes» se sustituye por Turbo Frames** (decidido el
    2026-08-07). Hobo traía un protocolo propio de ~2008: el navegador mandaba
    `render[i][part_context]`, un marcador serializado de qué trozo de plantilla
    había pintado cada nodo; el servidor llamaba a `refresh_part`, **volvía a
    ejecutar ese trozo** con su contexto guardado; y contestaba con
    **JavaScript** (`hjq.ajax.update("id", "<html>")`) que lo sustituía.
    Es lo que hacen los Turbo Frames de serie, sin marcador que serializar, sin
    viaje por la sesión y sin contestar en JavaScript.
    > **No había opción de dejarlo como estaba:** `refresh_part` vive en el
    > compilador viejo de DRYML, que la capa 3 sustituyó. El runtime nuevo no
    > tiene partes.
13. **El tema por defecto va dentro de la gema única.** Una app recién creada
    tiene que verse bien sin instalar nada más. Los temas *alternativos* siguen
    siendo plugins aparte.

## Reglas absolutas sobre `git push`

- **Nunca se hace push. Nunca, a ningún sitio.** El push lo hace Imanol a mano.
- **Jamás al repositorio de la organización `Hobo/`.** No hay permiso y no lo
  habrá. Los repos de la organización solo se **clonan y leen**.
- El único destino que existiría, y aun así lo hace él, es el repositorio
  personal de Imanol.

---

## Las 17 piezas y su veredicto

★ irrenunciable · ⚠ deuda permanente · ✎ corregido tras mirar el código

| # | Pieza | Veredicto | Nota |
|---|---|---|---|
| 1 | `fields do` | Se queda | Fuente única de verdad en el modelo |
| 2 | Generador de migraciones | Se queda ⚠ | Ver «Deuda 1» |
| 3 | Tipos ricos | Se queda ★ | Reconstruir sobre `ActiveRecord::Type` |
| 4 | Permisos | Reimplementar ⚠ | Ver «Deuda 2» |
| 5 | Lifecycles | Se queda, propia ✎ | Ninguna gema de estados da lo que hace falta |
| 6 | Scopes automáticos | Se delega → Ransack | 429 líneas, solo 3 consumidores reales |
| 7 | View hints | Se queda y crece ★ | No existe en Rails ni en el ecosistema |
| 8 | DRYML | Semántica sí, lenguaje no | Falta elegir sustrato |
| 9 | RAPID (catálogo) | Se reduce poco ✎ | Fuera ~15 envoltorios triviales, no 70 |
| 10 | Motor de derivación | Se queda ★ | *El* motivo de usar Hobo |
| 11 | Auto-actions | Se queda | Como *concern* legible, no `method_missing` |
| 12 | Router | Se queda, sin fichero ✎ | Fuera `config/hobo_routes.rb` |
| 13a | Tags estructurales del tema | **Mover a RAPID** ✎ | login, nav, flash, errores, transiciones |
| 13b | Tema (Bootstrap) | Se queda, redefinido ★ | Contrato de params **con prueba** |
| 14 | Subsites | Se queda tal cual ✎ | Eje transversal de 4 subsistemas |
| 15 | Usuario / auth | Se delega → Rails 8 | `generate authentication` ya existe |
| 16 | `hobo_support` | Se reduce ✎ | ~230 líneas fuera de 1.089, no «casi entero» |
| 17 | Contrato de plugin | Se queda, encogido ✎ | Engine + un `require` de tags + assets. Instalar = poner la gema |

Sobreviven unas **11.000-12.000 líneas de 17.700**, la mitad reescritas.

---

## Las dos deudas permanentes

### Deuda 1 — El generador de migraciones (`hobo_fields`, 442 líneas)

**Es un peaje, no un error.** Para tener `fields do` con migraciones automáticas
hay que saber del esquema lo mismo que sabe Rails, y Rails nunca hizo pública esa
parte. Lo que toca hoy:

| Línea | Qué | Estado |
|---|---|---|
| 407 | `ActiveRecord::SchemaDumper.send(:new, …)` | Constructor **privado** |
| 87, 113 | `ActiveRecord::Base.send(:descendants)` | Privado; con Zeitwerk **solo ve lo cargado** |
| 98 | `case connection.class.name` | Ramifica sobre el nombre del adaptador |
| 106 | `connection.native_database_types` | Cambia por adaptador y versión |
| 22 | `ActiveRecord::Migration.table_exists?` | Camino obsoleto |
| 290, 389 | `connection.columns`, `index_name_length` | API en migración a *pool/lease* |

**Plan:** aceptarla y blindarla con una batería que **ejecute** las migraciones
generadas, `up` **y** `down`, contra sqlite, postgres y mysql. El fallo nº1 de
`HALLAZGOS.md` existió porque las pruebas generaban el `down` y no lo corrían.
Alternativa anotada por si el peaje sale caro: introspeccionar la base de datos
en vez de Rails.

**Agravante compartido:** `descendants` con Zeitwerk exige carga ansiosa. El
router (pieza 12) tiene el mismo problema. Son dos piezas que necesitan lo mismo.

### Deuda 2 — Los permisos (`hobo`, 449 líneas)

**Es mayormente autoinfligida**, y casi toda se puede quitar.

```
:10-12  alias_method_chain :_create_record / :_update_record / :destroy
:14-16  alias_method_chain :has_many / :has_one / :belongs_to
:383    metaclass.class_eval   → unknownify_attribute
```

- `alias_method_chain` lo quitó Rails en 5.1, **pero `hobo_support` trae su
  propia copia** en `fixes/module.rb`, así que los **48 sitios siguen
  funcionando**. No es un bloqueo: es una técnica que Rails abandonó porque se
  lleva mal con `prepend`, ensucia las trazas y se dobla mal al aplicarse dos
  veces. Se sustituye por `Module#prepend` + `super` por calidad, no por
  urgencia.
- `_create_record` / `_update_record` son **privados** de ActiveRecord.
- Reescribir las macros de asociación hace que *toda* declaración de *todo*
  modelo pase por Hobo.

| Lo que hace hoy | Equivalente público |
|---|---|
| `_create_record` / `_update_record` | `before_create` / `before_update` |
| `destroy` envuelto | `before_destroy` |
| Envolver `has_many`/`has_one`/`belongs_to` | Existe solo para que `:dependent => :destroy` respete permisos → `before_destroy` en el padre |

Queda **una** cosa genuinamente difícil: los permisos de **lectura** por campo,
porque Rails no tiene gancho de lectura.

---

## ¿Merece la pena `hobo_fields` en 2026?

Contestado el 2026-08-07, con el código ejecutándose delante.

**Lo que Rails 8 ya hace mejor** está en el registro de mejoras de la capa 2, y
ya se ha quitado.

**Lo que no tiene equivalente, y es el valor real de la gema:**

1. **`fields do`** — declarar el esquema en el modelo. En Rails el esquema vive
   en `db/schema.rb`, que es *generado*, y las migraciones son historia: para
   saber qué campos tiene un modelo hay que abrir otro fichero.
2. **El generador de migraciones por diferencia.** Rails te da
   `generate migration AddBodyToAdverts body:text` — **tú** dices el cambio.
   Hobo lo **deduce** comparando modelo y base de datos. Sin equivalente en
   Rails ni en el ecosistema.
3. **Tipos ricos que viajan a la vista.** `contact_address :email_address` es lo
   que hace que salga un `<input type="email">` sin escribirlo. La Attributes
   API da el *casting*, pero nada que diga «este tipo se pinta así».

**El coste, medido:** el generador toca **seis API internas de Rails**, y en la
capa 2 se arreglaron cinco fallos causados justo por eso. **Ese peaje se paga en
cada versión de Rails, para siempre.** La batería multi-adaptador es lo que lo
hace asumible: te enteras el primer día.

### ¿Choca con la filosofía de Rails? **No.** (verificado en el código)

Se planteó la duda de si Hobo, al hacer del modelo la verdad, va contra Rails,
que hace de las migraciones la verdad. **Mirando el generador, no hay conflicto:**

```ruby
migration_template 'migration.rb.erb', "db/migrate/#{name}.rb"
rake('db:migrate') if action == 'm'
```

Hobo escribe **un fichero de migración normal de Rails** en `db/migrate/`, que se
versiona en git y se ejecuta con `rails db:migrate`, y `schema.rb` se vuelca como
siempre. **Las migraciones siguen siendo la historia y la verdad.** `fields do`
no las sustituye: **las escribe por ti**.

Para quien lo mire desde fuera, la frase es: *«tu flujo de Rails no cambia,
simplemente dejas de escribir migraciones a mano»*. Y es cierta.

**Lo que sí conviene tener claro:** `fields do` declara **dos cosas distintas**.

```ruby
fields do
  title           :string, :required
  contact_address :email_address
end
```

- **La parte de esquema** (`title` es varchar) — se puede derivar de la base de
  datos, así que **va y viene** con las migraciones.
- **La parte semántica** (`:required` es una validación; `:email_address` es un
  tipo rico que hace que la vista pinte `<input type="email">`) — **no está en el
  esquema** y no se puede derivar de él. Es lo que Rails no tiene.

**La máxima de Hobo, dicha por Imanol (2026-08-07):** *los campos se escriben en
el modelo, y nadie escribe la migración por detrás.*

Que al quitar un campo del modelo el siguiente `hobo:migration` genere el `drop`
**no es un fallo ni una deriva: es la forma de borrar campos en Hobo.** Quitas la
línea, generas, y ahí están los `remove_column`. Escribir una migración a mano a
espaldas del modelo es usar la herramienta al revés, no un hueco del diseño.

**Para qué sirve entonces el generador inverso `esquema → fields do`:** no para
reparar nada, sino como **punto de comparación**. El esquema y el modelo tienen
que decir lo mismo; poder derivar uno del otro permite **comprobarlo**. Si
difieren y no hay migración pendiente, algo va mal y se puede detectar en vez de
descubrirlo en producción.

Da además una invariante comprobable con la batería: **`fields do → migración →
esquema → fields do` tiene que ser un punto fijo.**

El primer intento ya lo tenía escrito (`declarations_from_schema.rb`, en el tag
`intento-1-update`) y **conviene rescatarlo** — también lo necesita `hobo:install`
sobre una app que ya existe, que es de otra fase.

**Decisión (2026-08-07):** se queda. Esta fase es **solo para aplicaciones
nuevas**, así que lo de las migraciones de **datos** no bloquea; cuando alguien
lo necesite, se verá. Pendiente para la capa 7: rescatar el generador inverso.

## La duda abierta: el sustrato de DRYML

**Esta es la decisión más grande y está sin tomar.** Se decide al empezar la
capa 3, con un spike, no antes.

Ojo con no confundir dos cosas: *dónde se declaran* los permisos (en el modelo —
eso no está en juego) y *dónde se aplican los de lectura* (la pregunta estrecha).
Que «los formularios se construyan solos según los permisos» funciona igual en
cualquier opción, porque el formulario le **pregunta al modelo**
(`editable_by?`, `viewable_by?`).

### Lo que hay que conservar de DRYML pase lo que pase

1. **`param`** — puntos de extensión declarados **en el marcado**, sin API
   previa. Es el mecanismo entero del contrato de temas.
2. **`<extend>` / `<old-x>`** — extender un tag desde otra gema sin saber de qué
   clase hereda. Es lo que permite apilar temas.
3. **Despacho polimórfico por tipo** (`for="date"`).
4. **El contexto implícito `this`** — sin él, el actualizador baja del ~95% al ~70%.

### Las opciones

| | Sustrato | `param` | `<extend>` | Coste |
|---|---|---|---|---|
| **A** | DSL en Ruby puro (estilo Phlex) | Método con bloque y valor por defecto | `prepend` + `super`, nativo | Todo el mundo escribe Ruby, no marcado |
| **B** | Encima de ERB (estilo ViewComponent) | Slots, pero **hay que declararlos en Ruby por adelantado** | **Sin equivalente limpio** | Familiar, pero un tema no puede añadir un param que la base no declaró |
| **C** | Encima de Slim/Haml | Igual que B | Igual que B | Añade otra sintaxis de la que depender |
| **D** | Conservar DRYML | Ya lo tiene | Ya lo tiene | Sin resaltado, sin LSP, curva de entrada; 3.600 líneas propias |

**La pregunta que decide** no es cuál se lee mejor, sino: *¿cuál puede expresar
`param` y `<extend>` sin inventarse un parser?* Hoy la respuesta parece que **A
los obtiene gratis de Ruby** y **B/C necesitan andamiaje para cada uno**, con
`<extend>` sin encaje claro. El spike tiene que confirmarlo o desmentirlo con
código real.

**El spike ya está hecho: `spike/dryml/`.** Se ejecuta con
`ruby spike/dryml/a_ruby_dsl.rb`. Resultado resumido:

| Propiedad | A · DSL en Ruby | B · ViewComponent + ERB |
|---|---|---|
| `param` | Sí, un método con bloque | Slots **declarados en Ruby por adelantado** |
| `param` anidado | Sí, sale solo | **No**, los slots son una lista plana |
| `<old-x>` (envolver el defecto) | Sí | **No**, un slot solo sustituye |
| `<extend>` desde otra gema | `Module#prepend` + `super` | **No** llega a quien ya usa la clase |
| Polimórfico por tipo | Registro de ~10 líneas | Hay que escribir el mismo registro |
| Dependencias | **Ninguna** | Rails entero arrancado |
| Runtime | **~50 líneas** | ViewComponent + ActionView |

**El punto que decide:** en ViewComponent un slot **solo sustituye, no envuelve**
— y eso es *exactamente* el fallo del primer intento documentado en
`HALLAZGOS.md`. Elegir B nos devolvería al problema del que veníamos.

## DECISIÓN TOMADA: opción A (2026-08-07)

Imanol elige el **DSL en Ruby**, con el spike delante.

### Y el spike C ya avisó de lo que cuesta

Se portó `<table-plus>` (58 líneas, el peor caso del catálogo) a
`spike/dryml/c_table_plus.rb`. **Funciona**: params con nombre calculado en
tiempo de ejecución, `attrs_for`, `scope`, `all_parameters`, `merge-params`,
atributos con guiones. Todo verificado ejecutando.

**Pero un `param` se perdió en silencio**, que es *exactamente* el modo de fallo
del primer intento. Causa:

> En DRYML, un `param` declarado dentro de un bloque que le pasas a **otro** tag
> pertenece al tag **que lo escribió**, no al que lo ejecuta.

El runtime ingenuo hacía `instance_exec` en el que ejecuta, así que el `param`
se buscaba en el sitio equivocado. Se arregla con `override.call` —los bloques de
Ruby capturan `self` léxicamente— **pero eso obliga a dos cambios de
arquitectura**:

1. **Los tags devuelven cadenas**, no escriben en un buffer compartido. Si no, el
   bloque escribiría en el buffer de quien lo definió y el HTML saldría
   desordenado.
2. **`this` y `scope` son una pila dinámica**, no estado de instancia. El bloque
   necesita el contexto de *quien lo ejecuta*.

**Y eso explica `part_context.rb` y la pila de `scoped_variables` de DRYML: no
eran complejidad gratuita, eran esta necesidad.**

**Consecuencia para el plan:** el runtime no son 50 líneas. Sigue siendo mucho
menos que las 1.700 del compilador de DRYML, pero hay que entrar sabiéndolo.

**Requisito no negociable de la capa 3:** una prueba que exija que **todo `param`
declarado sigue siendo alcanzable**. Sin ella, el diseño que sea volverá a perder
params de uno en uno y en silencio.

### La prueba de contrato (2026-08-07) — **hecha**

Vive en `spike/dryml/test/`, corre con `rake test` desde la raíz y son **17
pruebas, 137 aserciones, en verde**. Se muda a la gema `dryml` sin tocarla
cuando el runtime salga de `spike/`.

**Lo importante es cómo está hecha: no hay una lista de params escrita a mano.**
Esa lista es justo lo que se queda vieja. En vez de eso, `param_contract.rb`
antepone un grabador a `Rapid::Tag#param`, **renderiza el tag y apunta cada
`param` que la ejecución alcanza de verdad** —incluidos los de nombre calculado—
y luego, uno por uno, **vuelve a renderizar pasando un centinela** y exige que
salga en la salida.

> Un param que nadie puede alcanzar es un param que no existe.

Como hay params detrás de un `if` (las flechas de ordenación), la comprobación
toma **varios escenarios** y une lo alcanzado en todos.

**Las excepciones se auditan solas.** `except:` documenta por qué un param no se
puede sobreescribir desde fuera, y la prueba comprueba **las dos direcciones**:
que sigue siendo inalcanzable, y que sigue existiendo. Una excepción que se
quedó vieja **falla**.

**La prueba tiene dientes, y se demuestra.** `ParamContractTeethTest` reconstruye
el runtime ingenuo de spike C (`instance_exec` en vez de `call`) en un par de
tags y exige que **la comprobación falle**, nombrando el param perdido. Los
mismos dos tags sobre el runtime bueno pasan. Una comprobación que nunca falla es
peor que ninguna.

### Y encontró un segundo fallo silencioso: `old` no emitía nada

`<old-x>` —envolver el valor por defecto en vez de sustituirlo— **estaba roto**.
`Rapid.render(:panel, {}, :heading => Rapid.markup { tag("div") { old } })`
devolvía `<div class="wrap"></div>`: el envoltorio vacío, sin error.

La causa es **la misma lección de spike C, aplicada a medias**: `@old_stack` era
estado de instancia del tag que *ejecuta* el `param`, pero `old` se llama desde
el override, que corre con el `self` del tag que lo *escribió* — otro objeto, con
su pila vacía.

Arreglado: la pila de defectos pasa a `Rapid::Context`, junto al buffer, `this` y
`scope`, y se **desapila mientras corre** para que un `old` dentro de un defecto
no se llame a sí mismo. **Es exactamente el mismo error del que veníamos, y
reapareció a un metro de donde lo habíamos arreglado.** La prueba lo cazó el
primer día.

### Los params anidados (2026-08-07) — **hechos**

El barrido dejó documentado un hueco: `:field_heading_row` y `:default` son
params de `<table>` y de `<with-field-names>`, no de `<table-plus>`, y no había
forma de alcanzarlos desde fuera. Eso es la **sintaxis de params anidados** de
DRYML, `<table:><field-heading-row:>…</table:>`, y ya está.

**Al implementarla apareció que un param no es un bloque de contenido.** Los
`.feature` de cucumber de `dryml/` son la especificación, y dicen que una
etiqueta de parámetro lleva **cuatro cosas**:

| DRYML | Ruby |
|---|---|
| `<heading:>Title</heading:>` | `Rapid.parameter { text "Title" }` |
| `<heading: class="big">` | `Rapid.parameter(:attributes => { :class => "big" })` |
| `<heading: replace>` | `Rapid.parameter(:replace => true)` |
| `<table:><row:>…</row:></table:>` | `Rapid.parameter(:params => { :row => … })` |

Y de ahí salen **las reglas que el runtime no tenía**:

1. **Rellenar un param conserva el elemento**: `<h3 param="heading">` con
   `<heading:>X</heading:>` da `<h3>X</h3>`, no `X`. Antes sustituía el elemento
   entero. **`replace` es lo que se lo lleva**, y entonces `old` emite el
   elemento original — que es el `<x: restore/>` de DRYML, y sale gratis.
2. **Los atributos se fusionan**, y `class` se **concatena**: `class="card"` con
   `<card: class="odd">` da `class="card odd"`.
3. **Un param sin contenido propio deja el defecto en paz.** Es lo que permite
   `<card: class="x">` sin tocar el interior, y lo que hace que un param anidado
   solo aporte lo suyo.
4. **Los params anidados solo tienen sentido en una llamada a otro tag.** En un
   elemento no hay params de nadie a los que pasarlos, así que **se lanza un
   error en vez de tragárselos**.
5. **Los params anidados del que llama ganan** a los que el tag rellena por su
   cuenta. Si no, no serían un punto de extensión.

**Un tag expone la llamada con `as:`**, que es el `<search-filter param/>`
pelado. Sin eso no hay nada que lleve hasta los params del tag llamado, y **eso
es lo que la prueba ahora sabe distinguir**: no es lo mismo «se perdió en
silencio» que «nadie expuso la llamada».

### La prueba de contrato aprendió a navegar

Ya no prueba solo el nivel de arriba. Cada tag conoce **su dirección**
(`param_path`): la lista de params por los que hay que anidar para llegar a él,
o `nil` si nada lleva hasta ahí. El grabador la apunta con cada param, y el
barrido **construye el anidamiento solo**, a la profundidad que haga falta:

```ruby
# dirección [:table, :field_heading_row]
:table => Rapid.parameter(:params => { :field_heading_row => centinela })
```

Y usa **dos sondas**, porque son dos promesas distintas:

- **`replace`** — se le exige a **todos** los params: el que llama puede quitar
  el punto de extensión y poner lo suyo.
- **rellenar** — se le exige a los params **de elemento y a los pelados**, no a
  las llamadas a otro tag: el tag llamado es libre de ignorar el contenido que
  le den, y `<search-filter>` lo ignora. Exigírselo sería mentir.

El gancho pasó de `param` a `parameter_for`, que es lo único que comparten los
**tres tipos de sitio** (param pelado, elemento con param, llamada expuesta con
`as:`). Enganchado a `param` se perdía dos de los tres.

**`<table-plus>` queda con una sola excepción**, y no es un fallo del runtime:
`<table-plus>` llama a `<with-field-names>` **sin exponer la llamada**, así que
a sus params no llega nadie. Es una decisión de `<table-plus>`, y está escrita.

### El segundo tag grande: `<form>` (2026-08-07) — **portado**

`spike/dryml/d_form.rb`, con su barrido en `test/form_contract_test.rb`.

Se eligió porque **no se parece en nada a `<table-plus>`**. `<form>` son en
realidad **dos tags**:

- el **base** (`hobo_rapid/taglibs/forms/form.dryml`): polimórfico, diez líneas
  de marcado, **ningún param**, y todo el trabajo en un helper de Ruby
  (`form_helper`, `hobo_rapid_helper.rb:106`);
- el **generado por modelo** (`hobo/lib/hobo/rapid/generators/rapid/forms.dryml.erb`),
  que es donde viven los params: `error-messages`, `field-list`, `actions`,
  `submit`, `cancel`.

Así que ejercita lo que `<table-plus>` no tocaba: **despacho polimórfico por el
modelo**, `merge` en una llamada, una llamada expuesta como `param="default"`, y
**params que viven una y dos llamadas más abajo** del tag que el que llama
nombra.

El barrido encuentra **16 params, en tres tipos de sitio y hasta dos niveles de
profundidad, y ninguna excepción**:

```
default                     call        field_list > title_field   element
default > default           bare        field_list > title_label   element
error_messages              call        field_list > title_view    bare
field_list                  call        field_list > title_tag     call
field_list > fieldset       element     actions / submit / cancel  …
```

**Se quedó fuera** lo que es Rails y no runtime de tags: enrutado, protección
contra falsificación, i18n y los permisos de verdad del modelo. `<field-list>`
va reducido: el de verdad es `<feckless-fieldset>`, y lo que importaba de él era
que declara **un param por campo con nombre calculado**.

### Los tres fallos que destapó el port

1. **Un `<def tag="form" for="Story">` que llama a `<form>` se llamaba a sí
   mismo**, hasta desbordar la pila. En DRYML esa llamada va a la **definición
   base**, como un `super`. Arreglado con `from:`: un tag polimórfico **nunca
   despacha a la clase que hace la llamada**. Es léxico —lo decide quién escribió
   la llamada— y no dinámico.
2. **Los elementos vacíos llevaban etiqueta de cierre**: salía
   `<input …></input>`. Ahora `<input>`, `<br>`, `<img>` y compañía se emiten
   solos, y **rellenar uno con contenido lanza un error** en vez de escribir
   HTML inválido: para poner algo en su sitio hace falta `replace`.
3. **El grabador del barrido deduplicaba por nombre, no por dirección.** Dos
   params con el mismo nombre a distinta profundidad son **dos puntos de
   extensión distintos**, y el de dentro se perdía. Con `<table-plus>` no se
   notaba; con `<form>`, que tiene `default` y `default > default`, sí.
   **La prueba de contrato tenía ella misma el fallo que persigue.**

### Los pseudo-params (2026-08-07) — **hechos**

Los cinco, contra los escenarios de
`dryml/features/cookbook/06_pseudo_parameters.feature`:

| DRYML | Dónde cae |
|---|---|
| `<before-x:>` | **fuera**, antes del elemento o de la llamada entera |
| `<prepend-x:>` | **dentro**, antes del contenido |
| `<append-x:>` | **dentro**, después del contenido |
| `<after-x:>` | **fuera**, después |
| `without-x` | **quita el punto de extensión**; es un atributo, y se consume |

Lo importante es que **no hacen falta si el param no se ha sobreescrito**: un
`<append-heading:>` suelto tiene que añadirse al encabezado por defecto, y eso es
justo para lo que sirven.

**Dónde cae «dentro» depende del tipo de sitio**, y ahí estaba la miga:

- **param pelado** y **elemento**: dentro del contenido, y en el elemento, dentro
  de la etiqueta.
- **llamada a otro tag**: dentro del **contenido que se le pasa a la llamada**,
  o sea su param `default`. Es lo que hace que el `<append-decorated-help:>` del
  `.feature` acabe **dentro** del `<a>` y no detrás.

Cuando el que llama no le pasó contenido a la llamada, el envoltorio se apoya en
`old`, que alcanza el defecto que declare el tag llamado. Y si ese tag **no pinta
nunca el contenido que le dan** —`<submit>` es así—, un `append` **lanza un
error** en vez de desaparecer. Es un modo de fallo asumido a conciencia: puede
saltar en un tag que pinte su contenido solo bajo condición, y aun así se
prefiere a perderlo en silencio.

**Dos fallos más, encontrados al escribir las pruebas:**

1. **`<x: replace/>` sin contenido no quitaba el elemento**, se quedaba el
   original. El `.feature` dice que desaparece.
2. **`merge-params` aplicaba el pseudo-param dos veces.** `<form>` reenvía sus
   params al `<form>` base, que declara un param con **el mismo nombre**, así
   que el `append` caía en los dos niveles. Se arregla **consumiéndolos donde se
   escribieron**. Es otra vez la ambigüedad nombre/dirección, la misma que se
   comió el `default > default` del grabador.

### El runtime ya es la gema (2026-08-07)

Sale de `spike/` y entra en **`dryml`**, que es la unidad de trabajo de esta capa
(se fundirá en la gema única en la capa 7, decisión 12).

| Qué | Dónde |
|---|---|
| El runtime | `dryml/lib/rapid.rb` + `dryml/lib/rapid/{scope,context,parameter,tag}.rb` |
| La prueba de contrato | `dryml/lib/rapid/param_contract.rb` |
| Sus pruebas | `dryml/test/rapid/*_test.rb` |
| Los dos tags portados | `dryml/test/tags/{table_plus,form}.rb` |
| Cómo se eligió el sustrato | `spike/dryml/`, ya sin código vivo |

**Las 63 pruebas pasaron sin tocar una línea**, que era la comprobación de que el
runtime no dependía de dónde vivía.

**La prueba de contrato va en `lib/`, no en `test/`**, y es a propósito: la van a
necesitar las gemas de arriba. Cuando la capa 5 porte el catálogo y la capa 6 el
tema, sus pruebas hacen `require "rapid/param_contract"` y le pasan el mismo
barrido a sus tags. Es la pieza que impide que el catálogo entero se llene de
params perdidos en silencio.

**Se aprovechó para sacar del runtime lo que no era runtime:** `AJAX_ATTRS`,
`controller_ivar` y `default_row` son catálogo RAPID, no motor, y se van a
`dryml/test/tags/rapid_helpers.rb` hasta que la capa 5 los ponga en su sitio.
`Hash#partition_hash` deja de tener copia propia: **se usa el de `hobo_support`**.

**Del andamiaje viejo de la gema:** el gemspec pasa a `rails >= 8.0`,
`hobo_support` y `required_ruby_version >= 3.2`, fuera `rubyforge_project` y las
pinzas de `cucumber ~> 1.1` y `aruba ~> 0.4.6`; el `Gemfile` apunta a
`../hobo_support`. Fuera también `ext/mkrf_conf.rb`, una extensión de 2011 que
solo existía para comprobar que openssl estaba instalado.

**Lo que NO se toca:** `dryml/lib/dryml/` entero —el compilador y su parser— se
queda. No es código muerto: el parser es el front-end del actualizador que
migrará las plantillas de las aplicaciones que ya existen (decisión 6). Y los 87
escenarios de `features/` y `test/dryml.rdoctest` **se conservan sin ejecutar**:
son la especificación de la semántica, y se leen, no se corren.

`dryml` pasa a `PORTED_GEMS` en el `Rakefile` de la raíz. Queda `hobo` sin portar.

### Lo que queda de la sintaxis de parámetros

Sin hacer, y anotado para no confundirlo con lo que sí está:

- **`<x: param>` / `<x: param="otro">`** — que un tag reexponga con otro nombre
  un param del tag al que llama. Es lo que hace `<linked-card>` en los
  `.feature`.
- **`merge-params="bar"`** con lista de nombres; hoy `merge_params` es todo o nada.
- El **nombre del param como clase CSS** (`<div param="body">` → `class="body"`).
  Aparece en los `.feature` pero no en `template.rb`: hay que averiguar de dónde
  sale antes de copiarlo. Es convención de pintado, no del mecanismo, así que
  puede esperar a la capa 6.

---

## El plan por capas

Estado: `[ ]` pendiente · `[~]` en curso · `[x]` hecho

| | Capa | Qué | Piezas |
|---|---|---|---|
| `[x]` | **0** | **Banco de pruebas**: andamiaje minitest y corredor de la raíz | — |
| `[x]` | **1** | `hobo_support`: quitar ~230 líneas de azúcar, codemod de 113 sitios, `classy_module` → `Concern` | 16 |
| `[x]` | **2** | `hobo_fields`: `fields do`, tipos ricos, migraciones **+ batería que ejecute `up` y `down`** | 1, 2, 3 |
| `[x]` | **3** | **El remix de DRYML**: runtime, contrato de params, params anidados, pseudo-params y dos tags grandes portados. Ya es la gema `dryml` | 8 |
| `[x]` | **4** | `hobo`: permisos, lifecycles, view hints, auto-actions, router, subsites | 4, 5, 6, 7, 11, 12, 14 |
| `[x]` | **5** | El JS a Stimulus (decisión 14), `hobo_rapid` y el motor de derivación | 9, 10 |
| `[x]` | **6** | Separado `hobo_bootstrap`: estructura a RAPID, tema en Bootstrap 5 con su contrato probado | 13a, 13b |
| `[x]` | **7** | `hobo new`, generadores, **la fusión en una sola gema** y **el contrato de plugin** con un plugin de verdad (`hobo_timeago`) | 17 |

**Riesgo asumido conscientemente:** de abajo arriba no se ve una página hasta la
capa 6. Imanol lo acepta a cambio de hacerlo bien. El spike de la capa 3 es lo
que evita que ese riesgo se convierta en el desastre del primer intento.

---

## Capa 0 — lo que se encontró (2026-08-07)

**No hay que construir un banco de pruebas: hay uno heredado, y es mejor de lo
esperado.** Herramienta disponible: Ruby **3.4.6** y Rails **8.1.3.1** vía rbenv.

### Las pruebas que ya existen

| Gema | Formato | Ficheros | Volumen |
|---|---|---:|---|
| `hobo_support` | rubydoctest | 8 | 603 líneas, 75 aserciones |
| `hobo_fields` | rubydoctest | 8 | 1.473 líneas, 142 aserciones |
| `hobo` | rubydoctest + **irt** | 4 + 20 | 49 + 31 aserciones |
| `dryml` | **cucumber** | 26 | 2.366 líneas, 87 escenarios |

**No hay ni un minitest ni un rspec en las gemas del núcleo.**

### Estado de las tres herramientas

| Herramienta | Último release | ¿Vive en Ruby 3.4? |
|---|---|---|
| `rubydoctest` | 2014-12-31 | **Sí — probado y funcionando** |
| `irt` | 2015-09-24 | Sin probar |
| `cucumber` | 2026-06-25 | Vivo y mantenido |

Los 87 escenarios de cucumber de `dryml` describen contexto implícito, params,
tags polimórficos y merge de parámetros: son **la especificación de la semántica
que queremos conservar** en el remix. No tirarlos sin leerlos.

### Lo que rompe hoy

1. **`blankslate`**: la gema no existe ya, y `methodcall.rb:10` la requiere. Con
   eso `hobo_support` **no carga** en Ruby 3.4. Es justo el fichero que la capa 1
   borra, así que se arregla solo.
2. **Ruby 3.4 cambió `Hash#inspect`**: `{:a=>1}` ahora es `{a: 1}` y `{1=>2}` es
   `{1 => 2}`. Los doctests comparan la salida de `inspect` como cadena, así que
   **21 líneas** de `hash`, `enumerable`, `rich_types` y `migration_generator`
   fallan por formato. Mecánico.
3. El `Gemfile` de `hobo_support` apunta a `git://github.com/tslocke/rubydoctest`
   — protocolo muerto desde 2022.
4. El gemspec pinza `rails >= 4.2.7.1, < 5.0`.

### El banco de integración: `agility_bootstrap`

En `integration_tests/` hay dos aplicaciones Hobo completas: `agility`
(Rails 3.2) y **`agility_bootstrap` (Rails 4.2)**. La segunda es el banco:

- **13 modelos** y 12 controladores
- **22 ficheros de prueba**, con fixtures y factories
- **7 pruebas de integración**: `ajax_form`, `create_account`, `dialog`,
  `editors`, `lifecycle`, `nested_has_many`, `search`
- Usa `hobo_bootstrap`, que ya está vendorizado

Y ejercita justo las piezas del plan. Su `Story` tiene `fields do` con tipos
ricos (`:markdown`, `Color`), los cuatro permisos incluido
`view_permitted?(field)`, `:accessible => true` y `children :tasks`.

**Es el objetivo, no la herramienta del día a día**: no podrá arrancar hasta la
capa 5 o 6. Para las capas 1 y 2 hace falta que corra el `rake test` de cada
gema por separado.

### Lo que se hizo en la capa 0 — **terminada**

**El andamiaje de minitest, no el port entero.** Cada gema se porta en su capa.

- `hobo_support/test/test_helper.rb` y `hobo_support/Rakefile` con
  `Rake::TestTask`. **Ese es el patrón** a repetir en cada gema.
- `hobo_support/test/hobo_support/hash_test.rb` — primer fichero portado, de
  `test/hobosupport/hash.rdoctest`. **13 pruebas, verdes.**
- El `Rakefile` de la raíz tiene ahora dos listas, `PORTED_GEMS` y
  `PENDING_GEMS`: `rake test` corre las portadas y **dice en voz alta cuáles
  faltan**, para que el hueco no se olvide.
- `hobo_support` **ya carga en Ruby 3.4 con Rails 8.1**. Lo único que hacía falta
  era que `methodcall.rb` y `methodphitamine.rb` requirieran el `BlankSlate`
  local en vez de la gema `blankslate`, que ya no existe.
- `hobo_support.gemspec`: `rails >= 8.0` (antes `< 5.0`), `required_ruby_version
  >= 3.2`, fuera `rubyforge_project`. `Gemfile` limpio, sin el `git://` muerto.

**Nota:** el problema de `Hash#inspect` de Ruby 3.4 **desaparece solo** al portar
a minitest, porque minitest compara objetos y no la cadena de `inspect`. Los 21
sitios afectados dejan de importar en cuanto se porta cada fichero.

Se comprobó además que los *overrides* de `HashWithIndifferentAccess` en
`hash.rb` **siguen activos** en Rails 8.1 (`partition_hash` normaliza `:a` a
`"a"` correctamente). No hay problema ahí.

## Capa 1 — inventario del azúcar (2026-08-07)

**Son 146 sitios, no 113.** La cuenta anterior era solo `.rb` de cuatro gemas.

| Operador | Sitios | Traducción | Dónde vive |
|---|---:|---|---|
| `.*.foo` | 52 | `map(&:foo)` | `enumerable.rb` + `array.rb` |
| `.try.foo` | 43 | `try(:foo)` | `methodcall.rb` |
| `._?.foo` | 42 | `&.foo` | `methodcall.rb` |
| `.where.foo` | 8 | `select(&:foo)` | `enumerable.rb` |
| `.where_not.foo` | 1 | `reject(&:foo)` | `enumerable.rb` |

Por gema: `hobo` 51, `dryml` 24, `hobo_rapid` 24, `hobo_fields` 19, `hobo_support` 8,
`hobo_jquery_ui` 8, `hobo_bootstrap` 2, `hobo_bootstrap_ui` 2, `hobo_clean` 1.

### Dos propiedades de seguridad, verificadas

1. **Nada falla en silencio.** Sin `methodcall.rb`, `x.try.foo` lanza
   `TypeError: nil is not a symbol nor a string`, y `x.*.foo` sin `Enumerable#*`
   lanza `NoMethodError`. Un sitio que se escape **se ve**.
2. **`.try.` sí llama a métodos privados** (usa `send`), mientras que
   `try(:foo)` de ActiveSupport **devuelve nil** con los privados (usa
   `respond_to?`). Se revisaron los **33 métodos distintos** que se invocan con
   `.try.` y **ninguno es privado**, así que la traducción es segura. Anotado por
   si aparece uno nuevo.

### Los 16 casos dudosos

**Grupo 1 — `._?` sin llamada detrás (5).** `&.` exige un método; estos indexan o
comparan. Se leen mejor como `x && x[k]`.

| Sitio | Código |
|---|---|
| `hobo_fields/lib/generators/hobo/migration/migrator.rb:164` | `renames._?[table_name.to_sym]` |
| `hobo/lib/hobo/model.rb:391` | `attr_type(attr)._? <= String` |
| `hobo/app/helpers/hobo_route_helper.rb:24` | `params[:controller]._?.match(/…/)._?[1]` |
| `hobo/app/helpers/hobo_route_helper.rb:156` | `request.fullpath.match(/…/)._?[1]` |
| `hobo/app/helpers/hobo_permissions_helper.rb:8` | `session._?[:user]` |

**Grupo 2 — `.*.` con argumentos o bloque (4).** No traducen a `map(&:sym)`.

| Sitio | Código |
|---|---|
| `dryml/lib/dryml/template.rb:669` | `.*.gsub("-", "_").*.to_sym` |
| `dryml/lib/dryml/template.rb:846` | `.*.gsub("-", "_").*.to_sym` |
| `hobo_bootstrap_ui/taglibs/typeahead.dryml:36` | `.*.send(complete_target.name_attribute)` |
| `hobo_jquery_ui/taglibs/autocomplete.dryml:38` | `.*.send(complete_target.name_attribute)` |

**Grupo 3 — `.*.` encadenado (2).**

| Sitio | Código |
|---|---|
| `hobo_support/lib/generators/hobo_support/model.rb:34` | `attributes.*.name.*.length.max` |
| `hobo_fields/lib/generators/hobo/migration/migrator.rb:124` | `.*.to_s.*.underscore` |

**Grupo 4 — `.where.` / `.where_not.` (7 reales).**

| Sitio | Código |
|---|---|
| `hobo/lib/hobo/model/lifecycles/lifecycle.rb:61` | `creators.values.where.publishable?` |
| `hobo/lib/hobo/model/lifecycles/lifecycle.rb:65` | `transitions.where.publishable?` |
| `hobo/lib/generators/hobo/routes/router.rb:79` | `.where.routable_for?(@subsite)` ← con argumento |
| `hobo/lib/generators/hobo/routes/router.rb:87` | idem |
| `hobo/lib/generators/hobo/routes/router.rb:138` | idem |
| `hobo/lib/generators/hobo/routes/router.rb:142` | idem |
| `dryml/lib/dryml/dryml_doc.rb:125` | `.where_not.blank?` |

**Falsos positivos**, aquí `where` es un atributo de `IndexSpec`, no el operador:
`hobo_fields/lib/hobo_fields/model/index_spec.rb:14` y `:35`. **No tocar.**

> ⚠ **`Enumerable#where` colisiona con `ActiveRecord::Relation#where`.** Hoy no
> explota porque todos los receptores son Arrays (`Hash#values`, `split`). Pero
> si alguno pasara a ser una Relation, `.where.publishable?` llamaría al `where`
> de ActiveRecord y devolvería un `WhereChain`. Es un fallo latente que
> **desaparece al quitar el operador**.

**Grupo 5 — `Array#*` está sobrecargado.** `array.rb` lo redefine con argumento
opcional: **con** argumento hace join/repetir (delegando en el original, que
guarda como `multiply`), **sin** argumento devuelve el `MultiSender`. Al quitar
el override, Ruby recupera su `Array#*` nativo y los **~23 sitios** de
`array * ", "` siguen funcionando igual. Es seguro, pero es el borrado que más
conviene comprobar porque `*` sobre arrays se usa mucho fuera del azúcar.

### Lo que se hizo en la capa 1 — **casi terminada**

`hobo_support` pasa de **1.089 a 691 líneas**. 28 pruebas minitest en verde.

**Primera pasada, lo roto** (commit `8d9abd53`): fuera `methodcall.rb`,
`methodphitamine.rb` y `blankslate.rb`, y con ellos `.*.`, `._?`, `.try.`,
`.where.`, `.where_not.` e `it`/`its`. Reescritos los 146 sitios: 62 ficheros
por codemod y 16 a mano. Fuera también `alias_class_method_chain` y las guardas
muertas de `drop_while`, `take_while` y `Array.wrap`.

**Segunda pasada, lo redundante** (commit `22e45f08`): ver el registro de mejoras
más abajo. ~45 sitios más reescritos.

**Tercera pasada, `classy_module`.** Eran 14 usos. Se convirtieron **3** y los
**11 restantes se reparten por capas**, con criterio, no por pereza:

| Convertido ahora | Cómo |
|---|---|
| `hobo/lib/hobo/model/include_in_save.rb` | `Concern` con `included do` para los callbacks |
| `hobo/lib/hobo/model/lifecycles.rb` (`ModelExtensions`) | `Concern` con `class_methods do`; de paso se quita el `eval %(...)` que envolvía `valid?` para esquivar un fallo de Ruby 1.9.2 que ya no existe |
| `dryml/lib/dryml/dryml_doc.rb` (`CommentMethods`) | Módulo normal: eran solo métodos de instancia, no hacía falta `Concern` |

| Aplazado | A la capa | Por qué |
|---|---|---|
| `hobo_fields/lib/hobo_fields/model.rb` | **2** | Lleva **3 `alias_method_chain`** que hay que pasar a `prepend`: se reescribe entero de todas formas |
| `hobo/lib/hobo/model/accessible_associations.rb` | **4** | Igual, con **5 `alias_method_chain`** |

> **Corrección (2026-08-07):** al principio se dio por hecho que esos
> `alias_method_chain` estaban rotos porque Rails los borró en 5.1. **No lo
> están:** `hobo_support/lib/hobo_support/fixes/module.rb` define su propia
> versión, y los 48 sitios del repo funcionan. El motivo para cambiarlos es de
> calidad, no de urgencia.
| 6 generadores de Thor (`controller`, `subsite`, `plugin`, `taglib`, `invite_only`, `activation_email`) | **7** | El DSL de Thor (`argument`, `class_option`) se ejecuta a nivel de clase, así que en un `Concern` va dentro de `included do`. No es mecánico y no se puede verificar hasta que se toquen los generadores |
| `hobo_support/lib/generators/hobo_support/{model,eval_template}.rb` | **7** | Lo mismo, son de Thor |
| `hobo_support/lib/hobo_support/common_tasks.rb` | **2 y 4** | No es candidato a `Concern`: son tareas de Rake (`namespace :test do`) envueltas para incluirlas en un Rakefile. Solo lo usan los `Rakefile` viejos de `hobo` y `hobo_fields`, así que **muere con ellos** al portar sus pruebas |

`classy_module` sigue en `module.rb` hasta que caiga el último uso, en la capa 7.

---

## Registro de mejoras por capa

Se anota, en cada capa, en qué gana Rails y en qué gana Hobo. Las dos
direcciones cuentan.

### Capa 1

**Rails/Ruby lo hace mejor → fuera** (todo verificado ejecutando):

| Hobo | Nativo | Desde |
|---|---|---|
| `Hash#select_hash` | `Hash#select` ya devuelve Hash | Ruby 2.1 |
| `Hash#map_hash` | `transform_values` | Ruby 2.4 |
| `hash - [k]` | `except(k)` | Ruby 3.0 |
| `hash & [k]` | `slice(k)` | Ruby 2.5 |
| `hash.get(a,b)` | `values_at(a,b)` | siempre |
| `Hash#compact`/`compact!` | core | Ruby 2.4 |
| `recursive_update` | `deep_merge!` | Rails 3 |
| `hash \| otro` | era alias de `merge` | siempre |
| `metaclass` | `singleton_class` | Ruby 1.9 |
| `meta_eval` | `singleton_class.instance_eval` | Ruby 1.9 |
| `metaclass_eval` | `singleton_class.class_eval` | Ruby 1.9 |
| `meta_def` | `define_singleton_method` | Ruby 1.9 |
| `Enumerable#map_hash` | `index_with` | Rails 6 |
| `Enumerable#rest` | `drop(1)` | siempre |
| `map_with_index` | `map.with_index` | Ruby 1.9 |
| `build_hash` | `filter_map { }.to_h` | Ruby 2.7 |

**Hobo lo hace mejor → se queda:**

- **`Object#in?` es nil-safe.** El de ActiveSupport lanza `ArgumentError` con
  `nil`. Y **`not_in?` no existe en Rails**.
- **`Hash#partition_hash`** (39 usos). `Hash#partition` de Ruby devuelve arrays
  de pares, **no hashes**. Sin equivalente.
- **`implies`.** No existe en ningún sitio; lo usan los permisos.
- **`Array#safe_join`.** El `safe_join` de Rails es un helper de vista, no un
  método de Array.

**En medio:** `inheriting_cattr_reader` vs `class_attribute`. Rails hereda igual
de bien, pero `class_attribute` **además define un writer de instancia**, efecto
que Hobo no quiere. Evitable con `:instance_writer => false`, pero no es gratis.

### Capa 2

**Rails 8 lo hace mejor → fuera:**

| Hobo | Nativo | Nota |
|---|---|---|
| Sobreescribir `_read_attribute` y `define_method_attribute=` | **Attributes API** (`attribute name, TypeObject`) | Desde Rails 4.2. Se van 47 líneas de parches. Y los dos parches estaban **rotos**: `define_method_attribute=` cambió a `(canonical_name, owner:, as:)`, y la versión de Hobo de `_read_attribute` **se comía el bloque** que Rails le pasa |
| `BlankSlate` | `BasicObject` | Existe justo para esto |
| `case connection.class.name` | `connection.adapter_name` | La clase del adaptador ha cambiado de sitio varias veces |
| `ActiveRecord::Base.send(:descendants)` | `descendants` es **público** | |
| `ActiveRecord::SchemaDumper.new` a mano | `connection.create_schema_dumper({})` | Fallo nº1 de `HALLAZGOS.md`, reproducido en vivo |

**Hobo lo hace mejor → se queda:** ver «¿Merece la pena `hobo_fields` en 2026?».

### Lo que se hizo en la capa 2

`hobo_fields` **carga y funciona sobre Ruby 3.4 y Rails 8.1**. **50 pruebas
minitest, 116 aserciones, en verde** (3 *skip* por `kramdown` y `RedCloth`, que
no están instaladas).

**Roturas de carga arregladas:** `FieldDeclarationDsl` heredaba de `BlankSlate`
(borrado en la capa 1) → `BasicObject`, con sus constantes ancladas en la raíz
porque `BasicObject` no tiene `Object` en su cadena. Los tipos se requerían por
orden alfabético, así que `html_string` cargaba antes que su padre
`raw_html_string`. `sanitize_html` no requería `action_view`.

**Fallos reales encontrados y corregidos:**

| Dónde | Qué |
|---|---|
| `migrator.rb` `revert_table` | El fallo nº1 de HALLAZGOS, **reproducido**: con el volcador construido a mano, Rails 8 no lanza, escribe un comentario — y el `down` salía **sin tipos de columna**, con `add_column :adverts, :body,` a medias |
| `migrator.rb` `load_rails_models` | `Rails.application.eager_load!` sin guarda: fuera de una app Rails no arrancaba |
| `migrator.rb` `table_model_classes` | `c.name.starts_with?` revienta con clases anónimas, que tienen `name` a `nil` |
| `migrator.rb:309` | `to_remove - [primary_key.to_sym]` sobre un array de **cadenas**: no quitaba nada nunca |
| `model.rb` `belongs_to` | Desde Rails 5 la firma es `(name, scope = nil, **options)`. Hobo pasaba el hash **posicionalmente**, así que Rails lo tomaba por el scope y le pedía `arity` |
| `model.rb:65` | `public` sin argumentos dentro de un método: desde Ruby 3.0 no hace nada |
| Dos `.try.` **sin receptor** | Se escaparon de la capa 1 porque el regex exigía un punto delante |
| `migrator.rb:301` | `db_columns -= [...]` sobre un **Hash**: baja de la poda de la capa 1 |

**La batería de la Deuda 1 existe.** `migration_generator_test.rb` no compara
texto: **ejecuta** el `up`, comprueba que el esquema cambió, **ejecuta** el
`down` y comprueba que vuelve exactamente al estado anterior — comparando
nombre, tipo, `limit`, `default`, `null`, `precision`, `scale` e índices.

**La batería corre contra todos los adaptadores alcanzables.** El generador le
pide al adaptador los tipos nativos, el volcado de esquema y la introspección de
columnas, así que **un adaptador contra el que no se prueba es un adaptador que
no se soporta**. Los 18 casos están escritos una vez, en el módulo
`MigrationGeneratorBattery`, y se instancia **una clase de prueba por adaptador
que responda**:

```sh
rake test                                     # sqlite3, siempre
HOBO_TEST_POSTGRES_URL=postgres://user:pass@localhost/hobo_fields_test rake test
HOBO_TEST_MYSQL_URL=mysql2://user:pass@localhost/hobo_fields_test     rake test
```

Los que no responden **no desaparecen**: salen como *skip* con su motivo
(`MigrationGeneratorAdapterCoverageTest`), para que un adaptador ausente no se
confunda nunca con uno que pasa. En la máquina de Imanol solo hay sqlite3.

Las aserciones sobre el **texto** generado son deliberadamente laxas, porque la
redacción cambia de forma legítima entre adaptadores (límites nativos, comillas).
La aserción de verdad es `assert_reversible`, que ejecuta.

**Aislamiento entre pruebas:** quitar la constante de un modelo **no basta**. El
`DescendantsTracker` sigue guardando la clase, y el generador recorre
`descendants`. Sin `ActiveSupport::DescendantsTracker.clear`, un modelo definido
en un fichero de pruebas aparece en todos los siguientes.

Quedan sin portar `generators.rdoctest` e `interactive_primary_key.rdoctest`:
necesitan generadores de Rails y una app de verdad, así que van a la **capa 7**.

### Cómo correr las pruebas

```sh
rake test              # todas las gemas ya portadas
rake test_integration  # agility_bootstrap (no arrancara hasta la capa 5-6)
cd hobo_support && rake test
cd dryml         && rake test   # runtime de tags y contrato de params
cd hobo          && rake test:app && rake test   # con aplicacion Rails de verdad
```

La aplicación de pruebas de la capa 4 se monta en `/tmp/hobo_testapp` con
`rake test:app` (o `rake test:app force=1` para rehacerla). Sin ella, las pruebas
de `hobo/test/integration/` **saltan diciendo cómo montarla**; nunca pasan en
silencio.

---

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Lo que salió mal la primera vez | `HALLAZGOS.md` |
| El código del primer intento | rama `hobo_2027`, tag `intento-1-update` |
| El tema Bootstrap (vendorizado) | `hobo_bootstrap/`, con `ORIGEN.md` |
| Los widgets jQuery del tema | `hobo_bootstrap_ui/`, con `ORIGEN.md` |
| Contrato de `<page>` (30 params) | `hobo_bootstrap/taglibs/page.dryml` |
| **El runtime de tags** | `dryml/lib/rapid.rb` y `dryml/lib/rapid/` |
| **La prueba de contrato de params** | `dryml/lib/rapid/param_contract.rb` |
| Los dos tags grandes ya portados | `dryml/test/tags/{table_plus,form}.rb` |
| Cómo se eligió el sustrato de DRYML | `spike/dryml/README.md` |
| La app real de pruebas (2017) | `../amenti` — Ruby 1.9.3 vía rbenv, receta en `HALLAZGOS.md` |

### Los 22 repos de la organización Hobo

Del núcleo: `hobo` (este monorepo). Vendorizados: `hobo_bootstrap`,
`hobo_bootstrap_ui`.

**No vendorizados**, clonables desde `https://github.com/Hobo/<nombre>`:

| Repo | DRYML | Ruby | Qué es |
|---|---:|---:|---|
| `hobo_summary` | 282 | 24 | Tags de diagnóstico: modelos, columnas, asociaciones, gemas |
| `hobo_mapstraction` | 113 | 41 | Mapas (jQuery) |
| `select_one_or_new_dialog` | 82 | 26 | Variante en diálogo del de `hobo_bootstrap_ui` |
| `hobo_data_tables` | 47 | 24 | DataTables.net |
| `hobo_simple_color` | 43 | 28 | Selector de color |
| `hobo_tokeninput` | 41 | 24 | Entrada de etiquetas |
| `hobo_tree_table` | 33 | 24 | Tabla en árbol |
| `hobo_omniauth` | 22 | 195 | Login con terceros |
| `hobo_paperclip` | 2 | 46 | Adjuntos (Paperclip muerto → ActiveStorage) |

El resto son tutoriales, ejemplos, documentación y tres forks de `will_paginate`.

**Casi todos tienen exactamente 24 líneas de Ruby**: es el boilerplate del
contrato de plugin (pieza 17). Sirven de banco de pruebas de ese contrato —
cualquier decisión sobre DRYML o sobre assets **los rompe a los ocho a la vez**.

Con el contrato nuevo (decisión 22) esas 24 líneas se quedan en un engine con
dos initializers, y el trabajo de portar uno de estos ocho es **el DRYML**: sus
`taglibs/*.dryml` pasan a un fichero de tags en Ruby. `hobo_timeago/` es el
ejemplo terminado de a qué tiene que llegar cada uno.

---

## La capa 3, paso a paso — **terminada el 2026-08-07**

El registro de en qué orden se hizo y qué costó cada cosa. Para lo que viene
ahora, ver «Por dónde seguir» al final.

1. ~~Reescribir el runtime con la arquitectura correcta.~~ **HECHO el 2026-08-07.**
   `Rapid::Context` guarda **buffer, `this` y `scope` en una pila dinámica**
   (thread-local), y `param` llama a los bloques con `call`, no con
   `instance_exec`, para que conserven el `self` del tag que los escribió. Con
   eso el override de `:title_heading` **ya se aplica**: sale
   `<th class="shouty">TITLE!</th>` y la cabecera de al lado queda intacta.
   Verificado ejecutando `ruby spike/dryml/c_table_plus.rb`.
   Se añadió `Rapid.markup { }` para los bloques escritos fuera de un tag
   (una plantilla de página, o una prueba): son un tag anónimo sin params propios.
2. ~~Escribir la prueba de contrato.~~ **HECHA el 2026-08-07.** Ver «La prueba de
   contrato» más arriba. Descubrió de paso que `old` no emitía nada, y está
   arreglado.
3. ~~Sintaxis de params anidados.~~ **HECHA el 2026-08-07.** Ver «Los params
   anidados» más arriba. Trajo consigo el modelo de parámetro completo:
   contenido, atributos, `replace` y params anidados.
4. ~~Portar un segundo tag grande.~~ **HECHO el 2026-08-07:** `<form>`, base y
   generado, con su barrido. Ver «El segundo tag grande» más arriba. Destapó
   tres fallos, uno de ellos en la propia prueba de contrato.
5. ~~Pseudo-params.~~ **HECHOS el 2026-08-07**, los cinco. Ver «Los pseudo-params»
   más arriba.
6. ~~Sacar el runtime de `spike/` y convertirlo en la gema.~~ **HECHO el
   2026-08-07.** Ver «El runtime ya es la gema» más abajo.

**No empezar por portar tags en masa.** Primero el runtime correcto y la prueba
de contrato; si no, se repite el primer intento.

---

## Capa 4 — el arranque (2026-08-07)

**La gema `hobo` carga en Ruby 3.4 con Rails 8.1**, tiene banco de pruebas
minitest y las primeras 3 pruebas en verde. Es el gate de todo lo demás: hasta
ahora no arrancaba.

En el `Rakefile` de la raíz aparece un estado nuevo, **`PARTIAL_GEMS`**: la suite
corre y está verde, pero las suites viejas (`test/doctest` en rubydoctest,
`test/irt`) siguen sin portar y la capa no está terminada. Que salga verde no
quiere decir que esté hecha, y el corredor lo dice en voz alta.

### El hallazgo estructural: la gema se autocargaba a sí misma

`lib/hobo.rb` metía su propio `lib/` en
`ActiveSupport::Dependencies.autoload_paths`, y una referencia a `Hobo::Model`
cargaba `hobo/model.rb`. **Ese autocargador ya no existe**: en Rails 8
`autoload_paths` sobrevive solo como la lista que lee Zeitwerk, y
`load_missing_constant` no está.

Se sustituye por **`require` explícitos**, que es lo que una gema debe hacer de
todas formas —su `lib/` no es del autocargador de la aplicación— y que además
**deja a la vista el orden de carga**, que aquí importa porque media gema son
parches sobre ActiveRecord.

### Tres trozos de código muerto, dos de ellos muertos hace más de una década

| Qué | Desde cuándo | Qué se hizo |
|---|---|---|
| `extensions/active_record/associations/scope.rb` | El fichero **entero** está envuelto en `if false # DISABLED Getting Rails 3.1 working` | Fuera. La opción `:scope` de las asociaciones lleva **una década aceptándose y no haciendo nada** |
| El bloque `AssociationProxy.class_eval` de `extensions/active_record/permissions.rb` | `AssociationProxy` desapareció en **Rails 4.0** | Fuera |
| `require 'dryml'` en `lib/hobo.rb` | — | Ahora `require 'rapid'`. El compilador viejo pide `erubis`, muerta desde 2011 |

> ⚠ **Consecuencia anotada:** el bloque de `AssociationProxy` era lo que hacía
> que `project.tasks.create(...)` pasara por `user_save`. **Hasta que la pieza 4
> ponga el permiso en `before_create`/`before_update`, crear a través de una
> asociación no comprueba permisos.** El plan de la Deuda 2 ya dice que ese es el
> sitio correcto, y desde ahí cubre *todos* los caminos, no solo este.
>
> Y en `integration_tests/agility_bootstrap/app/models/project.rb:27` hay un
> `has_many :contributor_memberships, :scope => :contributor` que **no hace nada
> desde Rails 3.1**. Cuando el banco tenga que arrancar, en la capa 5-6, se
> escribe como Rails manda: `has_many :contributor_memberships, -> { contributor }`.

### Pieza 6 hecha: fuera los scopes automáticos

**429 líneas** (`model/scopes/automatic_scopes.rb`) más el `method_missing` y el
`respond_to?` de `model.rb` que los conjuraban. El veredicto ya estaba tomado
(se delega en Ransack); esto es ejecutarlo.

Los consumidores reales, localizados, son **dos, y los dos en controladores**:

| Dónde | Qué |
|---|---|
| `controller/model.rb:774` | `:query_scope => "#{attribute}_contains"`, el autocompletado |
| `projects_controller.rb:18` del banco | `:order_by => parse_sort_param(...)`, la ordenación de `<table-plus>` |

Los dos están en código que **esta misma capa** tiene que portar (pieza 11), y
hasta entonces **lanzan `NoMethodError` a la cara**, que es lo que queremos.

De paso: `respond_to?` estaba sobreescrito en vez de `respond_to_missing?`,
que es el gancho correcto desde Ruby 1.9.

### Cuatro API privadas de Rails 8 que ya no se dejan

| Sitio | Qué pasaba |
|---|---|
| `model/scopes.rb` y `accessible_associations.rb` | `Builder::Association.valid_options << :x`. En Rails 8 `valid_options` es **privado y recibe las opciones**. En `accessible_associations` se resuelve con `prepend` + `super`, que es adonde va el fichero entero cuando la pieza 4 lo reescriba |
| `Hobo::Model.all_models` | Escaneaba `#{Rails.root}/app/models/` sin guarda: fuera de una aplicación buscaba en `/app/models`. **La misma guarda que hubo que poner en el generador de migraciones en la capa 2** |
| `Hobo::Model.register_model` | Guardaba `model.name` sin comprobar: con una clase anónima registraba `nil`. **Otra vez el mismo fallo de la capa 2** |
| `test_helper` | `DescendantsTracker.clear` ahora recibe las clases |

## Pieza 4 hecha: los permisos (2026-08-07)

**15 pruebas minitest en verde**, en `hobo/test/hobo/permissions_test.rb`. De los
**35** `alias_method_chain` de la gema quedan **13**, y ninguno en esta pieza.

### Los ganchos: de API privada a callbacks

| Antes | Ahora |
|---|---|
| `alias_method_chain :_create_record` | `before_create :hobo_check_create_permission, prepend: true` |
| `alias_method_chain :_update_record` | `before_update` |
| `alias_method_chain :destroy` | `before_destroy` |

`_create_record` y `_update_record` son **privados** de ActiveRecord. Los
callbacks dicen lo mismo, son públicos, y **además cogen caminos que aquellos no
cogían**: crear a través de una asociación, por ejemplo, que antes se escapaba.

`prepend: true` para que la comprobación corra **antes** que nada más colgado del
mismo callback, incluido el borrado en cascada de Rails: no tiene sentido borrar
los hijos de un registro que no tienes permiso para borrar. Hay una prueba de eso.

De regalo, una diferencia real: el gancho viejo estaba en `_update_record`, que
**solo corre si hay algo que escribir**. `before_update` corre en el guardado
igualmente, así que **un update sin cambios también se comprueba**.

### Los envoltorios de `has_many` / `has_one` / `belongs_to`: muertos desde Rails 4.1

Los tres redefinían `<macro>_dependent_destroy_for_<nombre>`, un método que
ActiveRecord generaba para `:dependent => :destroy`. **Rails dejó de generarlo en
4.1**: desde entonces la cascada va por un `before_destroy` que llama a
`association.handle_dependency`.

O sea que llevaban **una década redefiniendo métodos que nadie llama, y los hijos
se borraban sin comprobar ningún permiso.**

Lo que los sustituye no toca las macros de asociación —que era el otro pecado
señalado en la Deuda 2, hacer que *toda* declaración de *todo* modelo pase por
Hobo— sino que el padre **le pasa su `acting_user` a los hijos** que va a borrar,
y cada hijo comprueba su propio permiso por el mismo `before_destroy` que todos.
Verificado con dos pruebas: el hijo que se niega **para el borrado entero**.

### `extensions/active_record/permissions.rb`, reescrito entero

Tres de sus métodos estaban podridos, y uno **no había funcionado nunca**:

| Método | Qué le pasaba |
|---|---|
| `nullify_keys` | Reimplementaba un método que ActiveRecord **ya no tiene**, sobre `quoted_id` (fuera en Rails 5.1) y el `update_all` de dos argumentos (fuera en Rails 4) |
| `delete_records` | Sustituía entera la versión de ActiveRecord, sobre `scoped`, que desapareció en Rails 4 |
| `_create_record` (en la asociación `through`) | La cadena llamaba al original `_create_record_without_user_create` y **el cuerpo pedía `create_record_without_user_create`**, sin el guion bajo. Lanzaba `NameError` la primera vez que se ejecutase |

Lo que queda son dos módulos con `prepend` que solo añaden el usuario y llaman a
`super`.

### El mismo truco roto, copiado en cuatro sitios

Cuatro macros de asociación llevaban el mismo apaño: *adivinar* si el segundo
argumento es un scope o un hash de opciones y, si parecía opciones, **pasarlo por
posición**. Desde Rails 5 la firma es `(name, scope = nil, **options)`, así que
Rails lo tomaba por el scope y le pedía `arity`. **Es el mismo fallo que la capa
2 encontró en `hobo_fields`.**

Estaban en `accessible_associations.rb` (×2) y en `model.rb` (×2). Los cuatro
fuera, con la firma correcta.

> **`prepend` y `alias_method_chain` no se llevan.** Al prepender el `belongs_to`
> de la capa 4 sobre el `alias_method_chain` que aún tenía `hobo_fields`, el
> alias capturó el método prependido y los dos se llamaron en círculo hasta
> desbordar la pila. **Es exactamente por lo que Rails lo abandonó en 5.1**, y
> estaba escrito en este plan sin que nadie lo hubiera visto pasar. Se arregla
> pasando también el de `hobo_fields` a `prepend`: dos `prepend` sí componen.
> Era trabajo aplazado de la capa 2, y ha resultado no ser opcional.

### Dos correcciones al plan

- **`metaclass.class_eval` en `unknownify_attribute` ya no existía**: la capa 1
  lo había pasado a `singleton_class.class_eval`. Un punto de la Deuda 2 que ya
  estaba resuelto.
- **`find_by_sql` estaba envuelto para no hacer nada**: recibía y devolvía. Fuera.
  Y `find(*args)` pasa a `find(...)`, porque desde Ruby 3 un splat convierte los
  argumentos con nombre de quien llama en un Hash posicional, y los buscadores de
  ActiveRecord llevan argumentos con nombre.

### Lo que sigue pendiente de la pieza 4

**Los permisos de lectura por campo**, que es lo único genuinamente difícil,
siguen como estaban: `unknownify_attribute` y `deunknownify_attribute` hacen su
apaño con métodos singleton porque **Rails no tiene gancho de lectura**. No es
deuda nueva; es la que ya estaba anotada. Funciona, y se decide qué hacer con
ello cuando la capa 5 enseñe cuánto se usa de verdad.

## Piezas 5 y 7 hechas: lifecycles y view hints (2026-08-07)

**44 pruebas minitest en verde** en `hobo` (15 de permisos, 16 de view hints,
13 de lifecycles). Las dos piezas se quedan tal cual decía el veredicto; el
trabajo ha sido **hacerlas funcionar en Rails 8 y dejarlas escritas**.

### Pieza 7, view hints: un fallo que las inutilizaba a medias

`paginate?` y `sortable?` guardaban su valor con `@x ||= …`, que **no distingue
«nadie lo ha dicho» de «alguien ha dicho `false`»**. Así que
`view_hints.paginate? false` se quedaba puesto hasta que alguien preguntaba, y
entonces el valor por defecto lo pisaba: **la paginación no se podía apagar.**
Comprobado con una prueba antes de arreglarlo.

Lo demás está sano y ahora está descrito: la clase de hints se fabrica bajo
demanda, `children` se resuelve **en la lectura y no en la declaración** —para no
forzar la carga del modelo hijo mientras el padre se está cargando—, declarar los
hijos le enseña al hijo quién es su padre sin pisar el que ya tuviera, y
`inline_booleans true` significa «todas las columnas booleanas».

Los cuatro métodos de traducción siguen lanzando `NotImplementedError` con la
clave de i18n que hay que usar en su lugar, que es la forma correcta de retirar
algo.

### Pieza 5, lifecycles: `attr_protected` y un lector que no existía

Lo que rompía era **`attr_protected`**, que Rails se llevó a la gema
`protected_attributes` en Rails 4 y que está sin mantener desde 2016. Lo usan el
campo de estado del lifecycle, su `key_timestamp` y los campos de autenticación.

`attribute_protected?` de los permisos colgaba de eso mismo, más de
`accessible_attributes` y `attributes_protected_by_default`.

**La respuesta de Rails son los parámetros fuertes, y no sirve aquí**: la
pregunta no la hace el controlador sobre unos parámetros, la hace **el
constructor de formularios sobre un campo**, antes de que exista ningún
parámetro. Así que Hobo se queda con su propia lista —`Hobo::Model.attr_protected`
y `protected_attributes`, heredable— que es la parte pequeña de aquella gema que
de verdad usaba.

Y `Model.lifecycle` **sin bloque** no era un lector: caía en
`dsl.instance_eval(&nil)` y moría con un `ArgumentError` sobre `instance_eval`
que no le decía nada a nadie. Ahora devuelve la clase `Lifecycle`, que es lo que
cualquiera espera al escribirlo.

Los ficheros de `lifecycles/` tampoco se requerían entre sí: otra víctima del
autocargador clásico.

## Pieza 11, primera mitad: la capa de controlador arranca (2026-08-07)

**52 pruebas en verde.** `hobo/controller/model.rb` **carga en Rails 8**, y los
dos consumidores de los scopes automáticos que la pieza 6 dejó lanzando
`NoMethodError` ya tienen sustituto.

### Ransack, donde estaba `<attr>_contains`

`hobo_completions` —el autocompletado— hacía
`finder.send("#{attribute}_contains", query)`. Ahora es
`finder.ransack("#{attrs}_cont" => query).result`, y la lista de scopes que
admitía la opción pasa a ser una **lista de atributos**: Ransack los junta con
`a_or_b_cont`, que es su forma de decir lo mismo.

**Ransack 4 se niega a buscar en un modelo que no ha dicho qué se puede buscar**,
y con razón. Hobo ya lo sabe, así que contesta él: `ransackable_attributes` son
sus columnas **menos las que nunca enseña** (`never_show`), y
`ransackable_associations` es una lista vacía, porque una búsqueda que se mete en
otra tabla es una decisión y no un valor por defecto.

### `:order_by` no ordenaba nada

El otro consumidor. Las páginas pasan `:order_by => parse_sort_param(...)` a
`hobo_index`, y esa opción **se quedaba en el hash y se le entregaba a
will_paginate, que no la conoce**. Quien ordenaba de verdad era el scope
automático `order_by`, por otro camino. Ahora `find_or_paginate` la aplica con el
`order` de la propia relación.

De paso, `find_or_paginate` dejaba caer el hash entero de opciones dentro de
`paginate`; ahora le pasa solo `:page` y `:per_page`, que es lo que entiende.

### Tres cosas más que Rails se llevó

| Qué | Desde | Ahora |
|---|---|---|
| `Mime::CSV` y compañía | Rails 5 | Símbolos, `request.format.symbol` |
| `before_filter` | Rails 5.1 | `before_action`, en 5 ficheros |
| `respond_to :html` / `respond_with` de clase | Rails 5 los sacó del núcleo | La gema `responders`, ahora declarada |

Y las dos cadenas `alias_method_chain` de los controladores —`render` y
`redirect_to`— pasan a módulos con `prepend`, que **componen con el resto de la
cadena de Rails** en vez de renombrarla.

> **Corrección sobre `Arel.sql`:** al escribirlo di por hecho que Rails 8 seguía
> rechazando una expresión sin marcar en `order`. **No lo hace**: Rails 6 y 7 lo
> exigían y Rails 8 vuelve a permitirlo. La marca se queda igualmente, y el
> motivo escrito es el correcto: `parse_sort_param` es **el único sitio que tiene
> la lista blanca**, así que es donde toca decir que la cadena es deliberada, en
> vez de depender de hacia dónde se incline Rails cada año.

## Cómo se prueban los controladores: los dos niveles (2026-08-07)

Decidido por Imanol: **las dos cosas**. Pruebas que no necesitan aplicación
siempre que se pueda, **y** una aplicación Rails de verdad en `tmp` para
verificar lo que solo se ve arrancando.

### Nivel 1 — sin aplicación

`hobo/test/hobo/controller_test.rb`, **15 pruebas**. Un controlador se define,
declara sus `auto_actions` y contesta a `parse_sort_param` y `find_or_paginate`
sin que exista ninguna aplicación.

**Hasta hoy eso era imposible**, y por un motivo concreto:
`app/helpers/hobo_route_helper.rb` hacía `include
Rails.application.routes.url_helpers` **en la primera línea del módulo**, así que
el fichero no se podía ni cargar sin una aplicación arrancada. No hacía falta: el
módulo se mezcla en controladores, y un controlador ya tiene los helpers de rutas
de su aplicación.

Ahí apareció además que **`hide_action` desapareció en Rails 5**, y sí importaba:
todo lo público que un controlador recibe es una acción enrutable, así que sin
sustituto **`object_url` y compañía quedaban accesibles por HTTP**. Se recoge la
lista de nombres al mezclar cada helper y se resta en `action_methods`. Hay
prueba, y de la herencia también.

### Nivel 2 — con una aplicación de verdad

```sh
cd hobo && rake test:app     # la monta en /tmp/hobo_testapp
cd hobo && rake test         # las de integracion dejan de saltar
```

Es una aplicación **Rails 8 pelada** con las cuatro gemas apuntando al árbol de
trabajo. `hobo new` es de la capa 7, y esto tiene que funcionar antes que aquello.

**Cuando no está montada, las pruebas saltan diciendo cómo montarla.** Nunca
pasan en silencio: es la misma regla que puso la capa 2 con los adaptadores de
base de datos.

Va fuera del árbol de la gema a propósito: una aplicación anidada dentro del
directorio del engine **hace que Zeitwerk se niegue a arrancar**, porque el mismo
árbol queda reclamado dos veces.

### Y encontró cinco cosas que ninguna prueba unitaria podía ver

| Qué | Dónde |
|---|---|
| **`gem "dryml"` no cargaba en ninguna aplicación.** `Bundler.require` carga el punto de entrada de cada gema, y el de `dryml` seguía siendo el compilador viejo, que pide `erubis` | Ahora `lib/dryml.rb` carga el runtime de la capa 3; el compilador se muda a `lib/dryml/legacy.rb` y **solo se carga a propósito** |
| **`hobo_fields` impedía arrancar cualquier aplicación.** Metía su `lib/` en `autoload_paths`, que en Rails 8 es la lista que lee **Zeitwerk**: registraba el árbol dos veces y Zeitwerk se plantaba. **La capa 2 dio esta gema por terminada y solo una aplicación real podía verlo** | Fuera, con `require` explícitos, como se hizo en `hobo` |
| La extensión de **ActionMailer** colgaba del gancho `on_load(:action_controller)`, y su primera línea es `ActionMailer::Base.send :include` | A `on_load(:action_mailer)` |
| **`File.exists?`** ya no existe en Ruby 3.4 | `File.exist?`, en 2 ficheros |
| Un gema **debe requerir lo que usa**: Bundler solo requiere lo que la aplicación lista, no las dependencias de sus gemas | `responders` y `ransack`, ahora requeridas por Hobo |

Y tres sitios más donde faltaban `require` por el autocargador clásico:
`hobo/controller.rb`, los cuatro helpers de `app/helpers`, y el generador de rutas.

Los dos inicializadores que llaman al compilador viejo de DRYML quedan **guardados
con `defined?`**: una aplicación arranca sin generar taglibs, en vez de no
arrancar. Vuelven en las capas 5 a 7 sobre el runtime nuevo.

### El índice contesta 200 — y el 403 escondía un `NameError`

**`GET /stories` devuelve 200 con el registro pintado en la vista.** Routing,
`auto_actions`, permisos, buscador y render, de punta a punta, fijado en la
prueba de integración.

El 403 de antes **no era una denegación**: era un `NameError` disfrazado.
`current_user`, en `hobo_permissions_helper.rb`, terminaba en `::Guest.new` —una
constante pelada que **solo el autocargador clásico sabía resolver**— y en una
aplicación sin modelo `Guest` eso reventaba **en todas las peticiones, antes de
que ninguna acción llegara a correr**. La página de error salía con 403 y no
había forma de saberlo desde fuera.

Ahora hay `Hobo::Model::Guest` de respaldo: la aplicación que tenga su propio
`Guest` lo sigue usando —querrá uno con nombre, o con idioma— y la que no, se
queda con el de Hobo, que dice que no a todo. Con prueba.

> **Lo que la vista enseñó:** la plantilla lee `@stories`, no `this`. Ese es el
> contrato del lado del controlador —`this=` pone la variable de instancia con el
> nombre del modelo— y `this` solo llega a una plantilla **por el runtime de
> tags**, que es de las capas 5 y 6. Anotado para no buscarlo donde no está.

### Escribir también funciona, y con eso la pieza 11 está

**`create`, `update` y `destroy` van de punta a punta** contra la aplicación de
pruebas: 302 a `/stories/1-nueva` —el id amistoso de Hobo, funcionando—, el
registro cambiado, el registro borrado. Y el mismo `create` contra un modelo que
dice que no da **403 sin escribir nada**: la reescritura de la pieza 4, vista
desde fuera.

Para llegar ahí hubo que resolver cuatro cosas más:

| Qué | Detalle |
|---|---|
| **Parámetros fuertes** | Rails rechaza desde la 4 que le pases los params en crudo. Hobo pregunta otra cosa: `update_permitted?` mira **lo que ha cambiado** (`only_changed?`, `none_changed?`, `any_changed?`) y `attr_protected` nombra lo que nadie puede asignar nunca. Así que la lista se construye con lo que Hobo ya sabe —todo menos los campos protegidos— y **decide el modelo** |
| **El respaldo del 403 era inalcanzable** | `if render :permission_denied … else …` — `render` **lanza** cuando falta la plantilla, no devuelve falso. Una aplicación sin esa plantilla recibía **500 donde debía recibir 403** |
| `Fixnum` | Desapareció en Ruby 3.2 |
| `render :text` y `render :nothing` | Se fueron en Rails 5 → `render :plain` y `head` |
| `translate key, options` | Rails lo quiere con argumentos con nombre; desde Ruby 3 un hash posicional **es otra cosa**, y llegaba como segundo argumento |

Y las **4 `alias_method_chain`** que quedaban de la pieza pasan a `prepend`:
`user_base.rb` (3), `find_for.rb` y `relation_with_origin.rb` (2).

**Quedan 5 en toda la gema**, de las 35 del principio, y las cinco son de la
pieza 12: `active_model/{name,translation}.rb`, `associations/reflection.rb`,
`extensions/{enumerable,i18n}.rb`.

## Pieza 12 hecha: el router, sin fichero generado (2026-08-07)

**`config/hobo_routes.rb` ya no existe.** Las rutas son un método que la
aplicación llama desde su propio `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  hobo_routes
  root :to => "front#index"
end
```

El fichero generado tenía tres problemas a la vez, y los tres se van con él:

1. **se escribía durante el arranque**, así que arrancar necesitaba disco de
   escritura, y un despliegue de solo lectura tenía una bandera propia
   (`read_only_file_system`) para esquivarlo;
2. **acababa en el repositorio** con pinta de fichero que se edita, y una nota
   arriba diciendo que no;
3. sus rutas se cargaban **en un sitio fijo**, así que una aplicación no podía
   decidir qué iba antes y qué después.

Lo que decide **qué** rutas hay no ha cambiado: sigue siendo el `Router`, que lee
de cada controlador sus `auto_actions`, sus asociaciones de propietario, sus
lifecycles y sus métodos web. Lo que cambia es que su salida se evalúa
directamente en el *mapper* en vez de dar un rodeo por el disco.

**El agravante de Zeitwerk, resuelto y probado.** El router encuentra los
controladores **que viven en ficheros**, sin que nadie los nombre: recorre
`app/controllers` y deja que el autocargador haga el resto. La prueba escribe un
modelo y un controlador de verdad en la aplicación y comprueba que salen **8
rutas**. Es lo que `descendants` no podía dar.

> **Y un 403 que no era de Hobo.** Una petición montada con `Rack::MockRequest`
> no lleva un `Host` que Rails reconozca, y `ActionDispatch::HostAuthorization`
> la corta con **403 desde el middleware** — idéntico por fuera a un permiso
> denegado. Ya van dos 403 distintos en esta capa que no eran lo que parecían;
> el montaje de la aplicación de pruebas ahora hace `config.hosts.clear` y lo
> deja dicho por escrito.

### Cero `alias_method_chain`

**Eran 35 al empezar la capa y no queda ninguna** en `hobo`, ni en
`hobo_support`, ni en `hobo_fields`. Las últimas cinco eran extensiones
(`ActiveModel::Name#human`, `ActiveModel::Translation#human_attribute_name`,
`AssociationReflection#klass`, `Enumerable#group_by`, `I18n.translate`), y las
dos de `hobo_fields` —`attr_accessor` con tipos ricos y `acts_as_list`— venían
aplazadas de la capa 2.

Esa última pareja importaba: **`attr_accessor` era el mismo choque latente que ya
explotó con `belongs_to`.** La capa 4 prepende su propio `attr_accessor`, y una
cadena de alias debajo de un `prepend` se llaman en círculo hasta desbordar la
pila. Estaba esperando a que alguien escribiera `attr_accessor :x, :type => …`.

Las que quedan en el repositorio son las del **compilador viejo de DRYML**
(`dryml/lib/dryml/legacy.rb` y compañía), que se conserva a propósito.

## Pieza 14 hecha: subsites (2026-08-07) — **y con ella la capa 4**

Un directorio dentro de `app/controllers` es un sitio entero más sobre los
mismos modelos, y atraviesa **cuatro subsistemas a la vez**: qué controladores
existen, qué rutas les tocan, qué controlador le corresponde a un modelo en cada
sitio, y qué URL tiene un registro en cada sitio. Los cuatro pasan, con un
`admin` de verdad escrito en ficheros.

### Dos fallos, y los dos silenciosos

**1. `concerns` era un subsite.** `Hobo.subsites` daba por subsite *cualquier*
directorio dentro de `app/controllers`, y Rails crea `app/controllers/concerns`
en **todas** las aplicaciones. O sea que toda aplicación Hobo tenía un subsite
fantasma y el router escribía obedientemente `namespace :concerns`. Ahora un
subsite es un directorio **que contiene algún `*_controller.rb`**, y `concerns`
está excluido por nombre.

De paso, el resultado estaba memorizado para toda la vida del proceso, así que un
subsite añadido con el servidor en marcha no se veía nunca.

**2. Los enlaces a un subsite salían vacíos.** `object_url` construye la ruta con
`polymorphic_path([subsite, objeto])`, y Rails **exige un símbolo** para el
espacio de nombres: con una cadena lanza `ArgumentError`. Ese error caía en el
`rescue` de `object_url`, que **devuelve `nil`**. Resultado: **todos los enlaces
a un subsite, muertos, sin una sola queja.**

Es el mismo patrón que lleva apareciendo toda la capa: un `rescue` amplio
convierte un fallo concreto en un resultado plausible.

### Y `subsite` se lo pregunta ahora a la clase

Se deducía de `params[:controller]`, así que fuera de una petición no había nada
que mirar. `Admin::StoriesController` **ya sabe** en qué subsite está, y lo sabe
también desde un correo, un job o la consola.

---

# La capa 4, terminada (2026-08-07)

| Pieza | Qué se hizo |
|---|---|
| **4** Permisos | Ganchos privados de AR → `before_create`/`before_update`/`before_destroy`. Los envoltorios de asociación, muertos desde Rails 4.1, fuera |
| **5** Lifecycles | `attr_protected` reimplementado, que es la parte de la gema muerta que Hobo usaba de verdad |
| **6** Scopes automáticos | 429 líneas fuera, delegado en Ransack |
| **7** View hints | Un fallo que impedía apagar la paginación |
| **11** Auto-actions | Lectura y escritura de punta a punta, con Ransack y parámetros fuertes |
| **12** Router | Sin `config/hobo_routes.rb`: `hobo_routes` en el `routes.rb` de la aplicación |
| **14** Subsites | Los cuatro subsistemas, con `admin` de verdad |

**77 pruebas en `hobo`**, 222 en el repositorio. **Cero `alias_method_chain`**, de
35. Una aplicación Rails 8 arranca con las cuatro gemas, sirve un índice, crea,
modifica y borra con permisos, y tiene subsites.

**Lo que la capa 4 no trae, y es lo siguiente:** la vista. Hoy la aplicación de
pruebas usa ERB y lee `@stories`; `this` solo llega a una plantilla por el
runtime de tags. Eso es la capa 5.

Quedan **5 `alias_method_chain`** —eran 35 al empezar la capa—, todas de la
pieza 12:

| Fichero | Cuántos | Pieza |
|---|---:|---|
| `controller/user_base.rb` | 3 | 11 |
| `extensions/active_record/relation_with_origin.rb` | 2 | 11 |
| `extensions/active_model/{name,translation}.rb` | 2 | 12 |
| `extensions/{enumerable,i18n}.rb` | 2 | 12 |
| `extensions/active_record/associations/reflection.rb` | 1 | 11 |
| `model/find_for.rb` | 1 | 11 |

## Lo que ya se sabía antes de empezar la capa 4

Se conserva porque sigue valiendo, y porque el arranque ya confirmó dos de estos
puntos: la carga ansiosa y el fichero aplazado de la capa 1.

- **La Deuda 2 (permisos)** es casi toda autoinfligida: los `alias_method_chain`
  y las macros de asociación reescritas se sustituyen por ganchos públicos. Lo
  único genuinamente difícil son los permisos de **lectura por campo**, porque
  Rails no tiene gancho de lectura.
- **`accessible_associations.rb` viene aplazado de la capa 1**, con sus 5
  `alias_method_chain`, y hay que reescribirlo entero.
- **El router necesita carga ansiosa** por `descendants` con Zeitwerk, el mismo
  agravante que el generador de migraciones de la capa 2.
- **`common_tasks.rb` muere aquí**, al portar las pruebas de `hobo`.

Y la capa 3 deja dos cosas usables desde ella: `require "rapid/param_contract"`
para cualquier tag que se escriba, y `dryml/test/tags/` como ejemplo de cómo se
porta un tag grande.

### Cómo correr lo de esta capa

```sh
cd hobo && rake test
ruby -Ilib -I../hobo_support/lib -I../hobo_fields/lib -I../dryml/lib \
     -e 'require "active_record"; require "hobo"'   # el gate de carga
```

## Capa 5 — el inventario (2026-08-07)

### El catálogo: 146 tags, 96 ficheros, ~3.900 líneas

Por directorio: `inputs` 30, `html` 24, `views` 22, `pages` 15, `lists` 14,
`editors` 11, `plus` 8, `buttons` 7, `forms` 4, `i18n` 3, `cards` 2.
**34 son polimórficos** (`for="string"`, `for="datetime"`, `for="EnumString"`…):
ese es el catálogo de vistas por tipo, y es el corazón de la pieza 9.

### Lo que no se porta, y por qué

| Qué | Motivo |
|---|---|
| **10 tags de elementos vacíos** (`<br>`, `<hr>`, `<img>`, `<meta>`, `<link>`, `<base>`, `<area>`, `<col>`, `<param>`, `<frame>`) | Existían porque **el parser de DRYML** necesitaba saber qué elementos no llevan cierre. El runtime de la capa 3 ya lo sabe: se añadió al portar `<form>` |
| **`<if-ie>`** | Los comentarios condicionales los quitó **IE10 en 2012**, e IE está fuera de soporte desde 2022 |
| **`<doctype>` con seis doctypes** | HTML 4.01 Strict/Transitional/Frameset y las variantes XHTML. Hoy solo existe `<!DOCTYPE html>` |
| **`<header>`, `<footer>`, `<aside>`, `<section>`** | Pintan `<div class="header">` porque se escribieron **antes de HTML5**. Ahora esos elementos existen. Se conserva solo el «no pintes nada si el cuerpo está vacío», que sí es útil |
| **Los tres tags de caché** (644 líneas, 17% del catálogo) | **Decidido el 2026-08-07: fuera.** No los usaba nadie —ni el tema, ni la app de integración, ni el resto de RAPID—. Eran invalidación por dependencias de contexto, de antes de que Rails tuviera claves de caché decentes (Rails 4, 2013). Quien necesite caché usa la de Rails; recuperarlos del git es un `git show` |

### El contrato con el navegador, mapeado

El servidor emite un atributo `data-rapid` con **JSON**: `{"form": {…opciones…},
"before-unload": {…}}`, o sea **nombre de comportamiento → opciones**. El JS
(`hjq.js`) busca `[data-rapid]`, y por cada clave llama al plugin de jQuery
`hjq_<nombre>` sobre ese elemento. Hay además `data-rapid-page-data` (datos
globales de la página) y `data-rapid-context` (el id tipado del registro).

**Hay 27 comportamientos** repartidos entre `hobo_jquery` (15), `hobo_jquery_ui`
(9) y `hobo_bootstrap_ui` (3).

**Eso se traduce a Stimulus casi uno a uno:** `data-rapid='{"form": {…}}'` pasa a
`data-controller="rapid-form"` con sus `data-rapid-form-*-value`. Y hay una
ganancia real que no es cosmética: **`hjq.init()` hay que llamarlo a mano después
de cada actualización ajax**, y buena parte de `hjq.js` existe para eso. Stimulus
conecta y desconecta solo cuando cambia el DOM, así que ese trabajo desaparece.

### El protocolo de partes, fuera (2026-08-07)

Del lado del servidor **ya no queda nada**: `hobo_ajax_response` y
`ajax_update_response` borrados, y con ellos las ramas
`if request.xhr? && params[:render]` de `show_response`, `index_response`,
`create_response` y `update_response`, y las respuestas `wants.js` de
`user_base.rb`. **Las 77 pruebas siguen en verde**, incluidas las de petición
real: crear, modificar y borrar no dependían de esto.

Un ajax ya no toma un camino distinto: **se pinta la página como siempre y Turbo
saca de ella el frame que pidió.**

`dryml/lib/dryml/part_context.rb` **se queda donde está**: es del compilador
viejo, que se conserva a propósito como front-end del actualizador de plantillas
(decisión 6). Lo que se ha ido es que Hobo dependa de él.

### Las 27 conductas, contadas

De las 1.045 líneas de jQuery, **Turbo se lleva unas 565 sin escribir nada**:

| Se va con Turbo | Líneas | Por qué |
|---|---:|---|
| `hjq.js` | 397 | Es la maquinaria de peticiones y partes del protocolo que acaba de irse |
| `hjq-form`, `hjq-formlet`, `hjq-a` | 146 | Enviar un formulario o seguir un enlace por ajax: `data-turbo-frame` |
| `hjq-live-search`, `hjq-search-results` | 22 | Un formulario que se envía solo dentro de un frame |

**Lo que sí es un widget y hay que reescribir** (~326 líneas): `input-many`,
`select-many`, `spinner`, `delete-button`, `hot-input`, `before-unload` y
`filter-menu`. Los de `hobo_jquery_ui` (acordeón, calendario, diálogo, pestañas,
autocompletar) y los de `hobo_bootstrap_ui` van con el tema, en la capa 6 — y
alguno se cae solo: el calendario es `<input type="date">` desde 2014.

### El banco de navegador (2026-08-07)

Un controlador de Stimulus **es** comportamiento en un navegador, así que se
prueba en uno. En la máquina hay Firefox y `geckodriver`, y el banco los usa:

```sh
cd hobo && rake test:app      # trae capybara, selenium y el runtime de Stimulus
cd hobo_rapid && rake test
```

Sirve una página pequeña con el controlador puesto, **la carga con un import map
igual que lo hace una aplicación Rails** —importando `@hotwired/stimulus` por su
nombre pelado—, la conduce con Firefox sin ventana y mira qué le pasó al DOM. Sin
navegador, salta diciendo cómo montarlo.

### `<input-many>` portado: la primera conducta

Era **185 líneas de jQuery** y es la más característica de Hobo: una lista de
filas de formulario que el usuario hace crecer y encoger. **8 pruebas en
navegador, en verde**, sobre lo que de verdad importa:

- la fila plantilla va con los inputs deshabilitados, para que nunca se envíe;
- añadir clona la plantilla y **habilita** sus inputs;
- **las filas se renumeran desde cero y sin huecos** tras añadir o quitar —que es
  el motivo de todo el invento, porque Rails lee el índice del nombre—;
- los `id` y los `for` de las etiquetas se renumeran con ellos;
- solo la última fila ofrece «añadir»;
- la fila vacía aparece solo mientras no hay ninguna;
- con un mínimo, «quitar» desaparece.

**Y algo que se cae solo:** ya no hace falta llamar a ninguna función de
inicialización cuando cambia el DOM. Stimulus conecta y desconecta por su cuenta,
y eso era buena parte de lo que hacía `hjq.js`.

### Las seis conductas que quedaban (2026-08-07)

**18 pruebas en navegador, en verde.** El JS propio pasa de **1.045 líneas a
~250**, y tres de las siete conductas se van sin sustituto:

| Conducta | Qué le pasa |
|---|---|
| `spinner` (83) | **Fuera, sin sustituto.** No la usa ningún taglib, se llamaba desde la maquinaria de ajax que ya no existe, y Turbo trae barra de progreso y marca los frames mientras cargan |
| `hot-input` (15) + `filter-menu` (6) | **Eran la misma idea escrita dos veces**: enviar el formulario cuando algo cambia. Son un solo controlador, `rapid-autosubmit`, y ya no hacen la petición: el formulario va a Turbo. Con retardo opcional, para no enviar una petición por tecla |
| `before-unload` (15) | Portado. **Se le cae la opción `message`**: los navegadores ignoran el mensaje propio desde 2016, porque se usaba para atrapar a la gente |
| `select-many` (62) | Portado. La versión de jQuery **convertía la opción elegida en un `<optgroup>`** para esconderla, y la volvía a convertir al quitarla; ahora se deshabilita y se oculta, que es para lo que están esos atributos, y nada de lo que lea el `select` ve una lista distinta |
| `delete-button` (43) | **Pendiente, y probablemente no se porta**: quitar el registro del DOM tras borrarlo es un `<turbo-stream action="remove">` que manda el servidor. Se decide al portar el tag |

### Pieza 9 empezada: `<view>`, y lo que le faltaba al runtime (2026-08-07)

`<view:body/>` no dice **cómo** pintar el cuerpo: dice «pinta este campo», y
**el tipo decide**. Un `:markdown` sale como html, un `:date` con formato de
fecha, un booleano como una marca. Es el catálogo de vistas por tipo, y para
portarlo hicieron falta dos cosas del runtime.

**1. El contexto no es un valor, es un valor y de dónde viene.** DRYML guardaba
`this`, `this_parent` y `this_field` **juntos**, y los restauraba juntos. Sin el
padre y el campo, un tag **no puede saber el tipo declarado de un `nil`**, ni
preguntar si el campo se puede ver, ni nombrar la clase css de lo que pinta. El
runtime tenía solo `this`; ahora tiene los tres, y `with_field(:body)` los mueve
a la vez.

Con eso, el despacho polimórfico va sobre **el tipo declarado**, no sobre
`this.class`: un campo en blanco sigue pintándose como lo que es, y la página no
da saltos cuando aparece un valor. Y hay `Rapid::Boolean`, porque en Ruby no
existe una clase Boolean y una vista tiene que poder despachar sobre ella.

**2. Un tag polimórfico no puede llevar conducta compartida.** Este lo aprendí
equivocándome: `define_for` **sustituye el tag entero**, así que las vistas por
tipo se saltaban el permiso, el envoltorio y el tratamiento del blanco. Son
**dos tags**: `<view>` guarda todo eso y delega el pintado en `<view-content>`,
que es el polimórfico. **DRYML tenía la misma pareja**, y ahora sé por qué.

**11 pruebas**, sobre lo que importa: cada tipo se pinta a su manera y **dentro**
de su envoltorio, la clase css lleva el modelo y el campo, un campo en blanco
pinta su envoltorio igual, `if_blank` pone algo en su lugar, y un campo que no se
puede ver **se niega** salvo `force`.

### Los tipos ricos ya sabían pintarse solos

No hace falta una vista por tipo rico. Un `Markdown`, un `Textile`, un
`EnumString` o un `LifecycleState` **saben pintarse**: llevan `to_html` desde la
capa 2. El catálogo no carga con ellos; **el tipo lo lleva puesto**, y eso es lo
que significa «tipos ricos que viajan a la vista». El defecto de
`<view-content>` es «si sabe darme html, se lo pido; si no, `to_s`».

### El barrido de contrato, apuntado al catálogo

`require "rapid/param_contract"` y una línea por tag. **Y encontró algo a la
primera:** en `<collection-view>`, la vista de cada miembro se llamaba **sin
exponerla**, así que un tema no tenía forma de decir cómo se pinta un miembro de
una colección. Ahora hay cuatro puntos de extensión, y el barrido los recorre:

```
collection        element
item              element
member            call
member > default  bare
```

> **Y de paso, un fallo en el entregable de la capa 3:**
> `rapid/param_contract.rb` **no requería `rapid`**. Es el fichero que las gemas
> de arriba tienen que poder requerir solas —es la razón de que viva en `lib/`—
> y solo funcionaba si alguien había cargado el runtime antes. Es exactamente la
> lección de la capa 4: una gema requiere lo que usa. Solo se vio al usarlo
> desde otra gema, que es la primera vez que ha pasado.

### La otra mitad: `<input>`, y lo que HTML5 se lleva (2026-08-07)

`<input:title/>` no dice qué control pintar: **el tipo lo dice**. Es donde
`fields do` paga: `contact_address :email_address` da un `<input type="email">`
sin que nadie lo escriba.

Misma forma que `<view>`, y por el mismo motivo: `<input>` guarda el permiso, el
nombre del campo y el envoltorio, y `<input-content>` es el polimórfico.

**Lo que se lleva HTML5:**

| Antes | Ahora |
|---|---|
| `input_for_date.dryml`, **81 líneas** de selects día/mes/año construidos con `date_select` de Rails | `<input type="date">`, que el navegador tiene desde 2014 y que sabe de idiomas, teclados y calendarios más que nosotros |
| hora y fecha-hora, con `order`, `date-separator`, `discard-type`, `prompt`, `prefix` | `type="time"` y `type="datetime-local"` |
| enteros y decimales como campos de texto | `type="number"`, con `step` según el tipo |

**Lo que no se lleva, y hay que conservar:** el truco de la casilla. Un
`<input type="checkbox">` sin marcar **no envía nada**, así que el modelo nunca
se entera de que lo desmarcaste. Va acompañado de un campo oculto con `0`, que es
lo que Rails hace desde siempre. Hay prueba.

Y los cuatro modos de `no_edit`, que son una decisión de producto y no técnica:
sin permiso, por defecto **se enseña el valor en lugar del control** —un
formulario que esconde lo que no puedes cambiar te dice menos que uno que te lo
enseña apagado—, y se puede pedir `:disable`, `:skip` o `:ignore`.

**16 pruebas**, más el barrido de contrato.

## Pieza 10: el motor de derivación (2026-08-07) — **se ve una página**

Declaras un modelo con `fields do` y **las páginas existen**: una tarjeta que
resume un registro, un índice que los lista, una página que enseña uno, un
formulario que lo edita. Nadie escribe esas vistas.

### Lo que el sustrato de Ruby se ahorra: la generación de código

El motor viejo **generaba fuente DRYML** en
`app/views/taglibs/auto/rapid/*.dryml` desde **534 líneas de ERB**, en el
arranque y en cada recarga. Era la única forma de hacerlo cuando los tags eran un
lenguaje de plantillas.

Con los tags como objetos de Ruby **no hay nada que generar**: los tags se
definen ejecutando Ruby. Ni ficheros escritos, ni nada que meter en `.gitignore`,
ni generación en el arranque — y **un error sale como un error de Ruby con su
traza**, en vez de como un fallo de sintaxis en un fichero que nadie escribió.

### Lo que lee del modelo

Nada nuevo: lo que el modelo ya dijo. Los campos y sus tipos (`fields do`), cuál
es su nombre (`name_attribute`), cuáles son sus hijos (`children :tasks`), y qué
se puede ver y editar (los permisos de la pieza 4).

```
<article class="show-page story">
  <h1><span class="view story-title">La luz de Hobo</span></h1>
  <dl>
    <dt>Body</dt>         <dd><span class="view story-body">Se ve algo</span></dd>
    <dt>Published on</dt> <dd><span class="view story-published-on">2026-08-07</span></dd>
    <dt>Featured</dt>     <dd><span class="view story-featured">&#10004;</span></dd>
  </dl>
  <section class="children tasks">
    <h2>Tasks</h2> ...
```

y el formulario, sin que nadie diga qué control lleva cada campo:

```
<input type="text" value="La luz de Hobo" name="story[title]">
<textarea name="story[body]">Se ve algo</textarea>
<input type="date" value="2026-08-07" name="story[published_on]">
```

**Probado contra la aplicación de verdad**, no solo con dobles: `hobo_fields`
declara los tipos, `hobo` aplica los permisos, el runtime de la capa 3 pinta, y
el motor decide qué pintar. Si algo de esa cadena se rompe, esa prueba se entera.

### Tres fallos más, y uno se repite por tercera vez

| Qué | Dónde |
|---|---|
| **`autoload_paths` otra vez** | `hobo_rapid` tenía la misma línea que `hobo` y `hobo_fields`. **Tercera gema, tercera vez que impide arrancar cualquier aplicación**, y las tres veces solo se ve con una app de verdad |
| **`member_class` devolvía nil** | `relation_with_origin.rb` leía `@klass` a pelo, y en Rails 8 ese ivar ya no está. Un tag polimórfico al que le pides pintar una colección de historias **caía al genérico sin decir nada** |
| Atributos booleanos de HTML | Salía `selected="true"` donde va `selected`. No es cosmético: un navegador lee `checked="false"` **como marcado** |

Y el barrido de contrato volvió a ganarse el sueldo: exigió que las vistas de
cada campo y la colección de cada hijo fueran **puntos de extensión**, que es lo
que permitirá que un tema entre en una página derivada sin reescribirla.

### Y la luz: una petición devuelve la página derivada

```
GET /stories  ->  200
<div class="index-page stories">
  <h1>Stories</h1>
  <div class="collection">
    <div class="card story">
      <h3><span class="view story-title">La luz de Hobo</span></h3>
      <dl><dt>Body</dt><dd><span class="view story-body">Se ve algo</span></dd>...
```

Un modelo con `fields do`, un controlador con `auto_actions`, las rutas de
`hobo_routes`, y **ninguna vista escrita**. Es la promesa de Hobo, funcionando
sobre Rails 8.

**Y cae hacia atrás, no toma el mando:** una aplicación que ha escrito su
plantilla recibe **su** plantilla. En cuanto una página necesita ser distinta, se
escribe, y nada discute. Hay prueba de las dos cosas.

### Y nadie tiene que pedir la derivación

Declarar el modelo **es** pedirla. Un `Engine` la hace en cada `to_prepare`, o
sea en el arranque y en **cada recarga** — que es lo que hace falta para que un
modelo al que le añades un campo en desarrollo gane la columna en sus páginas
sin reiniciar.

Y de paso resuelve el agravante que este plan arrastraba desde la capa 2:
`to_prepare` corre **después** de que el autocargador se haya reiniciado, así que
preguntar por los modelos ahí es lo que hace que Zeitwerk los cargue. La carga
ansiosa que hacía falta sale sola del sitio correcto.

### Por dónde va la capa 5

1. ~~**El JS a Stimulus.**~~ **Hecho**, salvo `delete-button`, que se decide al
   portar el tag. De 1.045 líneas de jQuery quedan ~250 de Stimulus.
2. **El catálogo de vistas por tipo** (pieza 9). `<view>`, las vistas por tipo,
   los tipos ricos, las colecciones, los `inputs` y el barrido de contrato:
   **hecho**. Faltan los tags de colección con formulario (`select-one`,
   `select-many`, `check-many`), que son los que hablan con asociaciones.
3. ~~**El motor de derivación** (pieza 10).~~ **Hecho.** Sin generar código.

**Aplazado a la capa 6:** los 11 tags de `editors/`, que son widgets de
navegador y se deciden con el tema delante.

## Capa 6 — el tema (2026-08-07)

### El inventario, y un aviso grande

`hobo_bootstrap` son **26 tags en 865 líneas**. `<page>` solo, **145 líneas con
~30 puntos de extensión**: es el contrato de temas, y es justo lo que el barrido
de la capa 3 existe para vigilar.

> ⚠ **El tema apunta a `bootstrap-sass ~> 2.1`: Bootstrap 2.1, de 2012.** El
> marcado que escribe —`navbar-inner`, `nav-collapse`, `icon-bar`,
> `data-toggle="collapse"`— **no existe desde Bootstrap 3** (2013), y hoy va por
> la 5.3. Portar el marcado tal cual daría una página maquetada para un CSS que
> lleva trece años sin existir.
>
> **Decisión pendiente de confirmar (la tomo yo para no bloquear):** se porta
> **la estructura y el contrato de params**, que es lo valioso, y el marcado se
> escribe para **Bootstrap 5**. Si prefieres otra cosa —Bootstrap 4, Tailwind,
> o CSS propio sin framework— se cambia el marcado, que es lo barato; el
> contrato no.

> Y una curiosidad que hay que decidir: uno de los params se llama
> **`navbar-innner`**, con tres enes. Es una errata que se publicó, así que
> **forma parte del contrato**: un tema que la sobreescriba se rompe si la
> arreglamos. Propongo arreglarla y anotarlo, porque esta fase es solo para
> aplicaciones nuevas.

### Pieza 13a hecha: los tags estructurales se van a RAPID

No eran del tema. Un mensaje flash, una lista de errores de validación, las
transiciones que ofrece un registro: **eso lo tiene una aplicación, se vea como
se vea**. Un tema decide cómo se ven; no debería decidir si existen.

Moverlos significa que **una aplicación sin tema los tiene igual**, y que un
segundo tema no tiene que reimplementarlos para no perderlos.

| Tag | Qué hace |
|---|---|
| `<flash-message>` / `<flash-messages>` | Los mensajes que dejó la aplicación. **Las clases son las suyas** —`:notice`, `:error`, lo que ponga—, no una lista fija |
| `<error-messages>` | Por qué no se pudo guardar. **No pinta nada si no hay nada que decir**, para que un formulario no arrastre una caja vacía |
| `<transition-buttons>` | Las jugadas que el registro ofrece **a este usuario ahora**. No están escritas en ninguna parte: son lo que el lifecycle de la pieza 5 permite |

**11 pruebas**, con el barrido de contrato.

### Pieza 13b: `<page>`, el contrato de temas — **con prueba**

El plan pedía «contrato de params **con prueba**», y ya existe. `<page>` declara
**28 puntos de extensión**, y una sola línea los recorre todos, en cuatro formas
distintas de página (normal, con columna lateral, con la navegación abajo, con el
javascript al final):

```ruby
assert_every_param_overridable(:page, SCENARIOS)
```

Importa más de lo que parece: **un tema vale exactamente lo que se le pueda
cambiar sin adueñarse de la página entera**, y el primer intento se murió de
params que desaparecían de uno en uno. Hay prueba también de las dos formas de
tocar una esquina: **sustituirla** (`replace`) y **añadirle** sin perder lo que
había (`old`), que es la diferencia entre apilar temas y pelearse con ellos.

**El marcado es Bootstrap 5.** Lo que había apuntaba a Bootstrap 2.1: `spanN`,
`navbar-inner`, `nav-collapse`, `icon-bar`. Los tamaños siguen siendo **doceavos**
—`content_size` y `aside_size` significan lo mismo—, solo cambia cómo se
escriben: `col-9` donde ponía `span9`. Y `<nav>`, `<header>`, `<footer>` y
`<aside>` son ahora los elementos de verdad, no `<div class="navbar">`.

### Y el barrido encontró un hueco en el propio runtime

Al pasarlo por `<page>` reventó en `<meta charset>`: **un elemento vacío es un
param que solo se puede sustituir**, no rellenar — no hay dónde poner el
contenido. El runtime lo sabía (lo lanzaba desde la capa 4) pero **no lo decía**,
así que el barrido pedía algo imposible.

Ahora `parameter_for` distingue `:void_element` de `:element`, y el barrido no
exige rellenar lo que no se puede. Es la tercera vez que el barrido mejora el
runtime en vez de solo vigilarlo.

## Capa 7 — `hobo new` (2026-08-07)

**`hobo new blog` deja una aplicación Rails 8 que arranca, tiene un modelo, su
CRUD y sus páginas — y ni una vista escrita.** Verificado generando una de
verdad, migrándola y pidiéndole una página:

```
$ HOBODEV=... hobo new blog
$ cd blog && bin/rails server
GET /  ->  200
<div class="index-page stories"><h1>Stories</h1>
  <div class="card story"><h3><span class="view story-title">Hobo 2027</span></h3>
```

### Lo que `hobo new` ya no hace

El de antes lanzaba **un asistente interactivo** que preguntaba veinte cosas y
generaba un modelo de usuario, un controlador de portada, un subsite de
administración y un tema **antes de que hubieras escrito una línea**. Eso hacía
los primeros cinco minutos impresionantes y los cinco siguientes confusos.

Ahora es **un `rails new` con las gemas puestas y un ejemplo**, y lo que sale es
**una aplicación de Rails**: todo está donde un desarrollador de Rails lo
buscaría. Para lo demás, `rails generate`.

La plantilla es **un fichero de la gema** (`lib/generators/hobo/app_template.rb`)
en vez de una cadena que se escribía en un temporal, así que se puede leer,
revisar y usar suelta con `rails new blog -m ...`.

### `hobo:resource`, deliberadamente pequeño

Escribe **un modelo y un controlador**. Nada más. El de antes escribía además
cuatro ficheros de vistas y una línea de rutas, y **tres de esas cuatro cosas son
hoy cosas que Hobo deduce** — un generador que escribe lo que se puede derivar es
un generador que alguien tiene que mantener en sintonía para siempre.

Y la sesión la genera Rails: `bin/rails generate authentication`. Es la pieza 15,
delegada, y ahora se puede comprobar que de verdad lo está.

### Cuatro fallos más, todos de los que solo se ven generando una app

| Qué | De qué capa venía |
|---|---|
| `ActiveRecord::Migrator.migrations` y su constructor de tres argumentos, en `migrations_pending?` | **Capa 2.** Sus pruebas ejecutaban las migraciones, pero nunca preguntaban si había pendientes |
| El migrador no se requería a sí mismo (`Generators::Hobo::Migration::Migrator`) | Autocargador clásico, cuarta vez |
| **El generador ofrecía borrar `ar_internal_metadata`**, que es de Rails y llegó en la 5 — decir que sí rompe `rails db:*` para siempre | Capa 2 |
| `before_filter` en `hobo_rapid` | Capa 4 lo arregló en `hobo`, pero no miró las otras gemas |

La prueba de `hobo new` **existe pero no corre por defecto**: genera una
aplicación entera y ejecuta bundler, así que tarda un par de minutos.

```sh
HOBO_TEST_NEW=1 rake test
```

Es la única prueba que comprueba **lo primero que hace una persona**.

---

# Lo que se aprendió el 2026-08-07, y hay que no olvidar

## Por qué 324 pruebas en verde y la aplicación se veía mal

Imanol abrió la aplicación y la vio **sin estilos, sin enlaces y sin la portada
del primer usuario** — con toda la suite en verde. La razón, escrita para no
repetirla:

> **Una prueba escrita a partir del código no puede ver una ausencia.**

Porté `<view>` y probé `<view>`. Porté el tema y probé el tema. Nunca escribí
«una tarjeta enlaza a su registro» ni «la página carga una hoja de estilo», así
que **nada falló cuando no había ninguna de las dos**. Las pruebas decían que
cada pieza hacía lo que yo dije que haría; no que Hobo hiciera lo que Hobo hacía.

Tres agravantes concretos:

1. **No miré lo que hacía el Hobo viejo**, teniéndolo en el repositorio:
   `integration_tests/agility_bootstrap/test` tiene 22 ficheros, y siete de
   integración (`create_account`, `lifecycle`, `search`, `nested_has_many`…).
   **Esa era la especificación de comportamiento.**
2. **Cada capa probó su costura, no el montaje.** Que el tema exista y que las
   páginas existan no prueba que estén conectados — y no lo estaban.
3. **La prueba más cercana al producto (`hobo new`) no corre por defecto.**

## La suite de conformidad: `hobo/test/conformance/`

Lo que arregla eso. Son propiedades **del producto montado**, sacadas de lo que
el Hobo viejo hacía, y escritas para **fallar cuando algo falta**, no cuando algo
está mal. Corren en un navegador de verdad contra una aplicación generada:

```sh
cd hobo && HOBO_APP=~/hobo_apps/hobo_luz rake test
```

Encontró, a la primera: las tarjetas no enlazaban, la navegación no llevaba a
ninguna parte, los timestamps salían en el resumen, `/stories/new` no pintaba
formulario, y la página venía envuelta dos veces.

**Regla nueva de trabajo: antes de portar una pieza, buscar qué exigía de ella el
banco viejo, y escribir esa exigencia como prueba.**

## La portada del primer usuario (pieza 15, la parte que es de Hobo)

**No se había tirado a propósito: faltaba.** Lo que se delegó a Rails es el
modelo de usuario, la sesión y las contraseñas (`bin/rails generate
authentication`). Lo que **Rails no tiene** es saber que una aplicación sin
usuarios debe pedir uno — y eso es la primera pantalla de Hobo, especificada en
`create_account_test.rb`:

```ruby
visit root_path
click_button "Register Administrator"
assert has_content?("You are now the site administrator")
```

Reconstruida: `<front-page>` y `<first-user-form>` en `hobo_rapid`, y un
generador `hobo:front_page` que escribe el `FrontController`. Verificado de punta
a punta: formulario → 302 → «You are now the site administrator» → sesión
iniciada.

Se adapta sola al modelo que haya: busca `User` o `Account`, y usa
`email_address`, `email`, `login` o `name`, lo que la aplicación tenga.

## Cuatro fallos de montaje, todos invisibles a las pruebas de pieza

| Qué | Por qué no se veía |
|---|---|
| **El tema no estaba conectado.** Las páginas derivadas se pintaban sueltas | Probé el tema y probé las páginas, nunca la unión |
| **`model_form` no lo pintaba nadie**: `new` y `edit` daban la página de solo lectura | Igual: la pieza existía y el producto no la tenía |
| **`as: :fields` chocaba con el param `:fields` del formulario** y lo vaciaba en silencio | El barrido de params vigila que se pueda **llegar** a un param, no que dos no se pisen |
| **El token CSRF llegaba nil**: `respond_to?(:form_authenticity_token)` **no ve métodos protegidos**, y en un controlador lo es. Todo formulario de Hobo daba **422** | Fuera de una petición no hay token, así que ninguna prueba de pieza lo notaba |

## La prueba de aceptación final: una videoteca

Propuesta por Imanol, y es el criterio de «esto está terminado»:

> Una aplicación de ejemplo **videoteca**: películas, categorías y géneros, con
> pantallas de listado **con filtros**, formularios, y **formularios anidados** —
> crear un género o una categoría **desde** la película, que es lo que Hobo hacía
> con `input-many` y `select-one-or-new`.

Sencilla, pero toca a la vez: `fields do`, asociaciones en los dos sentidos,
permisos, páginas derivadas, filtros (Ransack), formularios anidados y el
JavaScript de Stimulus. **Si la videoteca se construye sin escribir vistas y
funciona, la portación está hecha.**

Va **después** del empaquetado en una gema.

---

# ESTADO AL RETOMAR (2026-08-07, fin de sesión)

**Lee esto primero.** Es dónde estábamos exactamente y qué hacer a continuación.

## Lo que funciona hoy

Una aplicación Rails 8 generada con `hobo new`:

- **Portada del primer usuario**: sin usuarios, ofrece crearlo («Register
  Administrator»), lo crea, inicia sesión y redirige. Verificado de punta a punta.
- **Índice** derivado: panel de cabecera con nombre y contador, botón «Nuevo X»,
  **tabla** `table table-striped table-bordered`, primera columna enlazando a la
  ficha, columna de acciones (solo si hay algo que ofrecer).
- **Ficha** derivada: panel de cabecera con «Modelo «nombre»» y botón Editar,
  contenido principal aparte, lista de campos, y una sección por colección hija.
- **Formulario** derivado en `new`/`edit`, con el control que pide cada tipo.
- **Tema Bootstrap 5** servido por el engine, más `hobo.css`.
- **Rutas** con `hobo_routes`, subsites, permisos de la pieza 4 aplicados.
- **Asociaciones**: un `belongs_to` se pinta por su nombre y se edita con un
  select de lo que el usuario puede ver; un `has_many`, con casillas.

- **Formularios anidados**: una colección hija se edita dentro del formulario
  de su dueño, con `+` y `−`, y las filas se renumeran solas.
- **Crear desde el formulario**: una asociación con `:accessible => true` deja
  elegir uno de los que hay o hacer uno nuevo ahí mismo.
- **La barra**: quién eres, cómo salir, y el **selector de usuario** de
  desarrollo para mirar la aplicación como cualquiera.
- **Filtros**: `<search-filter>` y `<filter-menu>` sobre Ransack, que suman en
  vez de turnarse.

**Pruebas: 476 en **una** suite (+11 en la del plugin), todas en verde, + la
suite de conformidad en navegador (`cd hobo && HOBO_APP=~/hobo_apps/hobo_luz rake
test`). El banco se regenera con el `hobo new` de hoy: tiene que ser lo que sale
del generador, no lo que salía hace tres commits.**

## Una trampa del banco de pruebas, por si vuelve

`hobo` y `hobo_rapid` comparten la aplicación de integración
(`/tmp/hobo_testapp`). Cada prueba escribe dentro los modelos y las vistas que
necesita y los quita después, en un `ensure` — que cubre una excepción y **no**
cubre que maten el proceso. Un `app/models/story.rb` que sobrevive a una tanda
interrumpida lo autocarga la siguiente, y **lo que falla es la prueba de otra
gema**, con un mensaje sobre una columna que nadie pidió.

Costó media hora de desconcierto. `TestApp.sweep` barre antes de empezar, y lo
llaman las tres pruebas de integración. Si vuelve a aparecer un fallo raro y que
no se repite, mirar ahí primero.

## Cómo correr las cosas (para retomar en frío)

```sh
# toda la suite: una gema, una suite
rake test

# la suite del plugin de ejemplo (contrato de plugin, pieza 17)
rake test_plugin
#   `rake` a secas corre las dos

# el banco de integracion: una aplicacion de Rails de verdad en /tmp/hobo_testapp.
# Sin el se saltan (ruidosamente) las pruebas de test/integration
cd hobo && rake test:app          # force=1 para rehacerla
#   lleva el plugin de ejemplo en el grupo :hobo_plugin, que Rails no requiere
#   por defecto: RAILS_GROUPS=hobo_plugin bin/rails ... arranca la misma
#   aplicacion con el plugin puesto

# quien define cada tag y que definiciones estan tapadas
cd ~/hobo_apps/hobo_luz && bin/rails hobo:tags

# los generadores que hay, dentro de una aplicacion
bin/rails generate hobo:setup_wizard      # las preguntas, aqui y ahora
bin/rails generate hobo:resource nota titulo:string
bin/rails generate hobo:model / hobo:controller / hobo:migration
bin/rails generate hobo:front_controller  # (alias: hobo:front_page)
bin/rails generate hobo:user_resource     # (alias: hobo:signup)
bin/rails generate hobo:user_model / hobo:user_mailer / hobo:user_controller
bin/rails generate hobo:subsite staff     # (alias: hobo:admin_subsite)
bin/rails generate hobo:assets            # llevarte el css del tema

# la suite de conformidad, en navegador, contra una aplicacion arrancada
cd hobo && HOBO_APP=~/hobo_apps/hobo_luz rake test
#   entra sola como admin@example.com / test1234
#   HOBO_APP_URL cambia el puerto (por defecto 3007)
#   HOBO_APP_USER / HOBO_APP_PASSWORD cambian el usuario

# la prueba de `hobo new`, que genera una aplicacion entera (tarda minutos)
HOBO_TEST_NEW=1 rake test

# el banco de navegador de los controladores Stimulus va dentro de la suite
# (hobo/test/hobo_rapid/browser), y se salta solo si no hay Firefox

# generar una aplicacion nueva contra el arbol de trabajo
HOBODEV=/home/imanol/RubymineProjects/hobo hobo/bin/hobo new ~/hobo_apps/loquesea

# y `hobo new` pregunta si hay terminal; cada pregunta es tambien una bandera:
#   --theme=clean|bootstrap|none   --invite-only   --activation-email
#   --admin  --admin-name=staff    --private       --locale=es
#   --front=portada                --skip-migration | --generate-migration
#   --wizard (preguntar siempre)   --no-wizard (no preguntar nunca)
```

**Al tocar una gema hay que reiniciar el servidor**: Rails recarga el código de
la aplicación, no el de las gemas, aunque sean `path:`. Más de una vez en esta
sesión pareció que un arreglo no funcionaba y era esto.

```sh
kill $(pgrep -f "puma.*3009"); sleep 2
cd /tmp/videoteca3 && setsid nohup env HOBODEV=/home/imanol/RubymineProjects/hobo \
  bin/rails server -p 3009 -b 0.0.0.0 >> log/server.log 2>&1 < /dev/null &
```

## El banco de comparación (2026-08-10)

Para poder mirar, no para pasar pruebas. Todo en `~/hobo_apps/`, que sobrevive a
un reinicio; `/tmp` no. Las cinco de la tanda anterior (`hobo_luz`,
`rails8_hobo`, `rails8_baseline`, `agility2`, `agility3`) se borraron a petición
de Imanol; lo que se guardó de ellas está escrito aquí.

| Puerto | Qué | Cómo se arranca |
|---:|---|---|
| **3000** | `hobo2_mi_app`: **el patrón**. Hobo 2.2.6 recién generado con el asistente contestado a mano, con la biblioteca dentro. `git@github.com:imanolGOMI/hobo2_mi_app.git` | `cd ~/hobo_apps/hobo2_mi_app && RBENV_VERSION=2.5.9 bundle exec rails server -p 3000` |
| **3001** | `prueba_nueva_hobo3`: la de Imanol, hecha con el `hobo new` de hoy | suya |

Usuario del 3000: `admin@example.com` / `test1234` (el primer administrador es
el de Imanol y no se toca).

⚠ **Los puertos los da Imanol.** El 3000 y el 3001 son estos porque él lo pidió;
antes eran suyos y no se tocaban. Preguntar antes de ocupar uno.

**Cómo se volvió a levantar la de Hobo 2**, que es lo que más cuesta:
`~/hobo_apps/hobo2_gems` es una copia plana (sin git del repo) de `master`, con
`NAME_STR` → `QNAME_STR` en `dryml/lib/dryml/parser/base_parser.rb`. En el
`Gemfile` de la app: `git://` → `https://` (GitHub ya no sirve `git://`), rails
`4.2.11.3`, `sqlite3 1.3.13`, `ffi < 1.17` (la 1.17 pide Ruby 3) y **`kramdown
< 2.0`**, porque kramdown 2.5 arrastra `rexml 3.4` y el parser de DRYML es de
2012: con esa rexml, `NEW_REX` sale falso y todo DRYML es «malformed XML». Con
la rexml de la propia Ruby 2.5 (3.1.7.4) funciona. Falta `gem "blankslate"`, que
`hobo_support` usa y nadie declara.

Y dos cosas más, del día que se volvió a hacer desde cero (2026-08-10):

- **El ejecutable `hobo` no arranca**: el RubyGems 2.7.6 de esa Ruby muere con
  `uninitialized constant Gem::BundlerVersionFinder` antes de llegar a su
  primera línea. `RUBYOPT=-rbundler` lo desbloquea. El comando completo es
  `HOBODEV=~/hobo_apps/hobo2_gems RAILS_VERSION=4.2.11.3 RUBYOPT=-rbundler hobo
  new <app> --skip-wizard --skip-bundle -d sqlite3`, y luego
  `bundle exec rails generate hobo:setup_wizard` con las respuestas por la
  entrada estándar, una por línea.
- **Las gemas publicadas de Hobo 2 ya no sirven en un Ruby moderno**, y esto es
  el argumento entero de este proyecto en una línea: el parser de DRYML usa
  `REXML::Parsers::BaseParser::NAME_STR`, que **no existe en ninguna REXML
  actual** —hoy se llama `QNAME_STR`—. Por eso la aplicación del banco apunta a
  la copia parcheada y no a rubygems: no es una comodidad de desarrollo, es que
  `gem "hobo", "2.2.6"` no levanta. Con Ruby 1.9.3 sí, y por eso `amenti_v2`
  sigue en pie.

## La aplicación de pruebas viva

⚠ **`/tmp` se vacía al reiniciar la máquina, y se vació.** El 2026-08-09 ya no
existía ninguna de las tres aplicaciones, ni el worktree `/tmp/hobo2`, ni las
capturas. Las de Hobo 3 se regeneran en minutos; **la de Hobo 2 no** —cuesta lo
que dice la tabla de más abajo: sqlite3 1.3.13 compilado a mano, el parche de
REXML, el asistente contestado por la entrada estándar—. Por eso el banco de
conformidad vive ahora en `~/hobo_apps/`, que sobrevive.

```
~/hobo_apps/hobo_luz   el banco de conformidad. Regenerado con el `hobo new` de
http://localhost:3007  hoy: tiene que ser lo que sale del generador, no lo que
                       salia hace tres commits. Un modelo Story, un usuario.
                       admin@example.com / test1234

/tmp/hobo_testapp      el banco de integracion (`cd hobo && rake test:app`).
                       Este si puede vivir en /tmp: se rehace solo.

PERDIDAS, hay que rehacerlas si se vuelve a comparar pantalla a pantalla:
  videoteca3 (3009)    la videoteca en Hobo 3. Movie / Category / Genre /
                       MovieGenre; se rehace con `hobo new` + tres modelos
  videoteca2_app (3008) la MISMA en Hobo 2.2.6 (Rails 4.2, Ruby 2.5.9)
  /tmp/hobo2           worktree de master con Hobo 2.2.6 intacto
  capturas             /tmp/shots_hobo2/ y /tmp/shots_hobo3/
```

⚠ **Los puertos 3000 (`miapp`) y 3001 (`amenti_v3`) son de Imanol. No tocarlos.**
El 3002 es `amenti_v2` (Hobo 2, Ruby 1.9.3).

## La app de referencia en Hobo 2: **terminada**

```
/tmp/hobo2             git worktree de master (Hobo 2.2.6 intacto)
/tmp/videoteca2_app    Hobo 2.2.6, Ruby 2.5.9, Rails 4.2.11.3, sqlite
http://localhost:3008  admin@example.com / test1234
```

Arranca, tiene la videoteca dentro y se ve. Capturas en `/tmp/shots_hobo2/`.
Lo que hizo falta, anotado porque nada de esto se adivina:

| Problema | Solución |
|---|---|
| `NAME_STR` no existe en REXML | Es el mismo patrón que hoy se llama **`QNAME_STR`** (nombre con prefijo opcional, dos grupos de captura). Parcheado en `/tmp/hobo2/dryml/lib/dryml/parser/base_parser.rb`, **fuera del repo**: es una copia de trabajo, no `master`. Ninguna versión del gem `rexml` lo trae: la 3.1.7.3 publicada **no** es la que traía Ruby 1.9.3 |
| El esqueleto era de Rails 5 | El `hobo new` de Hobo 2 llama al `rails` que haya. Regenerado con `rails _4.2.11.3_ new`, que es lo único que evita ir arreglando `EventedFileUpdateChecker`, `perform_caching` y `public_file_server` de uno en uno |
| **MySQL ya no entra** | La contraseña que documentaba la sesión anterior no vale, y no hay `sudo`. Se pasó a **sqlite** |
| `sqlite3 1.3.13` no compila: no hay `libsqlite3-dev` | Se baja el `.deb` **sin root** (`apt-get download libsqlite3-dev`) y se extrae con `dpkg-deb -x`; se compila contra esa cabecera. Hay que **quitar el `libsqlite3.a`** del paquete, o el enlazador lo prefiere y falla por `-fPIC`, y **rehacer el symlink** `libsqlite3.so` para que apunte al del sistema. Enlaza contra `libsqlite3.so.0`, que sí está instalada, así que sigue funcionando cuando se borre lo descargado |
| El asistente pregunta y no hay terminal | `--default` **no existe**. Se le meten las respuestas por la entrada estándar |
| **`Categoria` se rompe** | El inflector inglés tiene una regla para los plurales latinos (`media`, `criteria`): `categoria` es su propio plural, y el singular le sale `Categorium`. **Los modelos van en inglés** — `Movie`, `Category`, `Genre` — que además es lo que dice la regla del repositorio |

### Los modelos de la videoteca, iguales en las dos

```ruby
Movie:      title, year, synopsis · belongs_to :category, :accessible => true
                                  · has_many :movie_genres, :accessible => true
                                  · has_many :genres, :through => :movie_genres
                                  · children :movie_genres
MovieGenre: belongs_to :movie · belongs_to :genre, :accessible => true
Category:   name · has_many :movies
Genre:      name · has_many :movies, :through => :movie_genres
```


## La prueba de aceptación: la videoteca

Decidida por Imanol. **La misma aplicación en Hobo 2 y en Hobo 3**, para
comparar pantalla a pantalla:

- **Modelos**: `Movie` (title, year, synopsis), `Category`, `Genre` — en inglés,
  ver arriba por qué
- **Asociaciones**: película pertenece a categoría; película tiene muchos géneros
- **Pantallas**: listado con **filtros**, ficha, alta y edición
- **Formularios anidados**: crear una categoría o un género **desde** la película
  — que es lo que Hobo hacía con `input-many` y `select-one-or-new`

**Si la videoteca se construye sin escribir vistas, funciona, y se parece a la de
Hobo 2, la portación está hecha.**

Las dos existen ya, con los mismos modelos y los mismos datos:

```
http://localhost:3008   /tmp/videoteca2_app   Hobo 2.2.6, Rails 4.2, Ruby 2.5.9
http://localhost:3009   /tmp/videoteca3       Hobo 3,     Rails 8.1, Ruby 3.4.6
capturas: /tmp/shots_hobo2/ y /tmp/shots_hobo3/, mismos nombres de fichero
```

## Comparar las dos pantalla a pantalla: lo que salió (2026-08-07)

Es la primera vez que se mira lo mismo, hecho por las dos. **Encontró cuatro
fallos de montaje en cuatro pantallas**, y todos con la suite en verde. Cada uno
va con su prueba, y las cuatro pruebas son de las que fallan **cuando algo
falta**:

| Qué se veía | Qué era | Prueba |
|---|---|---|
| `/session/new` reventaba con «wrong number of arguments (given 0, expected 1..4)» | `hobo/extensions/action_view/tag_helper.rb`, un parche de 2008 que reabría `tag` con el nombre **obligatorio**. En Rails el nombre es opcional: `tag` **sin argumentos es el constructor de etiquetas**, y así emite marcado todo lo escrito desde Rails 5.1, `javascript_importmap_tags` incluido. Era del compilador viejo de DRYML, que ya no está. **Borrado** | `hobo/test/integration/action_view_test.rb` |
| Las páginas de Rails, sin tema | El `gsub` de `hobo new` buscaba `<%= stylesheet_link_tag :app %>` y Rails 8.1 escribe `stylesheet_link_tag :app, "data-turbo-track": "reload"`. **`gsub_file` anuncia el fichero haya cambiado algo o no**, así que el tema se desenchufó sin decir nada — otra vez | `test_the_layout_wears_the_theme` |
| **Los formularios salían de solo lectura** y no había columna de acciones | `acting_user` en el runtime de tags devolvía `nil`, siempre, con un comentario que decía que ya se conectaría. Y la otra mitad: **Rails 8 recupera la sesión dentro de `require_authentication`**, el filtro que la decisión 17 salta a propósito, así que nadie leía la cookie. Con las dos cosas, toda la aplicación se pintaba para un invitado | `views_test.rb` (los dos sentidos) |
| `Category` salía como **`1`** en el índice, en la ficha y como caja de número en el formulario | El motor derivaba `category_id`, que es lo que guarda la base de datos. Ahora deriva **`category`**, que es de lo que va la página: `<view>` la pinta por su nombre y `<input>` da un **select** de las categorías que este usuario puede ver | `derivation_test.rb`, `associations_test.rb` |

> **La lección, otra vez y en su forma más pura:** `acting_user` llevaba semanas
> devolviendo `nil` y **ninguna prueba falló**, porque cada prueba de pieza
> preguntaba qué hace la pieza *para un invitado* y obtenía justo eso.
> **Un tag que hace una pregunta que él mismo contesta no está preguntando
> nada.** No se vio hasta poner las dos aplicaciones una al lado de la otra.

De paso: el estado de la petición (quién pregunta, el token, el flash) sale de
`helper.rb` a **`hobo_rapid/lib/hobo_rapid/request.rb`**, porque lo necesitan los
tags y lo necesita el puente, y los tags no deben tener que cargar la mitad de
Rails para poder probarse.

Y dos pruebas de conformidad se habían quedado viejas: miraban `.card` en `/`,
cuando `/` es la portada del primer usuario y la capa 5 devolvió el índice a
**tabla**. Ahora miran la lista y exigen lo que de verdad importa —que el nombre
del registro lleve a alguna parte— sea tarjeta o sea fila.

### Los formularios anidados — **hechos** (2026-08-07)

`<input-many>`, la mitad del criterio de aceptación. Un `children` llega ahora
al formulario como una lista que se puede crecer y encoger, con `+` y `−`, y
**verificado en un navegador de verdad**: añadir una fila, guardar tres,
quitar una, guardar dos.

El comportamiento ya estaba —`rapid_input_many_controller.js`, portado a
Stimulus en la capa 5, con sus pruebas de navegador—. Lo que faltaba era el tag
que pinta el DOM que ese controlador lee, y el DOM es el contrato entre los dos:

```html
<div class="input-many" data-controller="rapid-input-many"
     data-rapid-input-many-prefix-value="movie[movie_genres]">
  <div data-rapid-input-many-target="template" hidden>…índice -1…</div>
  <div data-rapid-input-many-target="item">…índice 0…</div>
  <div data-rapid-input-many-target="empty" hidden>…</div>
</div>
```

Tres cosas que no se adivinan, y que salen de mirar lo que emite Hobo 2:

1. **La fila plantilla, en el índice −1.** Sin ella una colección vacía no puede
   crecer nunca: no hay nada que clonar.
2. **Los nombres son los de Hobo, no los de Rails**: `movie[movie_genres][0][genre_id]`,
   sin `_attributes`, y un `belongs_to` viaja como su clave ajena. Es lo que lee
   `:accessible => true`, y es lo que permite que una fila nombre un registro
   que todavía no existe.
3. **Vaciar tiene que decirse.** Unos parámetros a los que simplemente les falta
   la clave significan «déjala como está», así que las filas borradas vuelven en
   la página siguiente. De ahí el `empty-input`.

### Y por debajo, tres fallos más, cada uno tapando al siguiente

Este es el patrón de la sesión: cada arreglo destapa el de abajo.

| Qué | Era |
|---|---|
| Toda petición de alguien con sesión moría en un `before_action` | `logged_in?` hacía `current_user.guest?`, y **el User que escribe `bin/rails generate authentication` no sabe qué es eso**. Estaba tapado por el fallo que hacía invitado a todo el mundo |
| `:accessible => true` **no hacía absolutamente nada** | Un `end` de más en `accessible_associations.rb` cerraba el módulo ochenta líneas antes de tiempo. Las macros acababan definidas en `Hobo::Model`, así que la opción se aceptaba, se guardaba en la reflexión y no instalaba nada: el hash de filas llegaba tal cual al escritor de ActiveRecord, que quiere registros. Y el `def self.included` huérfano era entonces el de `Hobo::Model`; solo el orden de carga impedía que lo reemplazara |
| **Ni una línea del JavaScript de la aplicación corría en las páginas que pinta Hobo** | Dos cosas a la vez. El engine no exponía sus controladores Stimulus —el `app/javascript` de un engine no está en el camino de nadie, y sus pins no están en el mapa de nadie— y `<javascript>` emitía un `<script src>` pelado, cuando el punto de entrada es un módulo ES que necesita el import map para resolver sus imports. Las páginas de Rails iban bien, que es justo por qué no se veía |

> Los cuatro controladores portados en la capa 5 tenían prueba de navegador cada
> uno, y **ninguna aplicación cargaba ninguno**. Es el tema desenchufado otra
> vez: la pieza existe y el producto no la tiene.

### `<select-one-or-new>` — **hecho** (2026-08-07)

Elegir uno de los que hay, **o hacerlo aquí mismo**. Verificado en un navegador:
desde el formulario de la película se crearon una categoría y un género nuevos,
sin salir de la página y **sin tocar el controlador**.

Hobo 2 lo hacía con un modal, y su propia documentación admitía el precio:
había que parchear el `create` del controlador para xhr **e inyectar JavaScript**
que volviera a seleccionar el registro. Nada de eso hace falta cuando los campos
del registro nuevo viajan en el formulario del padre: `:accessible => true` lo
crea al guardar, que es el mismo camino de `<input-many>`.

Así que en el servidor no había casi nada que inventar, y en el navegador queda
**una sola invariante**:

> Se envía exactamente **una** de las dos mitades. Las dos llegarían a
> `attributes=` y la segunda ganaría en silencio — el tipo de fallo que parece
> «a veces guarda otra cosa».

El select no se deshabilita, que impediría cambiar de idea: **se le quita el
nombre**, porque un control sin nombre no se envía. Y ese nombre queda aparcado
en el elemento para que `<input-many>` lo renumere junto con todo lo demás.

**Lo elige el modelo, no la vista:** `<input>` da un `<select-one-or-new>`
cuando la asociación dice `:accessible => true`, y un `<select-one>` normal
cuando no. Nadie edita una plantilla para conseguirlo, y nadie se lo encuentra
sin querer.

### El diseño, mirándolo al lado del de Hobo 2

Imanol comparó 3008 y 3009 y señaló lo que salta en cuanto se ven juntos: la
barra en blanco, sin fondo, y el icono de borrar mal. Las dos causas:

| Qué | Era |
|---|---|
| La barra superior, blanca sobre blanco | Una `navbar` de Bootstrap 5 es **transparente** salvo que se le diga otra cosa. El tema viejo lo sacaba de `navbar-inner`, que Bootstrap 5 se llevó. Ahora `bg-body-tertiary border-bottom`, y las cabeceras de página igual |
| El borrar salía como un botón azul enorme | Una regla de `hobo.css` escrita **para las páginas que pinta Rails** (`.container form button:not(.btn)`) alcanzaba el formulario de borrado de Hobo, que también es un formulario y cuyo botón tampoco es `.btn`. Y a los `+`/`−` de `<input-many>` igual. **Una regla escrita para el marcado de otro tiene que decir dónde para** |

### La barra de navegación, y el selector de usuario — **hecho** (2026-08-07)

Imanol: *«esa funcionalidad de Hobo de poder cambiar entre usuarios con ese
selector era clave y fue portada a una gema que a día de hoy utilizo en otros
proyectos»*. Está.

**`<session-links>`** — quién eres y cómo dejar de serlo. Va en RAPID, no en el
tema (pieza 13a): *que* una aplicación diga quién eres no es cuestión de gusto.
El «Log out» es un **formulario**, no un enlace, porque en Rails es un DELETE y
porque un enlace que cierra la sesión lo siguen todos los rastreadores y
precargadores que hay.

**`<dev-user-changer>`** — el selector. Es la herramienta que hace que valga la
pena escribir `view_permitted?`: lo declaras y luego **miras**, como cada
persona, en un clic. Comprobar permisos entrando y saliendo es comprobarlos una
vez y nunca más.

- Es un **formulario GET con un select que se envía solo**, reutilizando
  `rapid_autosubmit_controller` de la capa 5. Sin JavaScript en línea, así que
  no hay excepción que hacer en la política de contenido — el `onchange="..."`
  de Hobo 2 hoy no pasaría.
- **Tres cerrojos, y ninguno sobra**: la ruta no se dibuja en producción, hace
  falta `config.hobo.developer_features`, y el controlador vuelve a comprobarlo.
  Una forma de convertirse en cualquier usuario tiene que ser imposible de
  encender sin querer.
- La primera opción es **Guest**, que es como miras tu aplicación como la ve un
  extraño.
- El controlador usa `start_new_session_for` de Rails 8 si existe, y el
  `current_user=` de Hobo si no. Ni una cosa ni la otra están escritas a fuego.

Verificado en navegador: admin → lector → Guest, quedándose en `/movies`, y con
las acciones de la tabla apareciendo y desapareciendo.

### Y de paso, el fallo que el selector destapó: **un invitado no es nadie**

Al mirar la aplicación como Guest seguían saliendo los botones de editar y
borrar. La causa, que es de las buenas:

> El `current_user` de Hobo **nunca contesta nil**: contesta un `Guest`, un
> objeto que dice que no a todo. Eso está bien para la capa de modelo, que le
> hace preguntas. Y está mal para los tags, porque un modelo generado dice
> `acting_user.present?` — y **un Guest está presente**.

Así que un extraño veía un formulario para rellenar y botones que pulsar. El
puente (`rapid_tag`) normaliza ahora: **para los tags, nadie es nil**.

**Y eso rompió una prueba, con razón:** la suite de conformidad navegaba como
extraño y pasaba, porque un Guest contaba como alguien. Ahora **entra como
usuario** (`HOBO_APP_USER` / `HOBO_APP_PASSWORD`, por defecto
`admin@example.com` / `test1234`), que es lo que debió hacer siempre: un
formulario es para alguien.

### El diseño, segunda pasada

Más cosas que Imanol vio comparando 3008 y 3009:

| Qué | Arreglo |
|---|---|
| El menú no ocupaba todo el ancho | `container-fluid px-4` en la barra, en vez de `container`, que la encogía a 1140px |
| Las cabeceras, menos marcadas que las de Hobo 2 | `font-weight: 700` en las cabeceras de página y en la marca |

### Los filtros — **hechos** (2026-08-07). Con esto el criterio de aceptación está completo

`<search-filter>` y `<filter-menu>`, y el índice pasando la colección por
Ransack. Verificado en navegador con las cuatro combinaciones y con el SQL
delante:

```
sin filtro          -> Blade Runner, El apartamento
q[title_or_synopsis_cont]=blade    -> Blade Runner
q[category_id_eq]=2                -> El apartamento
los dos a la vez                   -> nada (Blade Runner no es comedia)
```

**La mitad del servidor ya estaba hecha desde la capa 4**, y el plan no lo
decía: `Hobo::Model.ransackable_attributes` deriva de las columnas del modelo
menos las que nunca se enseñan. Eso es lo que hace que funcionen sin escribir
nada: con Ransack a secas hay que escribir esa lista a mano en cada modelo.

Lo que faltaba:

- **`apply_search` en `find_or_paginate`**, antes de ordenar y paginar, para que
  una lista filtrada se pagine por lo que le queda y no por lo que tenía. Solo
  cuando `params[:q]` es un hash: `hobo_completions` también lee `params[:q]`,
  como cadena, porque es lo que mandaba jQuery Tokeninput.
- **Un param `:filters`** en el índice derivado, vacío. Es la única forma de que
  una aplicación ponga filtros sin adueñarse de la página entera, y vacío por
  decisión 18.
- **El puente lleva ahora la query string** (`HoboRapid.query_parameters`). Sin
  eso un filtro no puede enseñar lo que está puesto ni conservar lo de los
  demás.

**La propiedad que más se rompe, y la que tiene prueba propia:** dos filtros en
una página tienen que **sumar, no turnarse**. Cada formulario lleva escondido lo
que tienen los otros; si no, elegir una categoría se lleva por delante la
búsqueda que habías escrito — y en silencio, que es la peor forma de perder algo.

Así se escribe en una aplicación, y es todo lo que hay que escribir:

```erb
<%# app/views/movies/index.html.erb %>
<%= rapid_tag :index_page, @movies,
      :filters => Rapid.markup {
        call_tag(:search_filter, { :fields => "title, synopsis" })
        call_tag(:filter_menu, { :field => "category" })
      } %>
```

> **Ojo con las llaves.** `call_tag(nombre, atributos, **params)`: sin llaves,
> Ruby manda los `:clave => valor` a los **params** y el tag no ve ni un
> atributo. Pasó al escribir esta misma página, y falla en silencio.

De paso, `rapid_tag` aprendió a distinguirlos: un `Rapid::Parameter` es un
param, cualquier otra cosa es un atributo. En DRYML los separaba la sintaxis
—`<heading:>…</heading:>` frente a `class="big"`—, y aquí lo dice el valor.

Y el `<filter-menu>` trae un botón «Filtrar» **para quien no tenga JavaScript**,
que el controlador de Stimulus quita al conectarse: la página funciona de las
dos maneras y se ve bien las dos veces.

### Lo que la comparación deja pendiente

Visto en las capturas, ordenado por lo que más se nota:

1. **Los textos de la interfaz están a medias en castellano**: «Nuevo movie»,
   «Crear», «Guardar», «Editar», «Acciones», junto a etiquetas en inglés. Hobo 2
   dice «New Movie», «Create Movie». La regla del repositorio es **código en
   inglés**, y esto es cadena de interfaz: va en inglés, y luego i18n.
2. **Un `belongs_to` no enlaza**: Hobo 2 pinta «Drama» como enlace a la
   categoría; Hobo 3 pinta el texto.
3. **El buscador de la barra** (`<live-search>` de Hobo 2, contra `/search`).
   El menú de usuario ya está; el buscador no.

## Decisiones tomadas en esta sesión

16. **Un solo diseño por defecto: Bootstrap.** Nada de mantener `hobo_clean` en
    paralelo. Otros temas (Tailwind, etc.) serán una opción de `hobo new` más
    adelante; ahora no.
17. **Un controlador de Hobo deja pasar la petición y pregunta al registro.**
    El generador de autenticación de Rails 8 pone `require_authentication` en
    todos, y eso **impide que los permisos de Hobo lleguen a preguntarse**: un
    índice público se convierte en un muro de login. Los controladores de Hobo
    hacen `allow_unauthenticated_access` y deciden los permisos del modelo.

## Decisiones tomadas el 2026-08-07 (segunda tanda)

18. **Los filtros los pone la aplicación; Hobo pone los tags y Ransack.**
    Se comprobó que **el índice derivado de Hobo 2 tampoco tenía filtros**:
    pintaba `<collection>` y ya. `<search-filter>`, `<filter-menu>` y
    `<table-plus>` eran tags que escribías **a mano** en tu `index.dryml`. Lo
    que sí era automático eran los scopes de la pieza 6, y eso es lo que se
    delegó a Ransack. Así que: Hobo trae los tags, el controlador pasa la
    colección por Ransack para que funcionen sin escribir consultas, y el índice
    derivado sigue sin filtros. Se mantiene la comparación pantalla a pantalla.
19. **`<select-one-or-new>` va en línea, no en un modal.** Ver arriba: el modal
    de Hobo 2 exigía tocar el controlador de cada aplicación.
20. **Para los tags, nadie es `nil`.** El `current_user` de Hobo contesta un
    `Guest`, que **está presente**, y los modelos generados dicen
    `acting_user.present?`. El puente lo normaliza. Si alguna vez vuelve un
    modelo al estilo Hobo 2 que llame a `acting_user.administrator?`, este es el
    sitio donde mirar.
21. **El selector de usuario se queda, y con tres cerrojos.** Imanol lo usa hoy
    en otros proyectos y es lo que hace útiles los permisos. Ruta no dibujada en
    producción + `config.hobo.developer_features` + comprobación en el
    controlador.
22. **Un plugin es un engine de Rails que define tags y trae assets, y punto.**
    Instalarlo es ponerlo en el `Gemfile` (era la opción 1 de las que se
    preguntaron). Se caen las otras tres cosas que hacía `rails generate
    hobo:install_plugin`: el `<include gem="..."/>` del taglib, el `//= require`
    del JavaScript y el `*= require` de la hoja de estilos. **Definir un tag es
    registrarlo**, y los assets los trae el engine. Sin activación por subsitio:
    Imanol no la ha usado nunca y para un diseño distinto usa CSS.
23. **`bin/rails hobo:tags`**, porque el registro de tags es global. Redefinir un
    tag del catálogo es legítimo —es *para* eso que existen los plugins— y es
    invisible: gana el último que carga y nadie avisa. La tabla dice quién define
    cada tag y marca `shadowed` lo que ya no pinta nada. Es la lección de la
    fusión convertida en herramienta.
32. **Escribir un plugin también es un generador.** `rails generate hobo:plugin
    <nombre>` escribe el esqueleto de la gema —engine, fichero de tags, assets,
    import map, gemspec y prueba—, que es exactamente lo que es `hobo_timeago/`.
    La prueba lo genera en un directorio temporal, carga lo escrito, comprueba
    que el tag quedó registrado y lo borra.
31. **El asistente es un generador, no un momento.** `rails generate
    hobo:setup_wizard` hace las preguntas y hace lo que dicen, **también en una
    aplicación que ya existe** —que es lo que necesita quien acaba de añadir la
    gema a la suya—. `hobo new` lo llama, así que hay **un solo sitio que
    pregunta**, y cada pregunta es además una bandera para que un guion no se
    pare. No rehace lo que ya está.
30. **Si la función existe, el nombre de Hobo 2 sigue funcionando.** Que el
    trabajo de un generador lo haga otro fichero no es lo mismo que que el
    trabajo haya desaparecido. `hobo:user_resource`, `hobo:user_model`,
    `hobo:user_mailer`, `hobo:user_controller`, `hobo:front_controller`,
    `hobo:subsite`, `hobo:controller` y `hobo:assets` vuelven a funcionar, y
    los nombres nuevos (`hobo:signup`, `hobo:front_page`, `hobo:admin_subsite`)
    **heredan** en vez de copiar: dos nombres para una cosa es malo, dos
    implementaciones de una cosa es peor.
29. **El tema es una elección de tres, y puede ser distinta por subsitio**
    (cierra 13a/13b y revisa la 25). El catálogo escribe el **papel** de cada
    cosa —`index-page`, `content-header`, `collection-table`, `action new`— y
    **un tema es una tabla de nombres y una hoja de estilos**, nada más:
    `clean` (el de Hobo, por defecto, sin dependencias), `bootstrap`, o `none`
    (el cuerpo con sus clases dentro de tu layout). Un subsitio puede vestir
    otro: `config.hobo.subsite_themes = { "admin" => :bootstrap }`.
28. **`<page>` es del catálogo, no del tema.** Vivía dentro de
    `hobo_bootstrap`, y por eso solo podía haber un tema. Sus ~30 puntos de
    extensión siguen siendo el contrato.
27. **Un subsitio es una carpeta de controladores** (afina la decisión 14). No se
    registra en ningún sitio: `app/controllers/admin/` con algo dentro *es* el
    subsitio `admin`, y sus rutas las dibuja `hobo_routes`. Lo que el generador
    escribe son controladores y una regla de quién entra.
26. **Un modelo posee su tabla solo si la describe.** `fields do ... end` es un
    modelo diciendo lo que tiene, y solo entonces el generador de migraciones
    propone borrar lo que no está. `add_fields do ... end` es Hobo añadiendo a la
    tabla de otro: añade y no toca el resto. Es lo que hace seguro meter Hobo en
    una aplicación que ya existe.
25. **El tema es una pregunta, no un hecho** (revisa la decisión 13). Sigue
    viniendo dentro de la gema y sigue siendo lo que sale por defecto, pero lo
    carga un initializer y la aplicación puede decir `config.hobo.theme = false`:
    entonces Hobo pinta **el cuerpo** de cada página y el layout de la aplicación
    la envuelve. Es lo que permite meter Hobo en una app que ya tiene diseño, y
    lo que permite empezar en blanco. `hobo new --no-theme`.
24. **El inglés es el `:default`, y no hay `hobo.en.yml`.** Cada cadena viaja
    como clave con su inglés escrito en el sitio donde se pinta, y lo que se
    entrega es un fichero por idioma añadido (`hobo.es.yml`). Dos listas de las
    mismas cadenas se separan, y la que nadie lee es la que está mal. Una
    aplicación que quiera otro inglés escribe su `hobo.en.yml`, que es como se
    pisan las traducciones de una gema en Rails de toda la vida.

## Paridad de `hobo new`: las preguntas del asistente (2026-08-09)

**Criterio, de Imanol:** antes de los pasos grandes, `hobo new` tiene que dejar
lo mismo que dejaba en Hobo 2. Y las preguntas del asistente **no se tiran**.

**El asistente existe** (`hobo new blog` pregunta), y además cada pregunta es una
bandera, así que un guion nunca se para: `hobo new blog --theme=none
--invite-only --locale=es`. Sin terminal, todas toman su valor por defecto —eso
es lo que hacen las pruebas—; `--wizard` pregunta siempre y `--no-wizard` nunca.

Lo que desapareció del asistente viejo no son las preguntas: son las veinte
preguntas **antes de escribir una línea**, y cuatro que configuraban cosas que
ya no existen.

| Pregunta del asistente de Hobo 2 | Hoy |
|---|---|
| Tema del front | **`--theme=clean\|bootstrap\|none`** ✔ (decisión 29) |
| Tema del subsitio de administración | **`--theme=` en `hobo:admin_subsite`** ✔ |
| Tema de jQuery-UI (front y admin) | **Desaparece**: no hay jQuery-UI. Un widget con aspecto propio es hoy un plugin (decisión 22) |
| ¿Solo plantillas DRYML? | **Desaparece**: las dos cosas funcionan a la vez sin configurar nada. Escribes `index.html.erb` y Hobo se aparta; no la escribes y la deriva |
| Nombre del recurso de usuario | El `User` de Rails 8 (decisión 15) |
| Nombre del controlador de portada | **`--front=home`** ✔ |
| Nombre del subsitio | **argumento de `hobo:admin_subsite`** ✔ |
| Migración inicial: saltar/generar/migrar | **`--skip-migration` / `--generate-migration`** ✔ |
| ¿Repositorio git? | `rails new` lo hace; `--skip-git` para que no |
| ¿Que git ignore los autogenerados? | **Desaparece**: no se genera ningún fichero |
| Instalar plugins por defecto (jquery, jquery-ui) | No aplica: Stimulus (decisión 14) |
| Nombre del controlador de portada | `hobo:front_page` ✔ |
| Modelo de usuario, sesión, contraseñas | Rails 8 (decisión 15) ✔ |
| Alta de usuario | `hobo:signup` ✔ |
| ¿Activación por correo? | **`hobo new --activation-email`** ✔ |
| ¿Solo por invitación? | **`hobo new --invite-only`** ✔ |
| ¿Subsitio de administración? | **`rails generate hobo:admin_subsite`** ✔ |
| ¿Sitio privado? | falta (un `before_action`) |
| Migración inicial | `hobo:migration` ✔ |
| Locales / idioma por defecto | parcial: hay `hobo.es.yml`; falta el generador |
| Repo git | `rails new` ✔ |

### Las claves de lifecycle no funcionaban en Rails 8

Lo primero que apareció al ir a por la activación, porque va montada encima.
Un paso con `:new_key => true` pone una clave de un solo uso en un correo, y
quien vuelve con ella puede dar el siguiente paso.

- Se firmaba con `Rails.application.config.secret_token`, que **Rails quitó en
  la 5.2**: en Rails 8 esa línea es un `NoMethodError`. Ahora firma con el
  `secret_key_base` de la aplicación, y fuera de Rails con
  `HOBO_LIFECYCLE_SECRET`. Sin secreto se niega: una clave firmada con nada no
  es una clave.
- `generate_key` exigía `Time.zone` y **no lo usaba** —la línea siguiente es
  `Time.now.utc`—. En una aplicación siempre está puesto, así que el guardián
  solo saltaba fuera de Rails: justo donde uno quiere probar esto sin arrancar
  una aplicación.

Ninguna prueba podía verlo: la suite probaba estados y transiciones y **nunca
había pedido una clave**.

### Las cuentas: alta, activación e invitación

`bin/rails generate hobo:signup` escribe el alta, y **las dos preguntas del
asistente viajan desde `hobo new`**, que es donde se preguntaban:

```sh
hobo new blog                      # alta publica, cuenta activa al momento
hobo new blog --activation-email   # se da de alta y confirma por correo
hobo new blog --invite-only        # nadie se da de alta: te invitan
```

Con `--invite-only` **la ruta de alta no se dibuja**, así que la página no existe
y la barra deja de ofrecerla sola: el interruptor es la ruta, no una bandera.

Todo va montado sobre los **lifecycles** (pieza 5), que es para lo que existen:
las reglas —quién puede darse de alta, qué pide el alta, en qué estado deja la
cuenta, quién puede encenderla— viven en el modelo, no en el controlador.

**Tres trampas de los lifecycles, que solo se aprenden usándolos:**

| Qué | Cómo se ve |
|---|---|
| **Dentro de un paso solo pasan los atributos que el paso declara** | Poner la contraseña de un invitado en un callback se perdía por el camino, y el registro moría con «Password can't be blank». Se pone el *digest*, que además es lo honesto: no hay contraseña hasta que la elige quien acepta |
| **El contexto de validación es el nombre del paso**, no `:create` | Es una característica —deja escribir `validates :x, :on => :signup`— y hace que un `before_validation :on => :create` no se dispare nunca ahí |
| **Una transición responde lo que responda su bloque**, y un paso sin bloque responde `nil` | `if transicion!` lee como fallo un movimiento que salió perfecto. Si funcionó, se le pregunta al registro |

Y un fallo del producto: **el primer usuario quedaba sin activar y no podía
entrar** —una puerta cerrada con la llave dentro—. La portada lo crea
directamente, sin pasar por ningún paso, así que el estado por defecto del
lifecycle no es el suyo. Ahora queda activo **y administrador**, como en Hobo 2,
y eso hace verdad lo que la portada llevaba prometiendo desde el principio
(«You are now the site administrator»).

### Hobo no borra columnas de una tabla que no describió

Al montar la activación sobre el `User` de Rails 8, `hobo:migration` ofrecía
**borrar `email_address` y `password_digest`**, y preguntaba por terminal para
confirmarlo: en un guion esa pregunta no la contesta nadie —la prueba de
integración se quedó colgada veinte minutos y parecía lentitud— y delante de una
persona es una pregunta de más.

**Un modelo posee su tabla solo si la describe**, es decir si escribe su bloque
`fields do`. Cuando Hobo solo *añade* a la tabla de otro —el lifecycle poniendo
su estado, o `include Hobo::Model` en un modelo de una aplicación que ya
existía— lo que Hobo no declaró es de otro: **añadir sí, borrar no**. Y para
decirlo en voz alta hay `add_fields do ... end`.

Esto vale para toda la historia de adopción, no solo para el usuario: el
`EventPrice` de la app de Rails 8 de Imanol habría recibido una migración
proponiendo vaciar su tabla.

### El subsitio de administración es una carpeta

`rails generate hobo:admin_subsite` escribe el controlador base —para
administradores—, uno por recurso que ya tenga página, y el campo
`administrator` si no estaba. Y poco más, porque **un subsitio ya no se registra
en ningún sitio**: `Hobo.subsites` es «una carpeta bajo `app/controllers` con un
controlador dentro», `hobo_routes` le pone su prefijo y las páginas son las
derivadas de siempre. En Hobo 2 esto escribía además un taglib DRYML por
subsitio, una hoja de estilos, un manifiesto de JavaScript y un tema.

> **Rails 8 resucita la sesión dentro de `require_authentication`**, y los
> controladores de Hobo se saltan ese filtro a propósito (para que una página
> pública siga siendo pública). Es la tercera vez en el día que ese detalle
> muerde en un sitio distinto: la portada, el alta y ahora un `before_action`
> que echaba a la administradora de su propio subsitio.

### Y una lección sobre las pruebas

Las órdenes de generadores en las pruebas van con **la entrada estándar
cerrada**. Una pregunta que nadie contesta es una suite colgada, no una suite que
falla, y las dos se parecen mucho a las nueve de la noche.

## Los temas, de verdad (2026-08-09)

**El problema.** El tema era una pregunta de sí o no porque *solo podía haber
uno*: `<page>` —el documento entero— vivía dentro de `hobo_bootstrap`, y el
catálogo escribía clases de Bootstrap por todas partes (**78 atributos**:
`card card-body bg-body-tertiary`, `table table-striped`, `btn btn-primary`,
`d-flex justify-content-between`…). Quien no quisiera Bootstrap se quedaba sin
página, o con una página llena de nombres que no significan nada sin él.

**Lo que se hizo**, y son tres piezas que se sostienen entre sí:

| Pieza | Qué |
|---|---|
| El catálogo escribe **papeles** | `index-page`, `content-header`, `header-line`, `count`, `collection-table`, `field-list`, `action new`, `record-actions`, `content-9`… Ni una clase de Bootstrap en toda la gema |
| `<page>` sube al catálogo | Con sus ~30 puntos de extensión intactos (el contrato de la pieza 13b) |
| Un tema es **una tabla y una hoja** | `HoboRapid::Theme.wears "bootstrap", "hobo", "action" => "btn"`. Bootstrap son 40 líneas de tabla; `clean` no tiene tabla, porque su css estiliza los papeles |

```sh
hobo new blog                    # clean: 222 lineas de css propio, sin dependencias
hobo new blog --theme=bootstrap  # los mismos papeles, vestidos de Bootstrap 5
hobo new blog --theme=none       # el cuerpo con sus clases, dentro de tu layout
```

Y **por subsitio**, que es como lo preguntaba Hobo 2:
`config.hobo.subsite_themes = { "admin" => :bootstrap }`, o
`generate hobo:admin_subsite --theme=bootstrap`. Para saber cuál toca, el
subsitio viaja con la petición como el usuario y el token, y sale de donde ya
estaba: el espacio de nombres del controlador. El pipeline precompila **todas**
las hojas, porque la elección se hace por petición y precompilar pasa una vez.

> Un fallo que el css nuevo repitió y por eso está anotado en el propio css:
> pintar `button[type=submit]` pinta también **el borrar de cada fila** —que es
> un submit porque un borrado no puede ser un enlace— y salía un botón azul
> enorme al lado de un lápiz diminuto. Es exactamente el error que ya cometió el
> tema de Bootstrap en su día.

**Lo que esto abre:** escribir un tercer tema es escribir un css. Y `--theme=none`
deja de ser «feo sin estilos» para ser html con nombres a los que engancharse,
que es lo que necesita quien mete Hobo en una aplicación con diseño propio.

## Los generadores, uno por uno (2026-08-09/10)

**El criterio lo puso Imanol**, y es mejor que el que yo traía: *si la función
sigue existiendo, el generador debe seguir funcionando*. Que su trabajo lo haga
hoy otro fichero **no** es motivo para borrarlo; que el trabajo haya
desaparecido, sí.

Con ese criterio, de los 24 que había:

| Generador | Estado |
|---|---|
| `setup_wizard` | **Reescrito.** Las preguntas, y hacerlas también en una aplicación que ya existe (decisión 31) |
| `user_model`, `user_mailer`, `user_controller`, `user_resource` | **Reescritos.** El lifecycle del alta, las cartas, las páginas y las rutas. `hobo:signup` es el atajo que usa `hobo new` |
| `front_controller` | **Reescrito**, con su nombre de siempre; `hobo:front_page` hereda |
| `subsite` | **Reescrito**: un subsitio cualquiera, y `--administrators-only` le pone la regla. `hobo:admin_subsite` hereda |
| `controller` | **Reescrito**: el controlador de un modelo que ya existe. `hobo:resource` lo invoca |
| `assets` | **Reinterpretado**: se lleva la hoja del tema a tu aplicación para que la toques |
| `resource`, `model`, `migration` | Ya funcionaban |
| `i18n` | **Borrado**: copiaba 197 líneas por idioma a tu aplicación; hoy la gema es un engine y basta `--locale` |
| `install_plugin`, `install_default_plugins`, `plugin.rb` | **Borrados**: instalar un plugin es poner la gema (decisión 22) |
| `subsite_taglib`, `taglib.rb` | **Borrados**: no hay taglibs de DRYML |
| `activation_email.rb`, `invite_only.rb` | **Borrados como ficheros**: eran mixins de opciones, y hoy son banderas de `hobo:user_resource` |

Con `plugin.rb` y `taglib.rb` caen dos de los últimos usos de `classy_module`;
quedan cuatro, todos en `hobo_support` y `hobo_fields`.

**La prueba que importa** fue esta: `rails new` de toda la vida, la gema en el
`Gemfile`, `generate authentication`, y `rails generate hobo:setup_wizard`. Sale
una aplicación de Hobo que funciona —portada, alta con activación, subsitio,
tema— sin haber pasado por `hobo new`. **Eso es la historia de adopción entera,
en un comando.**

Y cinco fallos por el camino, cuatro de ellos de la misma familia —*adivinar en
vez de mirar*—:

| Qué | Cómo se veía |
|---|---|
| Thor **rellena los valores por defecto**, así que un generador no distingue «no me lo has dicho» de «me lo has dicho igual que el defecto» | El asistente no preguntaba nada |
| El controlador adivinaba su modelo con el **inflector inglés** | `nota` pide `Notum`, `categoria` pide `Categorium`. Ahora prueba también el nombre tal cual, y el generado lo dice en voz alta: `self.model = Nota` |
| El subsitio elegía sus controladores por **una lista de nombres** | El día que la portada se llamó `portada`, le hizo un controlador de administración. Ahora mira si el fichero incluye `Hobo::Controller::Model` |
| El modelo de usuario se llevaba el lifecycle **siempre** | Y ese lifecycle llama a un mailer que, sin activación, nadie ha escrito |
| En un método *endless*, `def x = y if z` aplica el `if` a la **definición** | El generador ni cargaba |

## El asistente, pregunta por pregunta contra el de Hobo 2 (2026-08-10)

Para poder comparar hacía falta una aplicación de Hobo 2 **recién hecha**, no
una de 2017: se montó una con el asistente de 2.2.6 contestado a mano, pregunta
por pregunta. Vive en `~/hobo_apps/hobo2_mi_app` (Ruby 2.5.9, Rails 4.2.11.3),
tiene una biblioteca dentro —autor, categoría, etiqueta, libro, la unión
libro-etiqueta y el préstamo— y está en
`git@github.com:imanolGOMI/hobo2_mi_app.git`. **Es el patrón contra el que se
compara**: lo que se cambie aquí no debería romper nada de lo que allí se ve.

Puestas las dos listas de preguntas una al lado de la otra, faltaban cuatro y
sobraba una:

| Pregunta de Hobo 2 | Qué se hizo |
|---|---|
| La migración inicial: `[s]kip, [g]enerate, [m]igrate` | **Recuperada**, y ver abajo: costó tres intentos dar con *cuándo* preguntarla |
| Los idiomas (lista) y el idioma por defecto | **Recuperadas las dos.** `--locales en es --locale=es`; con más de uno escribe también `config.i18n.available_locales`, sin lo cual `I18n.locale = :es` revienta |
| ¿Repositorio git? | **Recuperada.** `rails new` deja el repo, pero todo lo del asistente viene después: sin esto el primer commit no contiene la aplicación |
| ¿Caja de búsqueda? | **Retirada como pregunta**, porque en Hobo 2 **no lo era**: toda aplicación tenía `/search` y la caja en la barra sin que nadie preguntara. Se pone siempre; `--no-search` la quita |
| Nombre del recurso de usuario | Sigue sin preguntarse: el modelo lo escribe Rails y se llama `User` |
| Tema de jQuery-UI · ¿solo DRYML? · ¿ignorar autogenerados? | Siguen fuera: no hay jQuery-UI, no hay DRYML, no hay autogenerados |

### La pregunta de la migración, en tres intentos

Es el ejemplo más limpio de esta sesión de una cosa: **una pregunta se prueba
lanzándola, no leyéndola**. Los tres intentos salieron de que Imanol la lanzara.

1. **Preguntada con las demás.** Se contestaba y, tres pasos después, el
   generador decía «nada que cambiar»: en una aplicación sin banderas no hay
   nada que migrar, porque las tablas son de Rails y ya estaban aplicadas.
   → Se pasa al final, y solo se pregunta si hay algo. *«Sino no tiene sentido
   que haya pregunta de migración.»*
2. **Ejecutada desde dentro del asistente.** Con `--invite-only` seguía diciendo
   que no faltaba nada, y faltaban tres columnas: los modelos que el asistente
   acaba de escribir están **en disco**, y la clase `User` que hay en memoria se
   cargó antes de que le enseñara el lifecycle. → La migración se escribe en
   **otro proceso**, que es lo que el `hobo new` viejo hacía sin saber por qué.
3. **Fuera de sitio.** Al final, sola, después de todo. Hobo 2 la preguntaba
   **entre la portada y los idiomas**, con las demás, y al contestar hacía el
   trabajo. → Vuelve a su sitio: la respuesta va con las preguntas y el trabajo
   con el trabajo. El orden entero es hoy el de Hobo 2: tema, invitación,
   activación, subsitio, sitio privado, portada, **migración**, idiomas, git.

Y con ello se vio la última: `hobo new` **aplicaba por su cuenta** las dos
migraciones del generador de autenticación de Rails, así que lo que se veía era
una migración ejecutándose sola y detrás una pregunta sobre otra que ya no tenía
nada que hacer. La plantilla ya no toca la base de datos: lo hace el asistente,
después de haber preguntado, diciendo lo que aplica.

Y `hobo:migration` sigue enseñando el `up` y el `down` antes de escribir nada
—eso no había que inventarlo, ya lo hacía—, así que la migración se ve aunque la
respuesta esté dada.

Y una cosa más que sobraba, vista por Imanol al lanzar el generador nuevo: **el
modelo `Story` de ejemplo**. Lo escribía `hobo new` antes de preguntar nada, así
que lo que pasaba por pantalla era un modelo de usuario, una pregunta sobre la
migración y un `Story` apareciendo dentro de ella. Hobo 2 **nunca** creó un
modelo que no le hubieras pedido. Fuera: `hobo new` deja la autenticación, la
portada, el tema y lo que digan las respuestas, y el primer modelo lo escribes
tú con `hobo:resource`. El ejemplo pasó a las pruebas, que son quienes lo
necesitan.

Y **un fallo que solo se ve en una aplicación de verdad**: elegir castellano
dejaba la aplicación rota. Rails trae los formatos de fecha del inglés y de
ninguno más, así que `l(fecha)` en español levanta *translation missing:
es.date.formats.default* y **cualquier listado con una fecha responde 500**. En
Hobo 2 el asistente lo avisa en texto amarillo al terminar y nada más; en el
banco se descubrió al entrar en `/loans`. Ahora `hobo.es.yml` trae ese suelo
—formatos, meses, días—, y si la aplicación tiene `rails-i18n`, gana ella.
Prueba: `test_a_date_can_be_shown_in_spanish`.

> Es otra vez la misma lección, y por eso está aquí: **una aplicación generada
> por Hobo no ve lo que Hobo rompe en el idioma que no es el suyo.** La suite
> corre en inglés.

Lo que queda anotado de esa comparación, sin hacer todavía:

- **El usuario no tiene nombre.** `bin/rails generate authentication` escribe
  `email_address` y `password_digest`, y Hobo enseña un registro por su campo
  `name`: sin él, `User#to_s` devuelve «User 1» en la barra, en los enlaces y en
  los títulos. En Hobo 2 el modelo traía `name :string, :required, :unique`. Se
  arregla en `hobo:user_model` con `add_fields` —la tabla es de Rails y Hobo
  solo le suma (decisión 26)— y el formulario de alta lo hereda.

## Lo siguiente, por orden

**El criterio de aceptación está completo**: la videoteca se construye sin
escribir vistas —salvo tres líneas para decir por dónde se filtra—, funciona, y
se parece a la de Hobo 2. Lo que queda es empaquetar y pulir.

**Los cuatro puntos de esta lista están hechos** (2026-08-09). Lo que queda
anotado, sin orden y sin prisa:

- ~~El `belongs_to` que no enlazaba y la caja de búsqueda~~ **hechos**. Un
  registro es un sitio: `<view>` lo enlaza cuando hay ruta. Y la búsqueda global
  vuelve —`<search-box>` en la barra, `<search-results>` agrupadas por modelo,
  `hobo:search`—: el motor (`Hobo.find_by_search`) era de Hobo 2 y seguía
  entero; faltaban los dos extremos.
- ~~Los generadores viejos~~ **hechos**: cinco reescritos, cinco borrados, y
  el asistente vuelve a existir (ver la sección de arriba).
- **Los ocho plugins de la organización se quedan fuera, y a propósito.** Siguen
  en DRYML, en sus repositorios, y nadie los ha tocado: `hobo_summary`,
  `hobo_mapstraction`, `select_one_or_new_dialog`, `hobo_data_tables`,
  `hobo_simple_color`, `hobo_tokeninput`, `hobo_tree_table`, `hobo_omniauth`,
  `hobo_paperclip`.

  Lo que hay que hacer con cada uno **ya está resuelto y probado**: son gemas
  con un engine, un fichero de tags y sus assets (decisión 22), `hobo_timeago/`
  es el ejemplo terminado, y `rails generate hobo:plugin <nombre>` escribe el
  esqueleto. El trabajo que queda en cada uno es **su DRYML**: convertir sus
  `taglibs/*.dryml` en tags de Ruby.

  Se quedan fuera porque son repositorios de la organización —solo se clonan y
  se leen— y porque portar uno es una decisión de producto (¿hace falta
  autocompletar? ¿pestañas?), no una pieza pendiente de esta migración.
- ~~Los cuatro usos de `classy_module`~~ **hecho**: `HoboFields::Model` es un
  `Concern`, los mixins Thor son el generador que los usaba, `CommonTasks` era
  de Hobo 2 y no lo requería nadie, y `classy_module` ya no existe. Con él
  apareció que **`hobo:model` llevaba roto desde Ruby 3**: `ERB.new(src, nil,
  "-")` — el nivel de seguridad no existe y el trim mode es una keyword.
- El actualizador de plantillas de aplicaciones existentes (decisión 6) sigue
  siendo solo el parser de DRYML conservado a propósito.

### ~~1. La fusión en una sola gema~~ — **hecha** (2026-08-08)

Cinco gemas y un tema son **una gema `hobo`**. Un `Gemfile` de aplicación pasa
de seis líneas a una, y `hobo/lib/` tiene dentro `hobo_support`, `hobo_fields`,
`dryml`, `rapid`, `hobo_rapid` y `hobo_bootstrap`.

**Los espacios de nombres se quedan.** `Hobo`, `HoboFields`, `Rapid`,
`HoboRapid`, `HoboBootstrap` siguen diciendo de qué es cada cosa; lo que se
fusiona es el **empaquetado**, no el diseño. Y como todo cuelga de un solo
`lib/`, **ni un `require` cambió**.

Fuera: cinco gemspec, cinco Gemfile, cinco Rakefile, cinco VERSION y cinco
`test_helper` (el precio que la decisión 12 aceptó «hasta la capa 7»). El
`Rakefile` de la raíz tenía tres listas —`PORTED_GEMS`, `PARTIAL_GEMS`,
`PENDING_GEMS`— que sirvieron para que ninguna capa diera por buena una gema sin
mirarla; ya no hacen falta.

**A `legacy/` va lo que es especificación y no código**: los 87 escenarios de
cucumber de DRYML, los `.dryml` originales de RAPID y del tema, el
`dryml.rdoctest` y los CHANGES de cada gema. Se leen, no se ejecutan, y no
tienen por qué viajar dentro de la gema.

### Los cuatro fallos que solo aparecen al juntarlo todo

Ninguno se ve mientras cada gema tiene su proceso. Todos son la misma forma:
**algo global que estaba bien mientras estuviera solo.**

| Qué | Era |
|---|---|
| La aplicación no arrancaba: «Invalid route name, already in use: `dryml_support`» | **Tres engines con la misma raíz.** Un engine de Rails dibuja `config/routes.rb` relativo a su raíz, y al fundirse las gemas `Hobo::Engine`, `HoboRapid::Engine` y `HoboBootstrap::Engine` pasaron a compartirla. Ahora hay **un engine**, con los initializers de los otros dos dentro |
| La barra dejó de decir quién eras — en la prueba de otra suite | El port de `<form>` de la capa 3 hacía `Rapid::Tag.include` de un módulo con `def current_user = nil`. Eso alcanza a **todos** los tags, no solo al port |
| `<view>`, `<input>`, `<page>`, `<search-filter>` y `<error-messages>` pintaban otra cosa | El registro de tags es **global** —un tag se busca por nombre y una aplicación tiene un catálogo— y los suplentes de la capa 3 se llaman igual que tags que el catálogo ya tiene de verdad. Ganaba el que cargara el último. Los suplentes pasan a `spike_*`, y `<error-messages>` se borra: el catálogo tiene el suyo |
| El botón «Filtrar» de reserva no se escondía | El controlador de Stimulus estaba en el `<select>`, y su alcance es su propio elemento: el botón es hermano, no hijo. Va en el `<form>` |

> El tercero es el más instructivo: **un suplente que sobrevive a aquello para
> lo que suplía deja de ser un suplente y pasa a ser un impostor.**

### ~~1. El contrato de plugin (pieza 17)~~ — **hecho** (2026-08-09)

**Un plugin es un engine de Rails que define tags y trae assets. Instalarlo es
ponerlo en el `Gemfile`.** Eso es todo el contrato (decisión 22).

En Hobo 2, `rails generate hobo:install_plugin <nombre>` tocaba **cuatro** sitios
y una vez por subsitio: el `Gemfile`, un `//= require` en el JavaScript, un
`*= require` en la hoja de estilos y un `<include gem="..."/>` en
`app/views/taglibs/<subsitio>_site.dryml`. Tres de los cuatro existían porque un
tag de DRYML vivía en un fichero que alguien tenía que nombrar. Con los tags en
Ruby, **definir un tag es registrarlo**, y los ficheros de la gema se ejecutan
cuando Bundler la requiere: se quedan sin nada que hacer.

**Lo que se escribió**

| Qué | Dónde |
|---|---|
| El plugin de verdad, escrito para probar el contrato | `hobo_timeago/` — engine, `lib/hobo_timeago/tags.rb`, `app/assets`, `app/javascript`, gemspec y suite propia |
| Procedencia en el registro: cada definición apunta al fichero que la hizo | `hobo/lib/rapid.rb` (`Rapid::Definition`, `Rapid.definitions`) |
| La lectura de eso: quién define cada tag y qué está tapado | `hobo/lib/hobo/tag_index.rb` |
| `bin/rails hobo:tags` | `hobo/lib/tasks/hobo_tags.rake` |
| La prueba del «y nada más» | `hobo/test/integration/plugin_contract_test.rb` |

**Cómo se prueba un «y nada más».** No mirando lo que pasa, sino lo que deja de
pasar: el banco `/tmp/hobo_testapp` lleva el plugin en un grupo de Bundler que
Rails no requiere por defecto, y cada prueba arranca **la misma** aplicación dos
veces —`RAILS_GROUPS=hobo_plugin bin/rails runner …` y sin él— y compara. Con la
gema, las fechas salen en `<time>…3 days ago</time>`; sin ella, `2026-08-01`. Y
ningún fichero de la aplicación nombra al plugin, lo cual también se comprueba.

**Lo que se decidió no portar**, porque Imanol no lo ha usado nunca: la
activación por subsitio (para un diseño distinto, CSS) y el generador de
instalación.

**Lo que salió de aquí y no estaba previsto:** el registro de tags es global, así
que redefinir es invisible —gana el último que carga y nadie avisa—. Eso es lo
que dejó cinco tags de un banco de pruebas pintando las páginas de verdad durante
la fusión. `bin/rails hobo:tags` marca `shadowed` toda definición que sigue en el
registro y ya no pinta nada, y `Rapid.extend_tag` sigue siendo la forma honrada
de cambiar el tag de otro: dos gemas pueden extender el mismo tag y las dos se
ejecutan; dos que lo definan, no.

```
view_content                                hobo/lib/hobo_rapid/tags/views.rb
  for Date                        shadowed  hobo/lib/hobo_rapid/tags/views.rb
  for Date                                  hobo_timeago/lib/hobo_timeago/tags.rb

33 tags, 47 definitions, 2 shadowed -- hobo, hobo_timeago
```

Un tropiezo que vale la pena recordar: un engine de Rails ya carga
`lib/tasks/**/*.rake` él solo. Decirlo otra vez con `rake_tasks { load … }`
cargaba el fichero dos veces, y rake **suma** el segundo cuerpo al primero en vez
de reemplazarlo, así que la tarea imprimía el catálogo entero dos veces.

### El círculo: instalar la gema en una app ajena, y portar una vieja (2026-08-09)

Antes de borrar los generadores viejos, cerrar el círculo. Y menos mal.

#### 1. Una app Rails 8 ajena, con la gema añadida y nada más

Sujeto: una copia de `rails8_bootstrap` (Devise, Slim, Bootstrap propio,
ActiveStorage, Pagy, 9 modelos). **Todas sus páginas se caían**, el login
incluido, con solo poner la gema en el `Gemfile`. Tres monkeypatches de 2008
sobre clases de Rails y de Ruby que sobrevivieron a la reescritura:

| Qué | Por qué rompía |
|---|---|
| `String#safe_constantize` | El de ActiveSupport responde `nil` cuando la constante no está; el de Hobo relanzaba el `NameError` salvo que el nombre que faltara fuera **exactamente** la cadena entera. ActiveRecord pregunta justo por candidatos que espera que no existan (`Dj::ActiveStorage::Attachment` antes que `ActiveStorage::Attachment`), así que reventaba toda página con un adjunto, una asociación polimórfica o STI |
| `String#remove` | El de ActiveSupport quita **todas** las apariciones; el de Hobo, la primera. Mismo nombre, mismos argumentos, otra respuesta, ningún error |
| `ActionView#translate` | Reabierto con la firma de 2008, pasando el hash a `I18n.translate` por posición: hoy es `ArgumentError`, así que **`t()` moría en cualquier vista de la aplicación**. Estaba ahí por el tag `<t>` de DRYML |
| `current_user` | Hobo lo define en un helper que aterriza en todos los controladores y en todas las vistas, y se llevaba por delante el de Devise: el layout hacía `current_user.email` sobre un `Hobo::Model::Guest` |

Los dos primeros y el tercero: **borrados**. El cuarto cede con
`return super if defined?(super)`.

> **Una aplicación generada por Hobo no puede ver lo que Hobo le rompe a una
> aplicación que no generó.** Es la lección de la capa 6 un piso más arriba: la
> app de `hobo new` no llama a `t()` en una vista, no tiene adjuntos y no trae
> otra autenticación, así que nada de esto podía fallar en casa.

Después del arreglo, las cinco pantallas de la app ajena se ven **igual con la
gema que sin ella** (3010 vs 3011), y un modelo suyo que no tenía CRUD
—`EventPrice`— pasó a tener páginas con **dos líneas en el modelo, tres en un
controlador nuevo y `hobo_routes`**. Y salieron en español solas, porque la
aplicación tiene `es` de idioma.

Lo que **no** encaja todavía: la página derivada se pinta con el tema de Hobo
(documento entero, su propia barra), no con el layout de la aplicación. Para
adoptar Hobo en una app que ya tiene diseño hace falta poder decir «dame el
cuerpo, el layout lo pongo yo». El mecanismo ya está a medias —el controlador
mira si lo pintado empieza por `<!DOCTYPE` y solo entonces se salta el layout—:
falta la manera de decirlo.

#### 2. Agility, de Hobo 2 a Hobo 3

`agility_bootstrap` es la app de pruebas clásica: 13 modelos, 12 controladores,
~20 vistas DRYML escritas a mano y **permisos de verdad por usuario**. Se portó
el dominio (Project, Story, Task, StoryStatus, ProjectMembership,
TaskAssignment) y **ni una vista**.

Lo que costó, por línea de modelo:

| Hobo 2 | Hobo 3 |
|---|---|
| `hobo_model` | igual (sigue existiendo) |
| `fields do … end` | igual |
| `:accessible => true`, `children`, `belongs_to … :creator => true` | igual |
| `attr_accessible` | fuera (`protected_attributes` murió en Rails 5) |
| `has_many …, :scope => :contributor` | lambda: `-> { where(:role => "contributor") }` |
| `has_attached_file` (Paperclip) | fuera; sería ActiveStorage |
| `hobo_user_model` con su lifecycle de alta | el `User` de Rails 8 + tres líneas (decisión 15) |
| `errors[:base] << "…"` | `errors.add(:base, "…")` |

Y dos cosas rotas que **solo se ven con una aplicación así**:

- **El tipo `:markdown` no existía.** Sus dos ficheros llevaban comentados desde
  una nota de Rails 4 que decía «se cargarán más tarde», y más tarde no llegó
  nunca. Estaban comentados porque el motor se elegía **al cargar** el fichero
  (`defined?(RDiscount)`), y si Bundler no lo había requerido todavía la
  respuesta era `nil`. Ahora se busca al usarlo.
- **Un permiso denegado salía como 500.** El catálogo lanza su propio
  `HoboRapid::PermissionDenied` —`<view>` pregunta `viewable_by?` antes de
  pintar— y el controlador solo rescataba el de Hobo. Las aplicaciones que
  genera Hobo dejan verlo todo a todo el mundo; hacía falta una con permisos.
  Ahora un visitante recibe 403, que es lo que Agility dice.

Resultado: `/projects`, `/stories`, `/tasks` y `/story_statuses` funcionan
derivadas, con los permisos de Agility mandando. Lo que **no** se portó, y es la
mitad que falta: las ~20 vistas DRYML escritas a mano. Eso es el actualizador
(decisión 6), y ahora hay dos aplicaciones vivas para escribirlo contra ellas.

#### 3. El alta de usuario, que estaba a medias

Lo vio Imanol comparando las dos pantallas: **en Hobo 2 el usuario se crea en
dos sitios** —el primer administrador en la portada, y `/users/signup` para los
demás, con su enlace en la barra— y en Hobo 3 solo estaba el primero.

La causa es la decisión 15 leída de más: Rails 8 se queda con la autenticación,
y su generador escribe **sesión y recuperación de contraseña, no registro**. Así
que una aplicación generada tenía exactamente un usuario, para siempre. El
comentario del propio generador decía «anybody else signs up normally», y no
había *normally*.

- `<signup-form>` es el formulario, y `<first-user-form>` es ese mismo con las
  palabras de quien va a quedarse la aplicación.
- `rails generate hobo:signup` escribe el controlador y sus dos rutas, y
  `hobo new` lo llama. **Sin rutas no hay alta**: quitarlas es la manera de no
  tenerla, que es más fácil de comprobar que apagar una bandera.
- La barra ofrece «Sign up» a quien no ha entrado, si la ruta existe.

Y al probarlo de verdad salieron dos cosas más, las dos de la misma familia
—Rails 8 hace lo suyo en sitios que no se ven—:

| Qué | Por qué |
|---|---|
| Creabas el usuario y te quedabas **fuera** | `start_new_session_for` es **privado** en el concern de Rails 8, y el guardián preguntaba `respond_to?` sin `true`. Devolvía false y la línea se saltaba, en silencio |
| La barra decía «Log in» a quien acababa de registrarse | `allow_unauthenticated_access` es un `skip_before_action :require_authentication`, y **Rails resucita la sesión dentro de ese filtro**. La portada y el alta lo usan, así que nadie miraba la galleta. El puente le pregunta ahora a Rails cuando el controlador no tiene `current_user` |

La prueba de los cinco primeros minutos (`hobo_new_test.rb`) **levanta un
servidor de verdad**. La primera versión hacía las peticiones en proceso, con su
propio tarro de galletas, y daba por rotas dos cosas que la aplicación en marcha
hacía bien: **una prueba que se equivoca en esa dirección es peor que no
tenerla**.

#### 4. Un invitado podía crear registros (2026-08-09)

Lo vio Imanol mirando la app generada: de invitado no salen las acciones, pero
**sí sale el botón «New»**, y al pulsarlo un formulario sin campos.

Lo primero que se hizo fue el A/B que él propuso: generar una aplicación con la
versión de **ayer** (`0a9880ab`) y otra con la de hoy, sembrar lo mismo y mirar
las tres caras —dueño, otro usuario, invitado—. Salen idénticas. **No era de
hoy**, y saberlo antes de tocar nada ahorró perseguir un fantasma.

| quién | acciones | botón «New» | campos del formulario |
|---|---:|---:|---:|
| jefe | 2 | 1 | 4 |
| otra | 2 | 1 | 4 |
| invitado | 0 | **1** | **1** |

Que jefe y otra tengan acciones es correcto: el `Story` generado declara
`update_permitted? = acting_user.present?`, o sea *cualquiera que haya entrado*.

Debajo había algo peor: **un extraño podía POSTear un registro y se guardaba**.

- **La oferta es una promesa.** El índice pintaba «New X» en cuanto existía la
  ruta, sin preguntar. Ahora pregunta al modelo (`creatable_here?`).
- **Los permisos se preguntaban por otra persona.** Los modelos generados dicen
  `acting_user.present?`, y la respuesta de Hobo para nadie es un
  `Hobo::Model::Guest` —que **es** present—. Los tags normalizan el invitado a
  nil (decisión 20) y el modelo no: de ahí que la página escondiera el enlace de
  editar a alguien que sí podía crear.

  El arreglo obvio —que `current_user` devuelva nil— es **el equivocado**, y la
  suite lo dijo en el primer intento: sin `acting_user`, Hobo entiende que no
  hay nadie actuando (una consola, un `seeds.rb`) y **se salta los permisos**.
  Ahí está el valor de ese objeto: distingue *nadie mirando* de *alguien que no
  es nadie*. Así que sigue siendo un objeto, y ahora es **blank**: `present?`
  dice que no.

> Dos capas con dos ideas de quién es nadie, y ninguna de las dos equivocada por
> separado.

### De paso: `hobo new` dejaba una aplicación rota (2026-08-09)

Al regenerar el banco de conformidad, `/stories` respondía **500: «no such table:
stories»**. La plantilla hace, por este orden, `hobo:resource`, `generate
authentication` y `hobo:migration -n -m`; el generador de autenticación de Rails
deja dos migraciones sin correr y **`hobo:migration` se niega a hacer nada
mientras haya migraciones pendientes**: imprimía «You have 2 pending migrations»
y paraba. La llamada estaba envuelta en `rescue nil`, así que `hobo new` decía
«Listo» y la primera página de la aplicación era un 500.

Arreglado con un `rails_command "db:migrate"` antes, y fuera el `rescue nil`.

Y esto es otra vez lo mismo de siempre: la prueba que lo habría visto existe
—`test/integration/hobo_new_test.rb`— y **se salta por defecto** porque tarda
dos minutos. Al correrla se cayó por tres cosas a la vez, todas de meses
distintos: las migraciones, el `Host` vacío de `Rack::MockRequest` (403 de
`ActionDispatch::HostAuthorization`, que parece un permiso denegado y no lo es) y
que pedía `/`, que desde que existe `hobo:front_page` ya no es el índice del
modelo. **Una prueba lenta que no se corre no es una prueba, es una intención.**

### ~~1. Las cadenas de interfaz a inglés, y detrás i18n~~ — **hecho** (2026-08-09)

Las dos cosas de una vez, porque traducir después de haber concatenado no se
puede: **no hay cadenas, hay claves con su inglés escrito donde se usan**.

```ruby
text t(:"index.new_link", "New %{name}", :name => singular.downcase)
```

- `hobo/lib/hobo_rapid/translation.rb` — `t` dentro de un tag, y
  `HoboRapid.translate` fuera. Sin I18n cargado (las pruebas de pieza cargan el
  runtime y nada más) devuelve el `:default` interpolado.
- **No hay `hobo.en.yml`.** El inglés es el `:default`, en el sitio donde se
  pinta. Dos listas de las mismas cadenas se separan, y la que nadie lee es la
  que está mal. Añadir un idioma es escribir **un** fichero.
- `hobo/config/locales/hobo.es.yml` es ese fichero, y el engine lo lleva. Una
  aplicación en español es una línea: `config.i18n.default_locale = :es`.
- La interpolación es el motivo de todo esto: «New %{name}» y «Nuevo %{name}»
  no ponen el sustantivo en el mismo sitio, y `"New " + nombre` no llega ahí. El
  género sí se queda sin resolver («Nuevo película»): eso lo arregla la
  aplicación pisando la clave.
- De paso, a inglés también: la salida de `hobo new` y de `hobo:resource`, los
  mensajes de las excepciones del runtime (`Rapid::Tag`, `PermissionDenied`) y
  los fallos del contrato de params. Una gema inglesa que lanza excepciones en
  español no es una gema inglesa.
- `hobo/test/hobo_rapid/translation_test.rb` (el mecanismo) y
  `hobo/test/integration/i18n_test.rb` (que **el engine lleva el fichero**: la
  prueba unitaria carga el yml por ruta y pasaría igual si la gema no lo
  entregara a nadie — la misma forma de agujero que el tema construido y no
  conectado).

Comprobado en la aplicación viva: en inglés dice «New story»; con una línea en
un initializer, «Nuevo story».

## Cómo mirar la aplicación con el navegador

Hay Firefox y `geckodriver`. El guion de auditoría que se usó:

```ruby
# inicia sesion, recorre las pantallas y guarda capturas
Capybara.app_host = "http://localhost:3007"
page.visit("/session/new"); page.fill_in("email_address", ...); page.click_button("Sign in")
page.visit("/stories"); page.save_screenshot("...png")
```

**Y hay que mirarlas**: los cuatro fallos más gordos de la sesión se vieron en una
captura, no en una prueba.

## Reglas de trabajo

- **Nunca hacer push.** Ni a este repo ni a ninguno. Solo commits locales.
- **Commits sin mencionar a Claude**, ni `Co-Authored-By` ni referencias.
- **Código en inglés** (identificadores y comentarios). **Commits y documentación
  en español.**
- Parar al final de cada capa: probar, enseñar el resultado y preguntar.
