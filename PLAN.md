# Plan de trabajo — Hobo 2027

> **Si retomas la sesión, lee este fichero y no reconstruyas nada de la
> conversación.** Dónde estamos y qué queda. Es corto a propósito.
>
> - **`DECISIONES.md`** — lo que está decidido y por qué. Manda sobre todo lo
>   demás.
> - **`DIARIO.md`** — cómo se llegó hasta aquí, por fechas.
> - **`HALLAZGOS.md`** — lo que salió mal en el primer intento.

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

- **Cómo se escribe una vista**: `hobo.` y nada más -- `hobo.field_list`,
  `hobo.append_heading`. En ERB, Slim o HAML. `bin/rails hobo:tags` los lista.
- **DRYML**: lector y compilador propios, sin REXML. Lee las 88 plantillas de
  amenti y compila 94 de los 96 ficheros del catálogo de Hobo 2.

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

1. **Completar el catálogo.** Hoy `hobo.` contesta a 52 nombres y a Hobo 2 le
   faltan 72. De esos 72, unos 30 no vuelven -- editores en vivo y caché (el
   AJAX de 2008), las páginas de auth (Rails 8) y los de i18n (`t` de Rails) --
   y **unos 40 sí**: `collection`, `page-nav`, `count`, `delete-button`,
   `create-button`, `new-page`, `edit-page`, `hidden-field`, `select-many`. Se
   portan a Ruby en tandas, empezando por los que amenti usa, y los dudosos
   (`gravatar`, `hobo-cache`, `datepicker-rails`) se preguntan.
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
