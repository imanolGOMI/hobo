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

**La tensión de fondo, dicha en voz alta:** Rails apuesta por *migraciones como
historia* —dan auditoría y permiten migrar **datos**— y Hobo por *modelo como
verdad única*, que da un solo sitio donde mirar pero **no puede expresar una
transformación de datos**.

**Decisión (2026-08-07):** se queda. Esta fase es **solo para aplicaciones
nuevas**, así que la limitación de las migraciones de datos no bloquea. Cuando
alguien la necesite, se verá entonces.

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

**El spike:** portar tres tags representativos a cada opción candidata —
`<view>` (polimórfico), `<page>` (30 params) y uno con `<extend>`— y comparar.

---

## El plan por capas

Estado: `[ ]` pendiente · `[~]` en curso · `[x]` hecho

| | Capa | Qué | Piezas |
|---|---|---|---|
| `[x]` | **0** | **Banco de pruebas**: andamiaje minitest y corredor de la raíz | — |
| `[x]` | **1** | `hobo_support`: quitar ~230 líneas de azúcar, codemod de 113 sitios, `classy_module` → `Concern` | 16 |
| `[x]` | **2** | `hobo_fields`: `fields do`, tipos ricos, migraciones **+ batería que ejecute `up` y `down`** | 1, 2, 3 |
| `[ ]` | **3** | **El remix de DRYML** (empieza por el spike) | 8 |
| `[ ]` | **4** | `hobo`: permisos, lifecycles, view hints, auto-actions, router | 4, 5, 7, 11, 12, 14 |
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
```

---

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Lo que salió mal la primera vez | `HALLAZGOS.md` |
| El código del primer intento | rama `hobo_2027`, tag `intento-1-update` |
| El tema Bootstrap (vendorizado) | `hobo_bootstrap/`, con `ORIGEN.md` |
| Los widgets jQuery del tema | `hobo_bootstrap_ui/`, con `ORIGEN.md` |
| Contrato de `<page>` (30 params) | `hobo_bootstrap/taglibs/page.dryml` |
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

## Reglas de trabajo

- **Nunca hacer push.** Ni a este repo ni a ninguno. Solo commits locales.
- **Commits sin mencionar a Claude**, ni `Co-Authored-By` ni referencias.
- **Código en inglés** (identificadores y comentarios). **Commits y documentación
  en español.**
- Parar al final de cada capa: probar, enseñar el resultado y preguntar.
