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
| Rama | `hobo_2027_v2` — solo commits locales, **nunca push** |
| Objetivo | Rails 8.1 / Ruby 3.4 |
| Suite | `cd hobo && bundle exec rake test` — **659 pruebas, 0 fallos** |

**Las cinco gemas**, cada una en su directorio de `hobo_oficial_2027/`:

| | |
|---|---|
| `hobo/` | La gema. Fusión de `hobo_support`, `hobo_fields`, `dryml`, `hobo` y `hobo_rapid` |
| `hobo_bootstrap/` | El tema Bootstrap 5.3. El tema `clean` va dentro de `hobo` |
| `hobo_jquery/` | El comportamiento con jQuery, para quien no quiera Stimulus |
| `hobo_jquery_ui/` | Los tags de jQuery UI |
| `hobo_dryml/` | El lenguaje DRYML **y la compatibilidad** con Hobo 2 |

**Las tres cosas que Hobo hace, y su estado:**

1. **Aplicación nueva** — completa. `hobo new` deja una app Rails 8 que arranca,
   con modelo, CRUD, login y páginas derivadas.
2. **Escribir una vista** — todo cuelga de **`hobo.`**: `hobo.field_list`,
   `hobo.append_heading`, `hobo.param`. En ERB, Slim o HAML. `bin/rails hobo:tags`
   los lista. No hay helpers sueltos y no se reescribe el fuente de nadie.
3. **Actualizar una app de Hobo 2** — `hobo update` desde dentro de la
   aplicación vieja. Amenti (32 modelos, 88 plantillas, 52 gemas) arranca, sus
   ocho taglibs cargan y sus páginas públicas responden.

**El catálogo son ~90 tags**, todos en Ruby y en el núcleo. `hobo_dryml` no
añade catálogo: añade el lenguaje y la compatibilidad (la caché, las páginas de
auth, `<t>`, el `Guest` que contesta a cualquier pregunta).

### El banco de pruebas

| puerto | |
|---|---|
| 3000 / 3003 | hobo2_mi_app clean / bootstrap (Ruby 2.5.9, `RBENV_VERSION=2.5.9`) |
| 3001 / 3004 | hobo3_mi_app_clean / hobo3_mi_app |
| 3005 | amenti con Hobo 2 (Ruby 1.9.3) |
| 3006 | amenti actualizada con Hobo 3 |

Y el banco grande de DRYML: **`/mnt/e/APSOFT/UnoyCero/aplicaciones`** — 807
plantillas de ~20 aplicaciones reales de tres versiones de Hobo, 625 tags
distintos. Amenti sola se queda corta al lado.

### La regla que más ha valido

**Mirar la página.** Los fallos de las últimas sesiones —los atributos con clave
de cadena, las rutas de assets, el idioma que se perdía, `<t>` vacío— **no daban
error en ningún sitio** y la suite estaba en verde. Ninguno se habría encontrado
sin abrir el navegador.

---|---|
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

## Para cuando toque portar los plugins de jQuery

Un patrón mental que Imanol quiere que se siga, antes de escribir un controlador
de Stimulus desde cero para cada plugin:

1. **¿Lo resuelve ya Bootstrap 5 de serie?** — carrusel, colapsables, modales,
   tooltips y desplegables vienen dentro. Desde 2026-08-12 el tema trae también
   su JavaScript, así que están disponibles sin hacer nada.
2. **Si no, mirar Stimulus Components y Rails Blocks** antes de escribir nada.
   Cubren la mayoría de los casos corrientes (carruseles, datepickers,
   tooltips, colapsables, modales a medida).
3. Y sólo entonces, escribirlo.

## La medida de las clases de Bootstrap (2026-08-12)

Hecha contra las hojas de verdad —el Bootstrap 2 que amenti vendoriza, un
Bootstrap 3.2 del disco `E:` y nuestro 5.3.8— y contra las **867 plantillas** de
`/mnt/e/APSOFT/UnoyCero/aplicaciones`. El guion está en el diario.

| | |
|---|---|
| Clases distintas que escriben las plantillas | 863 |
| De ésas, existían en Bootstrap 2 o 3 y **no** en el 5 | 77 (1.291 apariciones) |
| Iconos (`icon-*`, sin traducción posible) | 23 clases / 163 apariciones |
| El resto | 54 clases / 1.128 apariciones |
| De ese resto, lo que hoy reescribe `hobo update` | 8 clases / 329 apariciones |
| Lo que no está en la tabla | 41 clases / 602 apariciones |

Y **45 de las 77 murieron ya en el salto 2→3**, no en el 4→5: por eso hace
falta leer las dos guías, la de 3→4 y la de 4→5, y además la de 2→3.

## Lo siguiente, por orden

1. **Regenerar amenti con el mapa de clases aplicado.** La que corre en el 3006
   se generó antes de ese cambio, así que la comparación contra el 3005 todavía
   no se ha hecho de verdad. Es lo primero:

       cd ~/RubymineProjects/hobo_apps/hobo2_amenti
       RBENV_VERSION=3.4.6 HOBODEV=/home/imanol/RubymineProjects/hobo_oficial_2027 \
         hobo update --write --theme=bootstrap

   Después hacen falta a mano cuatro cosas que el comando nombra pero no puede
   hacer: `gem "hobo_dryml"`, `gem "money"` + `gem "offsite_payments"` (el
   relevo de `ActiveMerchant::Billing::Integrations`), copiar
   `config/initializers/constants.rb.example` a `constants.rb`, y cambiar una
   línea en `pagos_controller.rb`. **Añadir `hobo_dryml` sola sí debería hacerlo
   el comando**: ya cuenta las 88 plantillas.

2. **Mirar la portada del 3006 contra la del 3005**, y las páginas privadas, que
   no se han visto. El contenido sale; la maquetación no se ha comparado.

3. **Las clases de Bootstrap 2 que quedan** — 14 en amenti. El comando las lista
   con su equivalente y no las toca (decisión 23). Cambiarlas es del usuario.

4. **Lo que queda del catálogo**, si aparece: los tags de `hobo_jquery_ui`
   (`accordion`, `tabs`, `dialog-box`, `sortable-collection`) van a esa gema, no
   al núcleo.

**Y lo que está apuntado sin prisa:**

- **Borrar `hobo/lib/dryml/`** — 3.585 líneas que ya no usa nadie: `hobo_dryml`
  tiene lector y compilador propios.
- **Los ocho plugins de la organización** siguen fuera y a propósito. Y desde
  que existe `hobo_dryml` puede que **no haya que convertir su DRYML**: si el
  plugin depende de esa gema, sus taglibs se ejecutan tal cual. Sin comprobar
  contra ninguno.
- **Nivel 3 de las pruebas** (aplicaciones generadas de verdad), aplazado.
- **`hobo:model` llevaba roto desde Ruby 3** y se arregló; queda mirar si hay
  más generadores en ese estado.

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
