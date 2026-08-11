require "test_helper"
require "hobo_rapid/derivation"

# El censo del catálogo: **los 36 tags, todos, pintados al menos una vez**.
#
# La suite tenía pruebas buenas de los tags grandes y ninguna de varios de los
# pequeños. Un tag que nadie pinta nunca es un tag que puede llevar meses roto:
# no falla nada porque no lo llama nadie, hasta que una página derivada lo llama
# y la página entera se cae.
#
# Así que esto no prueba lo que hace cada tag -- para eso están sus pruebas --
# sino cuatro cosas que valen para todos:
#
#   - **está en el censo**: un tag nuevo sin su ficha aquí hace fallar la prueba,
#     y añadir la ficha es escribir cómo se pinta, que es lo que faltaba
#   - **se pinta sin reventar**
#   - **lo que sale es html cerrado**: sin esto, un `param` que se come su
#     etiqueta de cierre no lo nota nadie hasta que el navegador reordena media
#     página
#   - **no se escapa un objeto de Ruby a la página**: `#<Story:0x00007f…>` es lo
#     que sale de un `to_s` que nadie quiso
class CatalogueCensusTest < Minitest::Test

  Dir[File.expand_path("../../lib/hobo_rapid/tags/*.rb", __dir__)].each { |file| require file }

  # --- de qué se pinta -------------------------------------------------------------

  class Task

    attr_accessor :id, :title, :done

    def initialize(id = nil, title = nil, done = nil) = (@id, @title, @done = id, title, done)
    def self.field_specs = { :title => nil, :done => nil }
    def self.name_attribute = :title
    def self.attr_type(field) = { "title" => String, "done" => Rapid::Boolean }[field.to_s]
    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = true
    def destroyable_by?(_user) = true

  end

  class Story

    attr_accessor :id, :title, :body, :published_on, :tasks, :category

    def self.field_specs = { :title => nil, :body => nil, :published_on => nil, :tasks => nil }
    def self.name_attribute = :title
    def self.attr_type(field)
      { "title" => String, "body" => String, "published_on" => Date, "tasks" => Array }[field.to_s]
    end
    def self.view_hints = self
    def self.children = [:tasks]
    def self.human_attribute_name(field) = field.to_s.humanize
    # Como el de ActiveModel: los tags preguntan por el nombre traducible del
    # modelo, no por el de la clase.
    def self.model_name = ModelName.new

    class ModelName

      def human(count: 1, **) = count.to_i > 1 ? "Historias" : "Historia"
      def to_s = "Story"
      def param_key = "story"
      def route_key = "stories"
      def singular_route_key = "story"
      def element = "story"
      def collection = "stories"

    end

    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = true
    def destroyable_by?(_user) = true
    def errors = @errors ||= Errors.new
    def to_s = title.to_s

    class Errors

      def full_messages = ["El titulo no puede estar vacio"]
      def empty? = false
      def any? = true
      def [](_field) = []
      def count = 1
      def size = 1
      def each(&block) = full_messages.each(&block)
      def to_a = full_messages

    end

  end

  class Collection < Array

    def member_class = Story

  end

  def story
    @story ||= Story.new.tap do |s|
      s.id = 1
      s.title = "Primera historia"
      s.body = "El cuerpo"
      s.published_on = Date.new(2026, 8, 10)
      s.tasks = [Task.new(1, "Una tarea", true)]
      # Un campo que vale **un registro**, que es lo que edita un <select-one>:
      # sobre un campo de texto pide un `id` que un String no tiene, y con
      # razon.
      s.category = Task.new(2, "Una categoria", false)
    end
  end

  def collection = @collection ||= Collection.new([story])

  # --- el censo -----------------------------------------------------------------
  #
  # Cada tag dice **desde dónde** se pinta:
  #
  #   :field      dentro de un campo de un registro (lo que hacen <view> e <input>)
  #   :field_record      un campo que vale un registro (lo que edita <select-one>)
  #   :field_collection  un campo que vale una lista (lo que edita <input-many>)
  #   :record     con un registro delante
  #   :collection con una lista delante
  #   :nothing    sin contexto: los de la página
  #
  # y, si hace falta, con qué atributos. Una ficha de una línea por tag es
  # justamente la documentación que no había.
  CENSUS = {
    # --- el resto del catalogo, portado el 2026-08-11 -----------------------------
    :labelled_item => [:nothing, {}],
    :item_label => [:nothing, {}],
    :item_value => [:nothing, {}],
    :labelled_item_list => [:nothing, {}],
    :feckless_fieldset => [:nothing, { :legend => "Datos" }],
    :name => [:record, {}],
    :collection_name => [:collection, {}],
    :collection_preview => [:collection, {}],
    :preview_with_more => [:collection, {}],
    :links_for_collection => [:collection, {}],
    :select_menu => [:field, { :options => %w[uno dos] }],
    :select_input => [:field, { :options => %w[uno dos] }],
    :select_many => [:field_collection, { :options => [] }],
    :input_all => [:record, {}],
    :hidden_id_field => [:record, {}],
    :gravatar => [:nothing, { :email => "a@b.c" }],
    :new_page => [:record, {}],
    :edit_page => [:record, {}],
    :after_submit => [:nothing, { :go_to => "/" }],
    # --- los de collections/, portados de Hobo 2 el 2026-08-11 --------------------
    :collection => [:collection, {}],
    :empty_collection_message => [:nothing, {}],
    :count => [:collection, { :label => "historias" }],
    :page_nav => [:collection, {}],
    :delete_button => [:record, {}],
    :create_button => [:record, {}],
    :update_button => [:record, {}],
    :transition_link => [:record, { :transition => "publish" }],
    :nil_view => [:nothing, {}],
    :hidden_field => [:nothing, { :name => "x", :value => "1" }],
    :hidden_fields => [:record, { :fields => "title" }],
    # --- los de forms/, portados de Hobo 2 el 2026-08-11 --------------------------
    :field_list => [:record, { :fields => "title, body" }],
    :form => [:record, {}],
    :formlet => [:record, {}],
    :submit => [:nothing, { :label => "Guardar" }],
    :or_cancel => [:record, {}],
    # --- los de html/, portados de Hobo 2 el 2026-08-11 ---------------------------
    #
    # No son elementos: DRYML decide con una lista (`static_tags`) y estos estan
    # fuera de ella, asi que una plantilla que escribe `<a>` o `<img>` esta
    # llamando a un tag.
    :empty_tag => [:nothing, { :tag_name => "br" }],
    :a => [:record, {}],
    :header => [:nothing, {}],
    :footer => [:nothing, {}],
    :section => [:nothing, {}],
    :aside => [:nothing, {}],
    :nav => [:nothing, {}],
    :section_group => [:nothing, {}],
    :doctype => [:nothing, {}],
    :html => [:nothing, {}],
    :if_ie => [:nothing, { :version => "lt 9" }],
    :image => [:nothing, { :name => "logo.png" }],
    :account_nav => [:nothing, {}],
    :app_name => [:nothing, {}],
    :card => [:record, {}],
    :check_many => [:field_collection, { :options => [] }],
    :collection_view => [:collection, {}],
    :dev_user_changer => [:nothing, {}],
    :error_messages => [:record, {}],
    :filter_menu => [:collection, { :field => :title, :options => %w[uno dos] }],
    :first_user_form => [:nothing, { :action => "/" }],
    :flash_message => [:nothing, { :type => "notice" }],
    :flash_messages => [:nothing, {}],
    :form_page => [:record, {}],
    :front_page => [:nothing, { :app_name => "Prueba", :action => "/" }],
    :index_page => [:collection, {}],
    :input => [:field, {}],
    :input_content => [:field, {}],
    :input_many => [:field_collection, {}],
    :javascript => [:nothing, { :name => "application" }],
    :main_nav => [:nothing, {}],
    :model_form => [:record, {}],
    :name_view => [:record, {}],
    :page => [:nothing, { :title => "Prueba" }],
    :record_actions => [:record, {}],
    :record_view_content => [:record, {}],
    :search_box => [:nothing, {}],
    :search_filter => [:collection, { :fields => [:title] }],
    :search_results => [:nothing, { :query => "hola", :results => {} }],
    :select_one => [:field_record, { :options => [] }],
    :select_one_or_new => [:field_record, { :options => [] }],
    # Y el de marcar muchos, sobre una coleccion.
    :session_links => [:nothing, {}],
    :show_page => [:record, {}],
    :signup_form => [:nothing, { :action => "/", :fields => [] }],
    :stylesheet => [:nothing, { :name => "application" }],
    :transition_buttons => [:record, {}],
    :view => [:field, {}],
    :view_content => [:field, {}],
  }.freeze

  def paint(name)
    where, attributes = CENSUS.fetch(name)
    outer = Rapid::Tag.new

    Rapid::Context.capture do
      case where
      when :field then outer.with_field(:title, story) { outer.call_tag(name, attributes) }
      when :field_collection then outer.with_field(:tasks, story) { outer.call_tag(name, attributes) }
      when :field_record then outer.with_field(:category, story) { outer.call_tag(name, attributes) }
      when :record then outer.with_this(story) { outer.call_tag(name, attributes) }
      when :collection then outer.with_this(collection) { outer.call_tag(name, attributes) }
      else outer.call_tag(name, attributes)
      end
    end
  end

  # El catálogo **de la gema**, y no lo que haya en el registro.
  #
  # El registro es global y una definición dura lo que dura el proceso, así que
  # corriendo la suite entera aquí aparecían los tags de las otras pruebas
  # -- `spike_page`, `tag_index_probe`, `naive_outer` -- y el censo pedía ficha
  # para ellos. Cada definición guarda de dónde salió, que es justo para esto.
  CATALOGUE_PATH = File.expand_path("../../lib/hobo_rapid", __dir__)

  def catalogue
    Rapid.definitions
         .select { |d| d.kind == :define && d.source.to_s.start_with?(CATALOGUE_PATH) }
         .map(&:name).uniq
  end

  # --- lo que se comprueba de todos ---------------------------------------------

  # La prueba que avisa: un tag nuevo sin ficha es un tag que nadie pinta.
  def test_every_tag_in_the_catalogue_is_in_the_census
    faltan = catalogue - CENSUS.keys

    assert_empty faltan, "tags sin ficha en el censo (nadie los pinta): #{faltan.join(', ')}"
  end

  # Y al revés: una ficha de un tag que ya no existe es una ficha que engaña.
  def test_the_census_has_no_ghosts
    fantasmas = CENSUS.keys - catalogue

    assert_empty fantasmas, "fichas de tags que ya no existen: #{fantasmas.join(', ')}"
  end

  def test_every_tag_paints
    catalogue.each do |name|
      html = paint(name)

      assert_kind_of String, html, "<#{name}> no ha devuelto texto"
    end
  end

  # Html cerrado. No es una comprobación de estilo: una etiqueta sin cerrar la
  # arregla el navegador moviendo lo que venga detrás, así que el fallo no se ve
  # donde está.
  def test_every_tag_leaves_closed_html
    catalogue.each do |name|
      pendientes = unclosed(paint(name))

      assert_empty pendientes, "<#{name}> deja sin cerrar: #{pendientes.join(', ')}"
    end
  end

  # Un objeto de Ruby en la página es un `to_s` que nadie quiso: sale como
  # `#<Story:0x00007f…>` y lo ve el usuario.
  def test_no_tag_leaks_a_ruby_object
    catalogue.each do |name|
      refute_match(/#<[A-Z]\w*[: ]0x/, paint(name), "<#{name}> ha escrito un objeto de Ruby en la pagina")
    end
  end

  private

  # Las etiquetas abiertas que nadie cerró. Se conocen las vacías de HTML, que se
  # escriben sin cierre a propósito.
  def unclosed(html)
    abiertas = []

    html.scan(%r{<(/?)([a-zA-Z][\w-]*)[^>]*?(/?)>}) do |cierre, nombre, suelta|
      next if Rapid::Tag::VOID_ELEMENTS.include?(nombre.downcase) || !suelta.empty?

      if cierre.empty?
        abiertas << nombre
      elsif abiertas.last == nombre
        abiertas.pop
      else
        abiertas << "</#{nombre}> sin abrir"
      end
    end

    abiertas
  end

end
