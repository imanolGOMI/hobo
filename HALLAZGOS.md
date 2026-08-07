# Lo que aprendimos del primer intento

Este documento recoge lo que salió de pasar una aplicación Hobo 2 de verdad por
el camino de actualización a Rails 8. Está escrito para que el segundo intento
no vuelva a descubrir lo mismo.

El código de ese primer intento está en la rama `hobo_2027`, marcado con el tag
`intento-1-update`. No hace falta leerlo para entender esto.

---

## El banco de pruebas

**amenti**, una aplicación de gestión de funerarias de 2017:

| | |
|---|---|
| Ruby | 1.9.3-p551 |
| Rails | 3.2.22, desde un fork de git |
| Hobo | 2.0.1 |
| Bootstrap | **2.3** (no 3: `.container` de 940px fijos, rejilla `.span12`) |
| Tamaño | 70 modelos y controladores, 81 plantillas DRYML, 27 tablas, 13 MB de datos |

Levantarla costó medio día y es la inversión que más rindió: **los cuatro fallos
del núcleo de Hobo 3 que encontramos no los saca ninguna prueba unitaria.** Sin
una aplicación real detrás no aparecen.

### Cómo volver a levantarla

1. `rbenv install 1.9.3-p551` funciona. La receta de ruby-build compila su
   propio OpenSSL 1.0.2 y llega a rubygems por TLS.
2. Bundler 1.17.3 (el 2.x pide Ruby >= 2.3).
3. `git://` está muerto desde 2022: hay que reescribir el Gemfile a `https://`.
4. Gemas que no compilan hoy y hay que sortear:
   - `puma 3.6` contra OpenSSL 3 → apuntarla al OpenSSL que rbenv compiló:
     `bundle config build.puma --with-opt-dir=$HOME/.rbenv/versions/1.9.3-p551/openssl`
   - `sqlite3 1.3.10` necesita cabeceras de sqlite. Se compila la amalgama
     dentro del propio prefijo de rbenv y se apunta con
     `--with-sqlite3-dir`. Sin tocar el sistema.
   - `mysql2 0.3.x`, `therubyracer`/`libv8` no compilan: fuera. Node del
     sistema hace de runtime de JavaScript.
5. La base de datos: el repositorio traía sqlite con datos reales aunque el
   `database.yml` apuntara a un MySQL cuyas credenciales ya no valían.
6. `hobo-metasearch` no existe: su repositorio se borró. Se quita del Gemfile y
   del `front_site.dryml`.

**La imagen `ruby:1.9.3` de Docker ya no arranca** con Docker 29: usa un
manifiesto v1 que containerd 2.1 rechaza. La vía nativa con rbenv es la que
funciona.

---

## Los cuatro fallos de Hobo 3

Ninguno es de la aplicación. Le pasarían a cualquiera.

### 1. Todos los `down` de las migraciones salían rotos

`Migrator#revert_table` construía `ActiveRecord::SchemaDumper.new` a mano. El
volcador hay que pedírselo al adaptador (`connection.create_schema_dumper`),
porque volcar una tabla llama a `column_spec_for_primary_key`, que vive en el
módulo del adaptador. Construido a mano le falta ese método — y **desde Rails 8
eso no lanza: devuelve un comentario**. La migración se escribía entera con las
líneas del `down` sin tipo, y solo fallaba al ejecutarla.

Lección: las pruebas generaban el `down` y no lo ejecutaban nunca.

### 2. `<select-one>` roto para casi todo `belongs_to`

Hacía `klass.all.merge(reflection.scope)`, y `scope` es `nil` en cualquier
asociación sin scope. Hasta Rails 8 eso fusionaba sin hacer nada; ahora lanza
`invalid argument: nil` y se lleva por delante **cualquier formulario con un
belongs_to dentro**.

### 3. `<hobo-cache>` construía su clave con `url_for`

La clave de caché salía de `url_for` con los atributos del tag (`suffix`,
`user`, `mtime`). Rails 8 lanza `UrlGenerationError` con claves que no
identifican ninguna ruta. La URL nunca era el objetivo: lo era una cadena
estable.

### 4. El railtie de DRYML daba por ordenados dos hooks que no lo están

Registraba el manejador de plantillas en `on_load(:action_view)` y lo requería
en `on_load(:before_initialize)`. Una aplicación con suficientes gemas carga
ActionView mientras se lee el Gemfile, y entonces la constante no existe.

---

## Las trampas del camino de actualización

Medidas sobre amenti, no estimaciones.

### El updater no puede ser un generador de Rails

`hobo:update` era un generador, o sea que para actualizar la aplicación había
que **arrancarla** — y una aplicación Rails 3.2 no arranca con Rails 8. Tiene
que correr desde fuera, en el entorno del Hobo instalado, tratando la
aplicación como un directorio de ficheros.

Y al sacarlo fuera aparece el segundo: si lee con rutas relativas al directorio
actual, desde fuera **no encuentra nada y anuncia que no hay nada que
reescribir**. Ocho ficheros con `attr_accessible` pasaron desapercibidos así.

Además, lanzado desde dentro de la aplicación, el gestor de versiones lee su
`.ruby-version` (1.9.3) y lo que sale es un `LoadError` de `active_support` que
no dice nada del problema real.

### Propshaft es la elección equivocada al actualizar

Fue el error que más tiempo costó ver. Dos motivos, y el segundo es el que
decide:

- **Los manifiestos.** `front.css` es una lista de `*= require`. Propshaft no
  lee directivas: serviría ese fichero, que es un comentario.
- **Las rutas.** Una plantilla que dice `<img src="/assets/logo.jpg">` — y todas
  lo dicen — recibe un 404 de Propshaft, que solo sirve nombres con dígito.
  Sprockets sirve las dos formas en desarrollo.

Reescribir cada ruta escrita a mano en las plantillas no es algo que una
actualización pueda hacer. **Se conserva el pipeline que la aplicación tiene.**

Lo que hace falta para que Sprockets 4 funcione sobre una aplicación de Rails 3:
`app/assets/config/manifest.js` (no existía, es posterior), y renombrar a `.css`
los manifiestos llamados `.scss` que no tienen una línea de Sass dentro.

### El Gemfile

- `git://` muerto desde 2022.
- Un fork de git de 2013 o está en upstream o no está en ningún sitio: se
  consulta rubygems y se prefiere la versión publicada.
- Los pines de la era Rails 3 no resuelven.
- **El lockfile hace que bundler se degrade a sí mismo** a la 1.10.5 antes de
  resolver nada (`BUNDLED WITH`), y las ramas que guardó ("master") las ha
  renombrado GitHub. Hay que apartarlo.
- Quitar una gema y dejar su `<include gem=...>` en un taglib, o su
  `*= require` en un manifiesto, es media eliminación: revienta al pintar, muy
  lejos de la línea del Gemfile que lo causó.

### will_paginate: no se toca

El updater la quitaba del Gemfile, dejando cada `Post.paginate(...)` llamando a
un método inexistente. **Pagy no parchea nada** —ni `paginate` en ActiveRecord
ni `page` en las relations— así que convive con will_paginate o kaminari sin
que se enteren. La actualización no tiene por qué tocar la paginación de nadie.

### Cuánto hay que reescribir en las plantillas

| | sitios |
|---|---|
| Clases de Bootstrap 2/3 (`well`, `pull-right`, `span8`, `form-horizontal`…) | 251 en 38 plantillas |
| Capa Ajax de jQuery (`updates=`, `update=`, `complete="$(…)"`, `ajax`) | 85 |

Lo primero es mecánico. Lo segundo no: Hobo 3 cambió jQuery por Turbo y esas 85
llamadas hay que rehacerlas de otra forma.

### Cambios de terceros que no son ni de Rails ni de Hobo

Aparecen sí o sí en una aplicación de esta edad, y conviene detectarlos y
decirlo, no intentar arreglarlos:

- `ActiveMerchant::Billing::Integrations` se fue a la gema `offsite_payments` en
  2015.
- Ransack 4 exige declarar `ransackable_attributes` en cada modelo.
- `factory_girl` es `factory_bot` desde 2017 (y pide `observer`, fuera de las
  gemas por defecto de Ruby 3.4).

---

## El error de planteamiento

Es lo más importante de este documento.

**Traté el tema como una traducción cuando un tema de Hobo es un contrato.**

Un tema no es «el mismo markup con otras clases». Es un conjunto de tags y, sobre
todo, de **parámetros** que las aplicaciones extienden. `page_extensions.dryml`
de amenti sobreescribía `<app-name:>`, `<footer:>`, `<account-nav:>`,
`<append-head:>`. Mi tema hacía `<page-header: replace>` con markup nuevo, y
`replace` se lleva por delante los parámetros que había debajo.

Y no falla. **La página se pinta, con los valores por defecto del tema donde iba
lo de la aplicación.** Se pierde diseño en silencio, un parámetro cada vez, y
solo se descubre mirando el HTML elemento por elemento.

### Cómo plantearlo bien

1. Enumerar el contrato completo del tema de Hobo 2: cada tag y cada `param`.
   Está en `hobo_bootstrap` 2.x (19 taglibs, 865 líneas) y `hobo_bootstrap_ui`
   (7 taglibs, 350 líneas).
2. Escribir una prueba que lo exija: *para cada parámetro que exponía `<page>`
   en Hobo 2, existe uno con ese nombre en Hobo 3, o el codemod lo renombra y lo
   dice.*
3. **Solo entonces** elegir el markup.

Eso habría cazado de golpe todo lo que fuimos perdiendo de uno en uno.

### El método que sí funcionó

Comparar el **texto** de las dos versiones de la misma página. De 59 bloques de
texto de la portada, faltaban dos: el título y el cambiador de usuario de
desarrollo. Eso dijo en un minuto lo que tres rondas de «recarga y mira» no
habían dicho: que el contenido estaba entero y lo que se perdía era diseño.

Comprobar códigos HTTP 200 no sirve para esto. Mirar el HTML, sí.

---

## Lo que quedó sin resolver

- **La capa Ajax.** 85 sitios con `updates=` y `complete="$(…)"`. Turbo es el
  sustituto pero la traducción no es mecánica.
- **El cambiador de usuario de desarrollo** (`<dev-user-changer>`): en Hobo 3
  solo quedan sus traducciones, el tag no se portó.
- **`table-plus-with-filters`**, de `hobo-metasearch`: una tabla con filtros por
  columna sobre Ransack. Funcionalidad de listado; su sitio sería `hobo_rapid`.
- **Los widgets de jQuery UI**: datepicker, autocompletado, ordenar arrastrando.
  Hoy son `<input type="date">`, `<datalist>` y Stimulus.
- **El pin `pagy ~> 9.3`** se resolvió pasando a Pagy 43, pero conviene saber
  que Pagy cambia de API entre versiones mayores.
- Los taglibs del tema que no llegaron a portarse: `index_page`, `login`,
  `tabs`, `table-plus`, `show_page`, `search`, `alert_box`, `lifecycle`.

---

## Una decisión que sigue abierta

Una aplicación que se actualiza tiene **dos migraciones distintas** metidas en
una:

- **A** — Rails 3.2 → 8, Ruby 1.9 → 3.4, Hobo 2 → 3. Mecánica y verificable.
- **B** — Bootstrap 2/3 → 5. Un rediseño.

Mezclarlas fue un error: cuando una pantalla sale rara no sabes de cuál de las
dos viene. Separarlas también permite ofrecer «actualiza el framework hoy y el
diseño cuando quieras», que es lo que la mayoría querrá.

Si se decide que la aplicación tiene que verse **igual** después de actualizar,
eso implica conservar el CSS de su Bootstrap y un tema con los taglibs de
entonces. Si se decide que puede verse **distinta pero bien**, basta con
completar el tema nuevo. Las dos son defendibles; lo que no funciona es no
elegir.
