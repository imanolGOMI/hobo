require "test_helper"
require "hobo/plugins"
require "tmpdir"
require "fileutils"

# Como se entera Hobo de que existe un plugin.
#
# La respuesta corta: **no se entera, se lo dicen**. Una gema pone
# `s.metadata["hobo_plugin"]` en su gemspec y con eso el asistente la ofrece.
# Nadie escribe una lista de temas ni de comportamientos dentro de Hobo, que es
# lo que habia y lo que hacia que un plugin de otro no pudiera existir.
class PluginsTest < Minitest::Test

  def setup
    @root = Dir.mktmpdir("hobo_plugins")
    # HOBODEV apunta a la carpeta de las gemas, y los plugins pueden estar ahi
    # dentro o al lado -- que es como esta el arbol de verdad.
    @dev = File.join(@root, "gemas")
    FileUtils.mkdir_p(@dev)
    @previous = ENV["HOBODEV"]
    ENV["HOBODEV"] = @dev
    Hobo::Plugins.reset
  end

  def teardown
    ENV["HOBODEV"] = @previous
    Hobo::Plugins.reset
    FileUtils.remove_entry(@root)
  end

  # Un gemspec de mentira, del tamaño justo para que rubygems lo cargue.
  def gem_at(dir, name, metadata: nil, summary: "Una gema")
    FileUtils.mkdir_p(File.join(dir, name))
    File.write(File.join(dir, name, "#{name}.gemspec"), <<~RUBY)
      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = "1.0.0"
        s.authors = ["Nadie"]
        s.summary = #{summary.inspect}
        #{"s.metadata = #{metadata.inspect}" if metadata}
      end
    RUBY
    Hobo::Plugins.reset
  end

  def found(kind) = Hobo::Plugins.of(kind).map(&:name)

  def test_a_gem_that_says_it_is_a_theme
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" })

    assert_equal %w[verde], found(:theme)
  end

  def test_and_one_that_says_it_runs_the_behaviour
    gem_at(@dev, "hobo_jquery", :metadata => { "hobo_plugin" => "behaviour" })

    assert_equal %w[jquery], found(:behaviour)
    assert_empty found(:theme)
  end

  # Lo que distingue el `hobo_jquery` nuevo del de Hobo 2, que sigue en el
  # arbol: el viejo no dice que es un plugin, porque cuando se escribio esto no
  # existia. Sin nombrar a ninguno de los dos.
  def test_a_gem_that_does_not_say_it_is_not_offered
    gem_at(@dev, "hobo_lo_que_sea")

    assert_empty Hobo::Plugins.all
  end

  # El nombre del plugin es el de la gema sin `hobo_`: es como se responde la
  # pregunta y como el plugin se apunta en el registro al cargarse.
  def test_the_name_is_the_gem_without_the_prefix
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" })

    assert_equal "hobo_verde", Hobo::Plugins.all.first.gem_name
    assert_equal "verde", Hobo::Plugins.all.first.name
  end

  # El resumen del gemspec es lo que se lee al lado de la respuesta. Sin el, la
  # pregunta es una lista de nombres de gema.
  def test_the_summary_is_what_the_question_shows
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" }, :summary => "El tema verde")

    assert_equal "El tema verde", Hobo::Plugins.all.first.describe
  end

  # Un plugin que se esta escribiendo entra en el Gemfile por `path:`, como hace
  # `hobo new` con la gema principal. Uno instalado, por su nombre.
  def test_a_plugin_from_the_working_tree_goes_in_by_path
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" })
    plugin = Hobo::Plugins.all.first

    assert_equal File.join(@dev, "hobo_verde"), plugin.path
    assert_includes plugin.gem_line, %(path: "#{File.join(@dev, "hobo_verde")}")
  end

  # Los plugins no viven dentro de la carpeta de las gemas sino al lado, porque
  # el repositorio principal todavia tiene dentro los de Hobo 2.
  def test_the_folder_next_door_counts_too
    gem_at(@root, "hobo_azul", :metadata => { "hobo_plugin" => "theme" })

    assert_equal %w[azul], found(:theme)
  end

  # Las hojas de estilo las pide el tema, que es quien sabe cuantas son. Si no
  # dice nada, una que se llama como el.
  def test_a_theme_says_which_stylesheets_it_needs
    gem_at(@dev, "hobo_bootstrap",
           :metadata => { "hobo_plugin" => "theme", "hobo_plugin_stylesheets" => "bootstrap hobo" })

    assert_equal %w[bootstrap hobo], Hobo::Plugins.all.first.stylesheets
  end

  def test_and_by_default_one_with_its_own_name
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" })

    assert_equal %w[verde], Hobo::Plugins.all.first.stylesheets
  end

  # Un gemspec roto es problema de su gema. El asistente no se cae por el.
  def test_a_broken_gemspec_is_ignored
    FileUtils.mkdir_p(File.join(@dev, "hobo_roto"))
    File.write(File.join(@dev, "hobo_roto", "hobo_roto.gemspec"), %(hobo_plugin\nraise "boom"))
    Hobo::Plugins.reset

    assert_empty Hobo::Plugins.all
  end

  # Y sin HOBODEV no se mira ningun arbol de trabajo: eso es cosa de quien esta
  # escribiendo Hobo, no de quien lo usa.
  def test_without_hobodev_there_is_no_working_tree
    gem_at(@dev, "hobo_verde", :metadata => { "hobo_plugin" => "theme" })
    ENV.delete("HOBODEV")
    Hobo::Plugins.reset

    assert_empty found(:theme)
  end

end
