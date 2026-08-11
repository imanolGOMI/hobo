# Decisiones — Hobo 2027

> Lo que está decidido y por qué. Si algo del código no cuadra con esto, manda
> esto: revisado contra el árbol el 2026-08-11.
>
> - **`PLAN.md`** — dónde estamos y qué queda. Se lee primero y es corto.
> - **`DIARIO.md`** — cómo se llegó a cada sitio, por fechas.

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


**Decididas el 2026-08-11, en la sesión larga de DRYML**

16. **DRYML vuelve, como lenguaje y como gema aparte** (`hobo_dryml`). Una
    aplicación con 88 plantillas en DRYML no está actualizada si no se puede ver
    ni una pantalla, y todas llevan a `/`, que es DRYML. Compila contra Rapid:
    no hay un segundo runtime.
17. **El catálogo va en el núcleo, en Ruby, siempre.** Aunque los tags que
    faltan estén escritos en DRYML, se portan a Ruby y no se cargan desde la
    gema: si el núcleo dependiera de `hobo_dryml`, el lenguaje opcional dejaría
    de ser opcional -- que es exactamente de donde venimos.
18. **Todo lo de Hobo en una plantilla cuelga de `hobo.`**: `hobo.field_list`,
    `hobo.append_heading`, `hobo.param`. Se quitaron los 63 helpers sueltos
    (`<%= card %>`, `<%= form %>`): leídos en una plantilla no dicen de dónde
    salen, y el día que la aplicación defina un helper con ese nombre gana el
    suyo, el tag desaparece y no salta nada. Es un objeto y no un módulo porque
    los tags necesitan la vista (token, usuario, `capture`).
19. **En ERB no se reescribe el fuente.** `<append-heading:>` en un `.html.erb`
    se escribió y se quitó el mismo día: aportaba sintaxis y no poder, y era la
    única pieza que podía fallar callada -- una regex reescribe lo que hay
    dentro de un `<!-- -->` o de un `<script>`, así que marcado comentado se
    ejecutaba. Quien quiera esa sintaxis tiene `.dryml`.
20. **Dos formas de escribir, y el usuario elige** (como Hobo 2, pero al revés).
    ERB/Slim con `hobo.` viene de fábrica; DRYML se instala. En Hobo 2 no había
    elección: `dryml` era dependencia de la gema `hobo` y el catálogo estaba
    escrito en él.
21. **Los tags transparentes salen del catálogo.** `img`, `br`, `hr`, `link`,
    `meta`, `base`, `frame`, `area`, `col` y `param` no hacían nada -- `<def
    tag="img"><empty-tag tag-name="img" merge/></def>` -- y existían sólo
    porque la lista de nombres de DRYML no los tiene. Están en la lista de
    `hobo_dryml`, así que `<img/>` sale igual en un `.dryml` y en ERB se escribe
    HTML. Comprobado contra 807 plantillas reales.

22. **Ninguna pieza devuelve vacío cuando le falta un dato.** O pinta algo
    legible, o se queja. Los cuatro fallos del 2026-08-11 en amenti eran el
    mismo silencio: un atributo que no llegaba, una ruta que no resolvía, un
    idioma que no se conservaba y una traducción que no existía. Ninguno dio
    error; los cuatro se vieron mirando la página.
23. **`hobo update` traduce las clases del tema, y sólo ésas.** El mapa que
    Hobo puede tener no es «Bootstrap 2 → Bootstrap 5» -- eso es de Bootstrap y
    son miles de clases -- sino **lo que emitía el tema de Hobo 2 → lo que
    emite el de Hobo 3**, que son las de la tabla de `hobo_bootstrap` y de las
    que conocemos las dos puntas. Las clases propias del usuario no se tocan.
24. **Un framework vendorizado no cruza.** Una aplicación que se llevó dentro
    su copia de Bootstrap 2 se queda sin ella: se avisa de qué clases quedan
    sueltas y con qué se corresponden, y el usuario decide. Arrastrarlo sería
    tenerlo ahí dentro cinco años más sin que nadie sepa por qué.

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
| 14 | ~~envoltorios de HTML que no hay que portar~~ **falso, corregido el 2026-08-11**: DRYML decide elemento o tag con una **lista** (`dryml/static_tags`, 98 nombres), y `a`, `img`, `br`, `form`, `input`, `table` y `section` **están fuera** -- son llamadas a tag. Su `<a>` coge un registro y saca la url; su `<img>` resuelve la ruta del asset. No son envoltorios: **hay que portarlos** |
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

---

## Reglas absolutas sobre `git push`

- **Nunca se hace push. Nunca, a ningún sitio.** El push lo hace Imanol a mano.
- **Jamás al repositorio de la organización `Hobo/`.** No hay permiso y no lo
  habrá. Los repos de la organización solo se **clonan y leen**.
- El único destino que existiría, y aun así lo hace él, es el repositorio
  personal de Imanol.

---

---

---

## Reglas de trabajo

- **Nunca hacer push.** Ni a este repo ni a ninguno. Solo commits locales.
- **Commits sin mencionar a Claude**, ni `Co-Authored-By` ni referencias.
- **Código en inglés** (identificadores y comentarios). **Commits y documentación
  en español.**
- Parar al final de cada capa: probar, enseñar el resultado y preguntar.

---
