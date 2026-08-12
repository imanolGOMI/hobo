# `<table>` and `<table-plus>`. Ported from Hobo 2 (2026-08-11).
#
#   <%= hobo.table :fields => "title, year, author" %>
#   <%= hobo.table_plus :fields => "title, year" %>
#
# A table of records, and the same table with a search box over it and headings
# that sort. `table-plus` was the worst case of the whole catalogue -- 58 lines
# of DRYML -- and here it is thin, because the two things it adds already exist
# as pieces: `search_filter` and `sortable_headings`.
#
# ## Why `index_page` does not call these yet
#
# The derived index paints its own table, inline, and making it call `<table>`
# is the right thing **and a change of its own**: it changes what every derived
# page of every application emits. So it goes in its own step, with the four
# applications up to compare -- which is how five real bugs were found today,
# and none of them by the suite.
#
# ## A note on the name
#
# `table` is not on DRYML's list of element names, so in a `.dryml` `<table>` is
# **this**, not an html table. That is Hobo 2's rule and it is kept. In ERB you
# write `<table>` for an html table and `hobo.table` for this one, which is the
# distinction the extension already makes.

require "rapid"
require "hobo_rapid/tags/structure"
require "hobo_rapid/sorting"

# `<table fields="title, year">`: a row per record, a column per field.
#
# With no `fields` it takes the ones the model would show, which is the same
# list a derived index uses -- so writing `<%= hobo.table %>` gives the table
# the page would have given you.
Rapid.define(:table, :attrs => [:fields, :field_tag, :empty]) do
  records = Array(this).select { |record| viewable?(record) }
  model = this.respond_to?(:klass) ? this.klass : records.first&.class

  next if records.empty? && !attributes[:empty]

  columns = attributes[:fields].to_s.split(",").map(&:strip).reject(&:empty?)
  columns = model ? HoboRapid::Derivation.index_columns(model) : [] if columns.empty?
  painter = (attributes[:field_tag] || "view").to_sym

  rest = all_attributes.except(:fields, "fields", :field_tag, "field_tag", :empty, "empty")

  tag("table", rest.merge("class" => ["collection-table", rest["class"]].compact.join(" "))) do
    tag("thead", {}, :thead) do
      tag("tr", {}, :field_heading_row) do
        columns.each do |field|
          # The heading is its own param, named after the field, which is what
          # lets a page or a taglib change one column and leave the rest --
          # `sortable_headings` is exactly that, done to all of them at once.
          tag("th", {}, :"#{field}_heading") do
            text(model ? HoboRapid::Derivation.label_for(model, field) : field.to_s.humanize)
          end
        end
        tag("th", { "class" => "controls" }, :controls_heading) if all_parameters.key?(:controls)
      end
    end

    tag("tbody", {}, :tbody) do
      records.each_with_index do |record, index|
        with_this(record) do
          tag("tr", { "class" => index.even? ? "even" : "odd" }, :tr) do
            columns.each do |field|
              with_field(field) { tag("td", {}, :"#{field}_cell") { call_tag(painter, {}, :as => :"#{field}_view") } }
            end
            tag("td", { "class" => "controls" }, :controls) if all_parameters.key?(:controls)
          end
        end
      end
    end
  end
end

# `<table-plus>`: the table, a search box over it, and headings that sort.
#
# Thin on purpose. In Hobo 2 this was 58 lines because it built the sort links
# and the filters itself; here both are pieces that already exist and are tested
# on their own, so what is left is saying where they go.
Rapid.define(:table_plus, :attrs => [:fields, :sort_columns]) do
  rest = all_attributes.except(:sort_columns, "sort_columns")

  tag("div", { "class" => "table-plus" }, :table_plus) do
    tag("div", { "class" => "header" }, :header) do
      tag("div", { "class" => "search" }) do
        call_tag(:search_filter, {}, :as => :search_filter)
      end
    end

    # The headings go in **as params of the call**, which is how a param
    # works: supplied when the tag is called, not patched afterwards. Same
    # piece the `sortable_headings` verb uses, so the two cannot disagree about
    # which arrow means what.
    model = HoboRapid::Sorting.model_of(this)
    headings = model ? HoboRapid::Sorting.headings_for(model, Array(attributes[:sort_columns])) : {}

    # `merge_params`, que es lo que ponia Hobo 2 (`<table merge-params>`) y
    # faltaba aqui.
    #
    # Los params de columna --`<codigo-view:>`, `<estado-view:>`-- se los pasa la
    # plantilla a **este** tag, y quien los reclama es el `<table>` de dentro. Sin
    # reenviarlos se quedaban a medio camino, sin decir nada, y cada celda salia
    # con su pintor por defecto: el listado de expedientes de amenti perdia los
    # enlaces de todas sus columnas. Es la forma corriente de retocar un listado,
    # asi que sin esto `<table-plus>` no se puede usar para lo que se usa.
    call_tag(:table, rest.merge(:empty => true), :as => :table, :merge_params => true, **headings)

    # Y las dos cosas que hacen que esto sea el «plus» y no una tabla.
    #
    # Faltaban las dos, y las dos estaban escritas: `<table empty>` pinta la
    # tabla aunque no haya filas, asi que sin el mensaje lo que se ve es una
    # cabecera sola y ni una palabra de por que. Y sin la barra de paginas, de
    # una coleccion de 4.000 expedientes se ven treinta y **no hay forma de
    # llegar a los demas** -- que es justo lo que un listado paginado tiene que
    # resolver. En Hobo 2 iban aqui dentro, detras de la tabla.
    #
    # Cuando pintarse lo decide cada una: el mensaje mira si hay filas y la
    # barra si hay mas de una pagina. Por eso se llaman siempre.
    call_tag(:empty_collection_message, {}, :as => :empty_message) if Array(this).empty?
    call_tag(:page_nav, {}, :as => :page_nav)
  end
end
