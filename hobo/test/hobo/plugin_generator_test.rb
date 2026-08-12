require "test_helper"
require "rails/generators"
require "generators/hobo/plugin/plugin_generator"
require "tmpdir"
require "fileutils"

# What `rails generate hobo:plugin` leaves behind.
#
# A plugin is a gem (decisión 22), and this writes the smallest one that works:
# an engine, a file of tags and its assets. The test generates one into a
# temporary directory, loads it, and takes it away again -- there is no plugin
# lying around afterwards and nothing to remember to clean.
class PluginGeneratorTest < Minitest::Test

  def setup
    @dir = Dir.mktmpdir
    generator = Hobo::Generators::PluginGenerator.new(["hobo_ejemplo"], [], :destination_root => @dir)
    generator.shell.mute { generator.invoke_all }
  end

  def teardown
    FileUtils.remove_entry(@dir)
    HoboTest.clean_up(:HoboEjemplo)
  end

  def path(*parts) = File.join(@dir, "hobo_ejemplo", *parts)

  def test_it_writes_a_gem
    assert File.exist?(path("hobo_ejemplo.gemspec"))
    assert File.exist?(path("VERSION"))
    assert File.exist?(path("Rakefile"))
    assert_includes File.read(path("hobo_ejemplo.gemspec")), %(add_runtime_dependency("hobo"))
  end

  # The three pieces of the contract, and no fourth.
  def test_it_writes_an_engine_a_file_of_tags_and_its_assets
    assert File.exist?(path("lib", "hobo_ejemplo", "engine.rb"))
    assert File.exist?(path("lib", "hobo_ejemplo", "tags.rb"))
    assert File.exist?(path("app", "assets", "stylesheets", "hobo_ejemplo.css"))
    assert File.exist?(path("app", "javascript", "controllers", "hobo_ejemplo_controller.js"))
    assert File.exist?(path("config", "importmap.rb"))
  end

  # The import map is the whole of the JavaScript wiring, and it is wrong in a
  # way nothing would notice: a controller not pinned under `controllers/` with
  # that name is never loaded by anybody.
  def test_the_controller_is_pinned_where_the_application_looks
    assert_includes File.read(path("config", "importmap.rb")),
                    %(pin "controllers/hobo_ejemplo_controller")
  end

  # And the thing itself: load what was written, and the tag is in the
  # catalogue. Defining a tag **is** installing it.
  def test_what_it_writes_defines_a_tag
    $LOAD_PATH.unshift(path("lib"))
    require "hobo_ejemplo"

    assert_includes Rapid.render(:hobo_ejemplo), "Hola"
    assert_includes Rapid.definitions_for(:hobo_ejemplo).last.source.to_s, "hobo_ejemplo"
  ensure
    $LOAD_PATH.delete(path("lib"))
  end

end
