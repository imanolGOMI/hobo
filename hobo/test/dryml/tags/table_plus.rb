# Spike C -- a real, large tag ported to the Ruby DSL of spike A.
#
# <table-plus> was picked because it is the worst case in hobo_rapid: it uses
# dynamic param names, merge-params, all_parameters, attrs_for, scoped
# variables, control attributes and dashed attribute names, all in 58 lines.
# If the DSL survives this it survives the catalogue.
#
#   ruby spike/dryml/c_table_plus.rb
#
# The original is hobo_rapid/taglibs/plus/table_plus.dryml.

# Runnable on its own, so it sets the load path up the way the Rakefile does.
$LOAD_PATH.unshift File.expand_path("../../../hobo_support/lib", __dir__)

require "cgi"
require "rapid"
require_relative "rapid_helpers"

# --- the tags <table-plus> leans on, stubbed just enough to render ------------

Rapid.define(:spike_search_filter, :attrs => [:query]) do
  tag("form", { :class => "search" }.merge(attributes)) do
    tag("input", { :type => "search", :name => "search" })
  end
end

Rapid.define(:empty_collection_message) do
  tag("p", { :class => "empty" }) { text "Nothing here" } if Array(this).empty?
end

Rapid.define(:page_nav) do
  tag("nav", { :class => "pagination" }.merge(attributes)) { text "1 2 3" }
end

# <with-field-names> iterates the field names and sets `scope` for each, which
# is what the heading row of the table walks over.
Rapid.define(:with_field_names, :attrs => [:fields]) do
  comma_split(attributes[:fields]).each do |field_name|
    with_scope(:field_name => field_name, :field_path => field_name) do
      param(:default)
    end
  end
end

# A cut-down <table>: enough to show merge-params and a parameter tag with body.
# `spike_table` y no `table`: **el registro de tags es global**.
#
# Este fichero es un spike y sus tags eran una version recortada de los de
# verdad. Mientras el catalogo no tenia `<table>` daba igual; desde que la
# pagina derivada llama al `<table>` del catalogo, la del spike se lo comia --
# gana el que cargue el ultimo -- y la lista de un `index-page` salia sin clase,
# sin cabeceras y con el registro en crudo en cada celda. Fallaba en otra suite,
# nunca aqui, y solo al correrlas juntas.
#
# Es el mismo motivo por el que los otros tres se llaman `spike_*`, dicho ya en
# `rapid_fixtures.rb`; a estos dos les faltaba el cambio.
Rapid.define(:spike_table, :attrs => [:fields, :empty]) do
  tag("table", attributes.except(:fields, :empty)) do
    tag("thead") { param(:field_heading_row) }
    tag("tbody") do
      Array(this).each do |record|
        with_this(record) { tag("tr") { param(:row) { tag("td") { text this.to_s } } } }
      end
    end
  end
end


# --- the port ----------------------------------------------------------------
#
# <def tag="table-plus" attrs="sort-field, sort-direction, sort-columns">

Rapid.define(:spike_table_plus, :attrs => [:sort_field, :sort_direction, :sort_columns]) do
  # <% sort_field ||= @sort_field; sort_columns ||= {} %>
  sort_field     = attributes[:sort_field]     || controller_ivar(:@sort_field)
  sort_direction = attributes[:sort_direction] || controller_ivar(:@sort_direction)
  sort_columns   = attributes[:sort_columns]   || {}
  sort_columns["this"] ||= this.try(:member_class).try(:name_attribute)

  # <% ajax_attrs, attributes = attributes.partition_hash(AJAX_ATTRS) %>
  ajax_attrs, other_attrs = attributes.partition_hash(RapidHelpers::AJAX_ATTRS)

  tag("div",
      { :class => "table-plus" }
        .merge(other_attrs.except(*attrs_for(:with_field_names), *attrs_for(:table))),
      :none) do

    tag("div", { :class => "header" }, :header) do
      tag("div", { :class => "search" }) do
        call_tag(:spike_search_filter, ajax_attrs, :as => :search_filter)
      end
    end

    # <table merge-attrs="..." empty merge-params param>
    call_tag(:spike_table,
             other_attrs.slice(*attrs_for(:table), *attrs_for(:with_field_names))
               .merge(:empty => true),
             :as => :table,
             :merge_params => true,
             # <field-heading-row:> ... </field-heading-row>
             :field_heading_row => proc {
               call_tag(:with_field_names,
                        all_attributes.slice(*attrs_for(:with_field_names)),
                        :default => proc {
                          col = sort_columns[scope.field_path] || scope.field_path
                          sort = (sort_field == col && sort_direction == "asc") ? "-#{col}" : col
                          sort_url = "?sort=#{CGI.escape(sort)}"
                          heading = this.try(:member_class).try(:human_attribute_name, scope.field_name) ||
                                    scope.field_name.to_s.capitalize

                          # param="#{scope.field_name}-heading" -- a param whose
                          # name is computed at render time.
                          tag("th", {}, :"#{scope.field_name}_heading") do
                            tag("a",
                                { :href => sort_url, :class => "column-sort" }.merge(ajax_attrs),
                                :"#{scope.field_name}_heading_link") { text heading }
                            if col == sort_field
                              param(:up_arrow)   { raw "&uarr;" } if sort_direction == "desc"
                              param(:down_arrow) { raw "&darr;" } if sort_direction == "asc"
                            end
                          end
                        })
               # <th if="&all_parameters[:controls]" class="controls"></th>
               tag("th", { :class => "controls" }) if all_parameters[:controls]
             })

    call_tag(:empty_collection_message, {}, :as => :empty_message)

    if this.respond_to?(:page_count) || this.respond_to?(:total_pages)
      call_tag(:page_nav, ajax_attrs, :as => :page_nav)
    end
  end
end


# --- rendering it ------------------------------------------------------------

if __FILE__ == $PROGRAM_NAME
  Story = Struct.new(:title, :status) do
    def self.name_attribute = :title
    def self.human_attribute_name(name) = name.to_s.capitalize
  end

  class Collection < Array
    def member_class = Story
    def total_pages = 3
  end

  stories = Collection.new([Story.new("First", "draft"), Story.new("Second", "done")])

  puts "--- plain ---"
  puts Rapid.render(:table_plus,
                    { :fields => "title, status", :sort_field => "title", :sort_direction => "asc" },
                    :this => stories)

  puts
  puts "--- with a dynamic param overridden: title-heading ---"
  puts Rapid.render(:table_plus,
                    { :fields => "title, status", :sort_field => "title", :sort_direction => "asc" },
                    :this => stories,
                    :title_heading => Rapid.parameter(:attributes => { :class => "shouty" }) { text "TITLE!" })

  puts
  puts "--- a param of <table>, reached by nesting through the call to it ---"
  puts Rapid.render(:table_plus,
                    { :fields => "title", :sort_field => "title", :sort_direction => "asc" },
                    :this => stories,
                    :table => Rapid.parameter(
                      :params => { :row => Rapid.markup { tag("td", { :class => "mine" }) { text this.title } } }))

  puts
  puts "--- asking whether the caller supplied :controls (all_parameters) ---"
  puts Rapid.render(:table_plus,
                    { :fields => "title" },
                    :this => stories,
                    :controls => Rapid.markup { text "" })
end
