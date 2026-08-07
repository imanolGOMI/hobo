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
| 17 | Contrato de plugin | Se queda | Engine + Railtie + taglibs + assets. 8 repos lo usan |

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
| `[~]` | **4** | `hobo`: permisos, lifecycles, view hints, auto-actions, router | 4, 5, 6, 7, 11, 12, 14 |
| `[ ]` | **5** | `hobo_rapid` + motor de derivación | 9, 10 |
| `[ ]` | **6** | Separar `hobo_bootstrap` en tags estructurales (→ RAPID) y tema | 13a, 13b |
| `[ ]` | **7** | `hobo new`, generadores, contrato de plugin | 17 |

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

### Lo que queda de la pieza 11

Las 4 `alias_method_chain` de `user_base.rb`, `find_for.rb` y
`relation_with_origin.rb`, y repasar el resto de acciones (`hobo_create`,
`hobo_update`, `hobo_destroy`, las de lifecycle) con el mismo par de niveles:
prueba sin aplicación donde se pueda, y petición de verdad donde no.

### Lo que queda de la capa 4

Por orden, y con lo que ya se sabe:

1. **Pieza 11, segunda mitad**: las acciones, con la decisión de cómo probarlas.
2. **Pieza 12, router**, con el agravante de la carga ansiosa por `descendants`.
3. **Pieza 14, subsites**, que es transversal y va la última.

Quedan **10 `alias_method_chain`** —eran 35 al empezar la capa—, repartidos así,
y cada uno cae con su pieza:

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

## Reglas de trabajo

- **Nunca hacer push.** Ni a este repo ni a ninguno. Solo commits locales.
- **Commits sin mencionar a Claude**, ni `Co-Authored-By` ni referencias.
- **Código en inglés** (identificadores y comentarios). **Commits y documentación
  en español.**
- Parar al final de cada capa: probar, enseñar el resultado y preguntar.
