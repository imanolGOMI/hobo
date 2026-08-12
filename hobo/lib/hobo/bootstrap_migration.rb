require "set"

# Bootstrap 2 -> 3 -> 4 -> 5, una etapa detrás de otra.
#
# La forma de esto la pidió Imanol y es la correcta: no hay un salto de 2 a 5,
# hay **tres saltos**, y cada uno tiene su guía oficial. Encadenarlos es lo
# único que da una respuesta completa, porque muchos nombres cambian dos veces:
#
#   .pull-right  ->  (3) .pull-right  ->  (4) .float-right  ->  (5) .float-end
#   .span5       ->  (3) .col-md-5    ->  (4) .col-lg-5     ->  (5) .col-lg-5
#   .icon-trash  ->  (3) .glyphicon-trash -> (4) se fueron   ->  (5) .bi-trash
#
# Leyendo solo la guía de 4 a 5 no aparece ni `pull-right` ni `span5`: para
# entonces llevaban años sin existir. Medido sobre las 867 plantillas del disco
# `E:`, **45 de las 77 clases que se rompen murieron ya en el salto 2 -> 3**.
#
# ## De dónde salen las tablas
#
# De las tres guías de migración oficiales, no de la memoria de nadie:
#
#   https://getbootstrap.com/docs/3.3/migration/
#   https://getbootstrap.com/docs/4.6/migration/
#   https://getbootstrap.com/docs/5.3/migration/
#
# Y se comprueban contra las hojas de estilo de verdad -- las clases que cada
# versión define -- con `script/medir_clases_bootstrap.py`. La prueba de que
# están completas no es que estén escritas: es que después de las tres etapas
# **no queda ni una clase** de las 867 plantillas que existiera en Bootstrap 2,
# 3 o 4 y no exista en el 5.
#
# ## Lo que una tabla de nombres no puede hacer
#
# Tres cosas, y se nombran en vez de fingirse:
#
#   - Los formularios de Bootstrap 2 (`form-horizontal` + `control-group` +
#     `controls`) no son un renombre, son otra estructura de marcado.
#   - `.panel` -> `.card` cambia la anidación, no solo el nombre.
#   - Y las palabras corrientes -- `item`, `left`, `right`, `active`, `info` --
#     que en Bootstrap significan una cosa dentro de un componente y fuera no
#     significan nada. Ésas se cambian **con contexto** o no se cambian.

module Hobo

  module BootstrapMigration

    # --- 2 -> 3 ---------------------------------------------------------------

    BS2_TO_BS3 = {
      "row-fluid" => "row",
      "brand" => "navbar-brand",
      "nav-collapse" => "navbar-collapse",
      "nav-toggle" => "navbar-toggle",
      "btn-navbar" => "navbar-btn",
      "navbar-inner" => "",
      "hero-unit" => "jumbotron",
      "btn-mini" => "btn-xs",
      "btn-small" => "btn-sm",
      "btn-large" => "btn-lg",
      "btn-inverse" => "btn-default",
      "visible-phone" => "visible-xs",
      "visible-tablet" => "visible-sm",
      "visible-desktop" => "visible-md visible-lg",
      "hidden-phone" => "hidden-xs",
      "hidden-tablet" => "hidden-sm",
      "hidden-desktop" => "hidden-md hidden-lg",
      "input-block-level" => "form-control",
      "control-group" => "form-group",
      "controls-row" => "row",
      "controls" => "",
      "input-prepend" => "input-group",
      "input-append" => "input-group",
      "add-on" => "input-group-addon",
      "img-polaroid" => "img-thumbnail",
      "unstyled" => "list-unstyled",
      "muted" => "text-muted",
      "label-important" => "label-danger",
      "text-error" => "text-danger",
      "bar" => "progress-bar",
      "accordion" => "panel-group",
      "accordion-group" => "panel panel-default",
      "accordion-heading" => "panel-heading",
      "accordion-body" => "panel-collapse",
      "accordion-inner" => "panel-body",
      "pill-content" => "tab-content",
      "pill-pane" => "tab-pane",
      "help-inline" => "help-block",
      "alert-error" => "alert-danger",
      "form-search" => "",
      "form-actions" => "",
      "thumbnails" => "row",
      "nav-list" => "list-group",
      "nav-header" => "list-group-item-heading",
      "search-query" => "form-control",
      "input-mini" => "form-control",
      "input-small" => "form-control",
      "input-medium" => "form-control",
      "input-large" => "form-control",
      "input-xlarge" => "form-control",
      "input-xxlarge" => "form-control",
    }.merge((1..12).to_h { |n| ["span#{n}", "col-md-#{n}"] })
     .merge((1..12).to_h { |n| ["offset#{n}", "col-md-offset-#{n}"] })
     .freeze

    # --- 3 -> 4 ---------------------------------------------------------------
    #
    # El salto de la rejilla: `col-md-*` pasa a `col-lg-*` y `col-lg-*` a
    # `col-xl-*`, porque Bootstrap 4 metió un punto de corte por debajo. Un
    # `span5` de Bootstrap 2 acaba siendo `col-lg-5`, y eso es lo que hace que
    # encadenar no sea lo mismo que traducir de una vez.
    BS3_TO_BS4 = {
      "img-responsive" => "img-fluid",
      "img-rounded" => "rounded",
      "img-circle" => "rounded-circle",
      "table-condensed" => "table-sm",
      "table-inverse" => "table-dark",
      "thead-inverse" => "thead-dark",
      "thead-default" => "thead-light",
      "control-label" => "col-form-label",
      "input-lg" => "form-control-lg",
      "input-sm" => "form-control-sm",
      "help-block" => "form-text",
      "form-control-static" => "form-control-plaintext",
      "btn-default" => "btn-secondary",
      "btn-xs" => "btn-sm",
      "btn-group-xs" => "btn-group-sm",
      "divider" => "dropdown-divider",
      "navbar-default" => "navbar-light",
      "navbar-toggle" => "navbar-toggler",
      "navbar-btn" => "btn",
      "navbar-form" => "form-inline",
      "pull-left" => "float-left",
      "pull-right" => "float-right",
      "center-block" => "mx-auto",
      "hidden" => "d-none",
      "hide" => "d-none",
      "hidden-print" => "d-print-none",
      "panel" => "card",
      "panel-heading" => "card-header",
      "panel-title" => "card-title",
      "panel-body" => "card-body",
      "panel-footer" => "card-footer",
      "panel-default" => "",
      "panel-group" => "",
      "well" => "card card-body",
      "thumbnail" => "card",
      "caption" => "card-body",
      "page-header" => "border-bottom pb-2 mb-3",
      "dl-horizontal" => "row",
      "img-thumbnail" => "img-thumbnail",
      "label" => "badge",
      "label-default" => "badge-secondary",
      "label-primary" => "badge-primary",
      "label-success" => "badge-success",
      "label-info" => "badge-info",
      "label-warning" => "badge-warning",
      "label-danger" => "badge-danger",
      "list-inline-item" => "list-inline-item",
      "caret" => "",
      "affix" => "sticky-top",
      "pager" => "pagination",
      "progress-striped" => "progress-bar-striped",
      "blockquote-reverse" => "text-right",
      "container-fluid" => "container-fluid",
    }.merge((1..12).to_h { |n| ["col-xs-#{n}", "col-#{n}"] })
     .merge((1..12).to_h { |n| ["col-md-#{n}", "col-lg-#{n}"] })
     .merge((1..12).to_h { |n| ["col-lg-#{n}", "col-xl-#{n}"] })
     .merge((1..12).to_h { |n| ["col-md-offset-#{n}", "offset-lg-#{n}"] })
     .merge(%w[xs sm md lg].to_h { |size| ["visible-#{size}", "d-block"] })
     .merge(%w[xs sm md lg].to_h { |size| ["hidden-#{size}", "d-none"] })
     .freeze

    # --- 4 -> 5 ---------------------------------------------------------------

    BS4_TO_BS5 = {
      "float-left" => "float-start",
      "float-right" => "float-end",
      "text-left" => "text-start",
      "text-right" => "text-end",
      "border-left" => "border-start",
      "border-right" => "border-end",
      "rounded-left" => "rounded-start",
      "rounded-right" => "rounded-end",
      "rounded-sm" => "rounded-1",
      "rounded-lg" => "rounded-3",
      "no-gutters" => "g-0",
      "form-group" => "mb-3",
      "form-row" => "row",
      "form-inline" => "d-flex flex-wrap align-items-center",
      "custom-select" => "form-select",
      "custom-range" => "form-range",
      "custom-file" => "form-control",
      "form-control-file" => "form-control",
      "custom-checkbox" => "form-check",
      "custom-radio" => "form-check",
      "custom-switch" => "form-check form-switch",
      "custom-control" => "form-check",
      "custom-control-input" => "form-check-input",
      "custom-control-label" => "form-check-label",
      "input-group-append" => "",
      "input-group-prepend" => "",
      "input-group-addon" => "input-group-text",
      "badge-pill" => "rounded-pill",
      "badge-primary" => "bg-primary",
      "badge-secondary" => "bg-secondary",
      "badge-success" => "bg-success",
      "badge-danger" => "bg-danger",
      "badge-warning" => "bg-warning text-dark",
      "badge-info" => "bg-info text-dark",
      "badge-light" => "bg-light text-dark",
      "badge-dark" => "bg-dark",
      "btn-block" => "w-100",
      "close" => "btn-close",
      "sr-only" => "visually-hidden",
      "sr-only-focusable" => "visually-hidden-focusable",
      "text-monospace" => "font-monospace",
      "font-italic" => "fst-italic",
      "font-weight-bold" => "fw-bold",
      "font-weight-bolder" => "fw-bolder",
      "font-weight-normal" => "fw-normal",
      "font-weight-light" => "fw-light",
      "font-weight-lighter" => "fw-lighter",
      "jumbotron" => "p-5 mb-4 bg-body-tertiary rounded-3",
      "jumbotron-fluid" => "p-5 mb-4 bg-body-tertiary",
      "media" => "d-flex",
      "media-body" => "flex-grow-1",
      "card-deck" => "row row-cols-1 row-cols-md-3 g-4",
      "card-columns" => "row row-cols-1 row-cols-md-3 g-4",
      "embed-responsive" => "ratio",
      "embed-responsive-16by9" => "ratio-16x9",
      "embed-responsive-4by3" => "ratio-4x3",
      "embed-responsive-item" => "",
      "thead-light" => "table-light",
      "thead-dark" => "table-dark",
      "pre-scrollable" => "overflow-auto",
      "text-hide" => "visually-hidden",
      "carousel-item-left" => "",
      "carousel-item-right" => "",
      "input-group-text" => "input-group-text",
      "table-responsive" => "table-responsive",
    }.merge(%w[0 1 2 3 4 5 auto].flat_map { |n|
      [["ml-#{n}", "ms-#{n}"], ["mr-#{n}", "me-#{n}"], ["pl-#{n}", "ps-#{n}"], ["pr-#{n}", "pe-#{n}"]]
    }.to_h)
     .merge(%w[sm md lg xl].flat_map { |size|
       [["text-#{size}-left", "text-#{size}-start"], ["text-#{size}-right", "text-#{size}-end"]]
     }.to_h)
     .freeze

    # Las palabras corrientes, que solo significan algo acompañadas.
    #
    # `in` es la marca de «abierto» de un colapsable en Bootstrap 3 y en la 4 se
    # llama `show`; suelta no es nada, y hay aplicaciones que la usan para lo
    # suyo. `success` e `info` en una fila de tabla son `table-success` y
    # `table-info`; en cualquier otro sitio no se tocan.
    #
    # La regla: **solo si en el mismo `class=` viene una clase que lo confirma**.
    CONTEXTUAL = {
      "in" => ["show", %w[collapse fade tab-pane modal carousel]],
      "checkbox" => ["form-check", %w[form-group mb-3 form-check-input]],
      "radio" => ["form-check", %w[form-group mb-3 form-check-input]],
    }.freeze

    # Y las filas de tabla, que se miran por el elemento y no por la clase de al
    # lado: `<tr class="success">` es `<tr class="table-success">`.
    TABLE_STATES = { "success" => "table-success", "info" => "table-info",
                     "warning" => "table-warning", "danger" => "table-danger",
                     "error" => "table-danger", "active" => "table-active" }.freeze

    # `data-toggle` y compañía: Bootstrap 5 los lee con `bs` delante, y sin eso
    # su javascript no se entera de que el componente existe -- el carrusel se
    # queda quieto con todas las fotos una encima de otra.
    DATA_ATTRIBUTES = %w[toggle target dismiss ride spy slide slide-to parent
                         content placement trigger offset boundary
                         backdrop keyboard focus interval wrap pause delay
                         html container animation template title original-title
                         display autohide].freeze

    # Los iconos. **Bootstrap sí tiene iconos**: `bootstrap-icons`, oficial y de
    # los mismos autores. Lo que no hace es meterlos en el css del framework.
    #
    # El camino completo es `icon-trash` (2) -> `glyphicon-trash` (3) -> nada
    # (4) -> `bi-trash` (5), y como en la 4 desaparecen, la traducción se hace
    # de una vez y al final. Los nombres no coinciden -- `ok` es `check`,
    # `remove` es `x` -- así que hay tabla.
    ICONS = {
      "trash" => "trash", "pencil" => "pencil", "edit" => "pencil-square",
      "plus" => "plus-lg", "minus" => "dash-lg", "ok" => "check-lg",
      "remove" => "x-lg", "remove-circle" => "x-circle", "ok-circle" => "check-circle",
      "search" => "search", "print" => "printer", "refresh" => "arrow-clockwise",
      "user" => "person", "envelope" => "envelope", "file" => "file-earmark",
      "book" => "book", "tags" => "tags", "tag" => "tag", "time" => "clock",
      "star" => "star-fill", "star-empty" => "star", "share" => "share",
      "arrow-left" => "arrow-left", "arrow-right" => "arrow-right",
      "arrow-up" => "arrow-up", "arrow-down" => "arrow-down",
      "chevron-left" => "chevron-left", "chevron-right" => "chevron-right",
      "step-backward" => "skip-backward-fill", "step-forward" => "skip-forward-fill",
      "play" => "play-fill", "pause" => "pause-fill", "stop" => "stop-fill",
      "download" => "download", "download-alt" => "download", "upload" => "upload",
      "home" => "house", "calendar" => "calendar", "lock" => "lock",
      "eye-open" => "eye", "eye-close" => "eye-slash", "cog" => "gear",
      "wrench" => "wrench", "info-sign" => "info-circle", "question-sign" => "question-circle",
      "warning-sign" => "exclamation-triangle", "exclamation-sign" => "exclamation-circle",
      "list" => "list", "th-list" => "list-ul", "th" => "grid-3x3",
      "check" => "check-square", "picture" => "image", "camera" => "camera",
      "folder-open" => "folder2-open", "folder-close" => "folder",
      "zoom-in" => "zoom-in", "zoom-out" => "zoom-out", "resize-full" => "arrows-fullscreen",
      "off" => "power", "repeat" => "arrow-repeat", "random" => "shuffle",
      "comment" => "chat", "shopping-cart" => "cart", "phone" => "telephone",
      "map-marker" => "geo-alt", "globe" => "globe", "flag" => "flag",
      "bold" => "type-bold", "italic" => "type-italic", "font" => "fonts",
      "align-left" => "text-left", "align-center" => "text-center",
      "align-right" => "text-right", "align-justify" => "justify",
      "screenshot" => "crosshair", "certificate" => "patch-check",
      "signal" => "reception-4", "inbox" => "inbox", "headphones" => "headphones",
      "volume-up" => "volume-up", "volume-off" => "volume-mute",
      "backward" => "rewind-fill", "forward" => "fast-forward-fill",
      "fire" => "fire", "leaf" => "flower1", "heart" => "heart-fill",
      "gift" => "gift", "bell" => "bell", "briefcase" => "briefcase",
      "road" => "signpost", "plane" => "airplane", "usd" => "currency-dollar",
      "eur" => "currency-euro", "gbp" => "currency-pound",
    }.freeze

    # `icon-white` era como Bootstrap 2 pintaba un icono en blanco sobre un
    # botón de color. En Bootstrap 5 el icono hereda el color del texto, así que
    # sobra -- y quitarlo es exactamente lo que hay que hacer.
    ICON_MODIFIERS = %w[icon-white glyphicon].freeze

    class << self

      # El nombre de la etapa siguiente, para poder decirlo en el informe.
      STAGES = { 2 => ["2 -> 3", BS2_TO_BS3], 3 => ["3 -> 4", BS3_TO_BS4], 4 => ["4 -> 5", BS4_TO_BS5] }.freeze

      # Una plantilla, de la versión que sea hasta la 5.
      #
      # `keep` son las clases que **la aplicación define en su propio css**: ver
      # `rename_classes`. Devuelve `[texto, etapas_aplicadas]`. Encadenar es lo
      # que hace que `span5` acabe en `col-lg-5` sin que nadie haya escrito esa
      # pareja.
      def apply(text, from: 2, keep: [])
        keep = keep.to_a.to_set if keep.respond_to?(:to_set)
        applied = []

        (from..4).each do |version|
          name, table = STAGES[version]
          next unless table

          before = text.dup
          text = rename_classes(text, table, keep)
          text = rename_carousel(text, version)
          text = rename_contextual(text, keep) if version == 3
          applied << name if text != before
        end

        text = rename_icons(text, keep)
        text = rename_data_attributes(text)
        [text, applied]
      end

      # Cada `class="..."`, palabra por palabra. Una clase puede convertirse en
      # varias (`well` -> `card card-body`) o en ninguna (`controls`).
      #
      # ## Y lo que la aplicación haya escrito de su puño se queda
      #
      # Una clase de Bootstrap puede estar **también** en el css de la
      # aplicación: `.well { background: #f5f5f5 }` retocado a su gusto,
      # `.thumbnail` con su borde, `.info` que ni siquiera es de Bootstrap sino
      # de su hoja. Cambiar el nombre a secas se lleva por delante esa regla, y
      # la página sale distinta de como estaba sin que nadie sepa por qué.
      #
      # Así que cuando la aplicación define la clase, **se conserva al lado de
      # la nueva**: `class="well"` sale como `class="card card-body well"`. La
      # de Bootstrap 5 pone el comportamiento nuevo y la suya sigue aplicando lo
      # que decía. Bootstrap 5 ya no usa ese nombre para nada, así que no hay
      # con qué chocar.
      def rename_classes(text, table, keep = [])
        text.gsub(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          renamed = names.split.flat_map do |name|
            replacement = table[name]
            next [name] unless replacement
            keep.include?(name) ? replacement.split + [name] : replacement.split
          end.uniq
          %(class=#{quote}#{renamed.join(" ")}#{quote})
        end
      end

      # Lo que solo significa algo **dentro de un componente**.
      #
      # `item` es la palabra más corriente del mundo y dentro de un carrusel
      # tiene que ser `carousel-item`, o las fotos se apilan. Fuera de uno no se
      # toca. Igual las flechas, que en Bootstrap 2 y 3 se decían con `left` y
      # `right` y desde la 4 tienen nombre propio.
      def rename_carousel(text, version)
        return text unless text.include?("carousel-inner") || text.include?("carousel-control")
        return text unless version == 3 # el cambio es del salto 3 -> 4

        text = text.gsub(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          renamed = names.split.map { |name| name == "item" ? "carousel-item" : name }
          %(class=#{quote}#{renamed.join(" ")}#{quote})
        end
        text = text.gsub("carousel-control left", "carousel-control-prev")
                   .gsub("carousel-control right", "carousel-control-next")

        # Y la foto, que se sale: Bootstrap 2 le daba `max-width: 100%` a toda
        # imagen y Bootstrap 3 quitó esa regla global.
        text.gsub(/(class="[^"]*carousel-item[^"]*"[^>]*>\s*<img)((?![^>]*\bclass=)[^>]*?)(\s*\/?>)/m) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)} class=\"d-block w-100\"#{Regexp.last_match(3)}"
        end
      end

      # Lo que solo cambia acompañado: ver `CONTEXTUAL` y `TABLE_STATES`.
      def rename_contextual(text, keep = [])
        text = text.gsub(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          written = names.split
          renamed = written.flat_map do |name|
            new_name, alongside = CONTEXTUAL[name]
            next [name] unless new_name && (written & alongside).any?
            keep.include?(name) ? [new_name, name] : [new_name]
          end.uniq
          %(class=#{quote}#{renamed.join(" ")}#{quote})
        end

        # `<tr class="success">` y `<td class="error">`: el elemento es el que
        # dice que eso es el estado de una fila y no una palabra cualquiera.
        text.gsub(/<(tr|td|th)\b([^>]*?)class=(["'])([^"']*)\3/) do
          element, rest, quote, names = Regexp.last_match.captures
          renamed = names.split.flat_map do |name|
            state = TABLE_STATES[name]
            next [name] unless state
            keep.include?(name) ? [state, name] : [state]
          end.uniq
          %(<#{element}#{rest}class=#{quote}#{renamed.join(" ")}#{quote})
        end
      end

      def rename_icons(text, keep = [])
        text.gsub(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          renamed = names.split.flat_map do |name|
            if (icon = name[/\A(?:icon|glyphicon)-(.+)\z/, 1]) && !ICON_MODIFIERS.include?(name)
              new_name = ["bi", "bi-#{ICONS[icon] || icon}"]
              keep.include?(name) ? new_name + [name] : new_name
            elsif ICON_MODIFIERS.include?(name)
              keep.include?(name) ? [name] : []
            else
              [name]
            end
          end.uniq
          %(class=#{quote}#{renamed.join(" ")}#{quote})
        end
      end

      # Las clases que la aplicación define en su propio css.
      #
      # Se leen de sus hojas y **no** de las de Bootstrap ni de las de una gema:
      # lo que se busca es lo que ha escrito quien hizo la aplicación, que es lo
      # único que hay que respetar. Un fichero que se llame `bootstrap` es de
      # Bootstrap por mucho que esté en `app/assets`.
      def application_classes(root)
        sheets = Dir[File.join(root, "app", "assets", "stylesheets", "**", "*.{css,scss,sass}")] +
                 Dir[File.join(root, "public", "stylesheets", "**", "*.css")]
        sheets.reject! { |file| File.basename(file).match?(/\Abootstrap|glyphicon|font-awesome/i) }

        sheets.each_with_object(Set.new) do |file, names|
          text = File.read(file, :encoding => "UTF-8", :invalid => :replace, :undef => :replace)
          text = text.gsub(%r{/\*.*?\*/}m, "")
          text.scan(/([^{}]+)\{/) do |selector,|
            selector.scan(/\.(-?[_a-zA-Z][\w-]*)/) { |name,| names << name }
          end
        end
      rescue StandardError
        Set.new
      end

      def rename_data_attributes(text)
        DATA_ATTRIBUTES.reduce(text) { |written, name| written.gsub(/\bdata-#{name}=/, "data-bs-#{name}=") }
      end

    end

  end

end
