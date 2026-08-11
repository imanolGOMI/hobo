# Plan de trabajo — Hobo 2027

> **Si retomas la sesión, lee este fichero y no reconstruyas nada de la
> conversación.** Aquí está el estado, las decisiones vigentes y lo que queda.
> Es corto a propósito.
>
> - **`DIARIO.md`** — cómo se llegó hasta aquí, por fechas. Se consulta cuando
>   alguien pregunta «¿por qué está esto así?», no se lee entero.
> - **`HALLAZGOS.md`** — lo que salió mal en el primer intento y no hay que
>   repetir.

---

## Dónde estamos

| | |
|---|---|
| Rama | `hobo_2027_v2` |
| Punto de partida | `master` = Hobo 2.2.6 (Rails 4.2), **intacto** |
| Objetivo | Rails 8.1 / Ruby 3.4 |
| Primer intento | rama `hobo_2027`, tag **`intento-1-update`**. Descartado, se conserva |
| Método | De abajo arriba, por capas. **Parar, probar y preguntar en cada capa** |

**Las gemas** (revisado 2026-08-11). Son cinco, cada una en su directorio de
`hobo_oficial_2027/`:

| | |
|---|---|
| `hobo/` | La gema. Fusión de `hobo_support`, `hobo_fields`, `dryml`, `hobo` y `hobo_rapid` |
| `hobo_bootstrap/` | El tema Bootstrap. El tema `clean` va dentro de `hobo` |
| `hobo_jquery/` | El comportamiento con jQuery, para quien no quiera Stimulus |
| `hobo_jquery_ui/` | Los tags de jQuery UI |
| `hobo_dryml/` | El lenguaje DRYML, para aplicaciones que vienen de Hobo 2 |

**El estado, en una línea cada uno:**

- **Aplicación nueva**: completa. `hobo new` deja una app Rails 8 que arranca,
  con su modelo, su CRUD, su login y sus páginas derivadas. 649 pruebas.
- **Retocar una página derivada**: hecho, en ERB y en Slim -- los siete verbos y
  el taglib de la aplicación.
- **Actualizar una aplicación de Hobo 2**: `hobo update` la trae entera y
  arranca. Amenti (32 modelos, 88 plantillas, 52 gemas) responde en el 3006.
- **DRYML**: lector y compilador hechos y probados contra las 88 plantillas de
  amenti. Falta el mobiliario del catálogo para que las páginas se pinten.

---

---

## Decisiones tomadas

Revisadas una a una contra el código el **2026-08-11**. Las que ya no son
verdad están tachadas con lo que las sustituyó: el registro de por qué se
decidieron así en su momento sigue más abajo, en el diario.

**Vigentes**

1. **Empezar de cero** sobre `master`, no continuar el primer intento.
2. **De abajo arriba, por capas**, con parada, prueba y preguntas al final de
   cada una.
9. **Las pruebas, todas en minitest.** Se acabó `rubydoctest` (abandonada en
   2014) e `irt` (2015).
10. **No se vendorizan repos de la organización.** Se clonan y se leen.
12. **La fusión de las gemas se hizo al final**, en la capa 7, para que el diff
    de cada capa fuera legible.
13. **El tema por defecto va dentro de la gema.** Una aplicación recién creada
    se ve bien sin instalar nada. Los alternativos son gemas aparte.
14. **El JavaScript es Stimulus y Turbo**, no jQuery. `hobo_jquery` sigue
    existiendo como gema para quien lo quiera.
15. **El protocolo de «partes» son Turbo Frames.** No había opción de dejarlo:
    `refresh_part` vivía en el compilador viejo de DRYML.

**Cambiadas, y por qué**

3. ~~Primera fase: solo aplicación nueva. Actualizar aplicaciones viejas es otra
   fase y otra rama.~~ → **La actualización se hace en esta misma rama**
   (2026-08-11). El criterio de aceptación de la aplicación nueva está completo,
   así que la fase siguiente empezó, y separarla en otra rama solo habría
   duplicado el trabajo de mantener las dos.
4. ~~La compatibilidad va por ramas, no por condicionales.~~ → **Va por gemas.**
   `hobo_dryml`, `hobo_jquery` y `hobo_bootstrap` son gemas que se instalan o
   no. Es lo mismo que perseguía la decisión original -- que lo viejo no
   ensucie lo nuevo con condicionales -- por un camino que no obliga a mantener
   dos ramas.
5. ~~DRYML: se conserva la semántica, no el lenguaje.~~ → **El lenguaje también**
   (decidido por Imanol el 2026-08-11). Razón: una aplicación como amenti tiene
   88 plantillas en DRYML, y sin el lenguaje **no se puede ver ni una pantalla**
   -- todo lleva a `/`, que es DRYML. Vive en la gema `hobo_dryml`, y compila
   contra Rapid: no hay un segundo runtime.
6. ~~El parser de DRYML no se tira: se reutiliza como front-end del
   actualizador.~~ → **Se tiró y se escribió otro** (2026-08-11). El viejo
   heredaba de `REXML::Parsers::BaseParser` y usaba sus constantes internas, que
   no son API de nadie y cambian entre versiones de Ruby -- se rompió dos veces
   en una semana. El nuevo son ~270 líneas, no depende de REXML, lleva la línea
   de cada nodo y lee las 88 plantillas de amenti. `hobo/lib/dryml/` sigue en el
   árbol y **ya no lo usa nadie**: es lo siguiente que hay que borrar.
7. ~~`will_paginate` no se toca.~~ → **Hubo que parchearlo** (2026-08-11).
   `hobo_will_paginate` usa el `try` sin argumentos de Hobo 1, que en el `try`
   de Rails acaba en `respond_to?(nil)` y revienta: cualquier `to_a` de una
   lista paginada tiraba la página. El parche está en
   `hobo/lib/hobo/extensions/will_paginate.rb`.
8. ~~Se conserva el pipeline de assets que la app tenga. Propshaft fue un
   error.~~ → **Las aplicaciones nuevas usan Propshaft**, que es lo que trae
   Rails 8 y lo que escribe `hobo new`. La decisión original era sobre no
   romperle el pipeline a una aplicación existente, y para eso sigue valiendo;
   como está escrita dice otra cosa.
11. ~~El resultado final es UNA SOLA GEMA.~~ → **Son cinco**: `hobo`, y
    `hobo_bootstrap`, `hobo_jquery`, `hobo_jquery_ui` y `hobo_dryml` aparte. La
    fusión de las cinco gemas *originales* (`hobo_support`, `hobo_fields`,
    `dryml`, `hobo`, `hobo_rapid`) sí se hizo, y esa parte de la decisión se
    cumplió. Lo que salió después fue lo opcional: un tema, un comportamiento,
    un lenguaje. Quien no lo quiere no lo instala.

---

## Reglas absolutas sobre `git push`

- **Nunca se hace push. Nunca, a ningún sitio.** El push lo hace Imanol a mano.
- **Jamás al repositorio de la organización `Hobo/`.** No hay permiso y no lo
  habrá. Los repos de la organización solo se **clonan y leen**.
- El único destino que existiría, y aun así lo hace él, es el repositorio
  personal de Imanol.

---

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
| 8 | DRYML | **Semántica y lenguaje** ✎ | Revisado 2026-08-11: el lenguaje vuelve, en la gema `hobo_dryml`, compilado contra Rapid |
| 9 | RAPID (catálogo) | **A medias** ⚠ | Revisado 2026-08-11: dice 112 → ~97 y hay **36**. Ver «El catálogo, contado» |
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

### El catálogo, contado (2026-08-11)

La decisión 9 decía que el catálogo se reducía poco: fuera unos 15 envoltorios
triviales de 112. **Hay 36.** Nadie eligió esos 36: el catálogo no se portó, se
reconstruyó de dentro afuera con lo que el motor de derivación necesitaba para
pintar `index_page`, `show_page` y `form_page`. `field-list` nunca apareció
porque la página derivada pinta su `<dl>` a mano, ahí mismo.

Dónde está cada cosa: los 112 de Hobo 2 en
`hobo_oficial/gemas/hobo/hobo_rapid/taglibs/`, los 36 de ahora en
`hobo/lib/hobo_rapid/tags/*.rb` (1.659 líneas, siete ficheros).

De los **94 sin portar**:

| | |
|---:|---|
| 23 | envoltorios de HTML -- `<a>`, `<br>`, `<img>`, `<table>`, `<section>`. En DRYML hacían falta porque para colgarle un `param` o un `merge-attrs` a un elemento tenía que ser *un tag*; en Ruby se escribe `tag("a", …)`. **No hay que portarlos**, y son justo los ~15 que la decisión 9 daba por fuera |
| 11 | caché y editores en vivo -- fuera, decidido el 2026-08-07 |
| 9 | i18n (`model-name-human`, `human-collection-name`…) -- lo hace `t` de Rails |
| 8 | páginas de auth -- las trae Rails 8 |
| **43** | **mobiliario de página que falta de verdad** |

Y de esos 43, amenti usa **13**: `field-list` (65 usos), `form` (25), `submit`
(16), `or-cancel` (14), `formlet` (13), `collection`, `page-nav`,
`transition-button`, `select-input`, `new-page`, `delete-button`, `edit-page`,
`select-menu`. Los otros 30 (`gravatar`, `search-card`, `sti-type-input`,
`remote-method-button`…) no los usa nadie y varios son de la época del AJAX de
Hobo 2.

**Lo que esto significa, y es lo que hay que decidir:** no es un problema de la
migración. Una aplicación nueva escrita en ERB tampoco puede escribir hoy una
lista de campos ni un formulario suelto. El catálogo de Hobo 3 está a medias, y
hasta dónde tiene que llegar es una decisión de producto pendiente.

**Y una conclusión del spike que quedó escrita y es falsa:** en «DECISIÓN
TOMADA: opción A» se lee que el runtime obliga a que «los tags devuelvan
cadenas, no escriban en un buffer compartido». Rapid escribe en un buffer
compartido (`Rapid::Context.capture`) y el problema del `param` perdido se
resolvió de otra forma. `<table-plus>`, que fue el spike, **no está en el
catálogo**.

---

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

---

## Lo siguiente, por orden

**El criterio de aceptación está completo**: la videoteca se construye sin
escribir vistas —salvo tres líneas para decir por dónde se filtra—, funciona, y
se parece a la de Hobo 2. Lo que queda es empaquetar y pulir.

**El orden que se acordó el 2026-08-10, y en qué quedó (revisado 2026-08-11):**

1. ~~El puente de plantillas~~ **hecho** (2026-08-11). Los siete verbos en
   `hobo_rapid/params.rb` y el taglib en `app/views/taglibs/application.html.erb`.
2. ~~El actualizador de plantillas DRYML~~ → **se convirtió en dos cosas
   distintas**: `hobo update`, que trae una aplicación entera de Hobo 2 a esta
   (Gemfile, config, rutas, modelos, base de datos), y la gema `hobo_dryml`, que
   hace innecesario convertir las plantillas.
3. ~~Decidir sobre el lenguaje~~ **decidido: sí** (2026-08-11).

**Lo que queda, por orden:**

1. **Que amenti se vea en el 3006.** Falta el mobiliario de página del catálogo
   -- 13 tags que amenti usa, ver «El catálogo, contado» -- y decidir hasta
   dónde llega el catálogo, que es una decisión de producto y no de migración.
2. **Repasar los dos apaños de los verbos en ERB/Slim**, que Imanol pidió
   debatir aparte: adivinar «¿la vista escribió marcado?» mirando el texto que
   sale, y la vista viva del taglib, que no tiene petición. Ninguno de los dos
   afecta a DRYML, donde la intención se dice explícitamente.
3. **Borrar `hobo/lib/dryml/`**, que ya no lo usa nadie (3.585 líneas).
4. **Revisar DRYML viejo contra DRYML nuevo**, que Imanol pidió: qué se
   conserva, qué se quita y qué se mejora, con las dos gramáticas delante.

**Los cuatro puntos de la lista anterior están hechos** (2026-08-09). Lo que
queda anotado, sin orden y sin prisa:

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
  esqueleto.

  **Y desde el 2026-08-11 puede que no haya que convertir su DRYML**: si el
  plugin depende de `hobo_dryml`, sus `taglibs/*.dryml` se ejecutan tal cual.
  Está sin comprobar contra ninguno de los ocho, y comprobarlo es barato --
  ninguno es tan grande como amenti.

  Se quedan fuera porque son repositorios de la organización —solo se clonan y
  se leen— y porque portar uno es una decisión de producto (¿hace falta
  autocompletar? ¿pestañas?), no una pieza pendiente de esta migración.
- ~~Los cuatro usos de `classy_module`~~ **hecho**: `HoboFields::Model` es un
  `Concern`, los mixins Thor son el generador que los usaba, `CommonTasks` era
  de Hobo 2 y no lo requería nadie, y `classy_module` ya no existe. Con él
  apareció que **`hobo:model` llevaba roto desde Ruby 3**: `ERB.new(src, nil,
  "-")` — el nivel de seguridad no existe y el trim mode es una keyword.
- ~~El actualizador de plantillas sigue siendo solo el parser conservado~~
  **ya no** (2026-08-11): las plantillas no se convierten, se ejecutan --
  `hobo_dryml`--, y lo que se actualiza es la aplicación entera con
  `hobo update`.

---

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

---

## Reglas de trabajo

- **Nunca hacer push.** Ni a este repo ni a ninguno. Solo commits locales.
- **Commits sin mencionar a Claude**, ni `Co-Authored-By` ni referencias.
- **Código en inglés** (identificadores y comentarios). **Commits y documentación
  en español.**
- Parar al final de cada capa: probar, enseñar el resultado y preguntar.

---

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
