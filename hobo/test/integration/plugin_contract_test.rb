require "test_helper"
require_relative "../prepare_testapp"

# The plugin contract (piece 17), checked in a real application.
#
# The claim is one sentence: **a plugin is a Rails engine that defines tags and
# ships assets, and installing it is adding the gem.** Hobo 2's plugins needed
# four edits per subsite -- the Gemfile, a `//= require` in the JavaScript, a
# `*= require` in the stylesheet and an `<include gem="...">` in the site
# taglib -- because a DRYML tag lived in a file somebody had to name. A Ruby tag
# is registered by being defined, so three of those four have nothing left to do.
#
# A claim of the form "and nothing else" cannot be checked by looking at what
# happens; it is checked by looking at what happens **without** it. So the bench
# carries the plugin in a Bundler group Rails does not require by default, and
# every test here boots the same application twice.
#
#   cd hobo && rake test:app
class PluginContractTest < Minitest::Test

  PLUGIN = "hobo_timeago".freeze
  DATE = "Date.new(2026, 8, 1)".freeze

  def setup
    skip TestApp.why_not unless TestApp.built?
    TestApp.sweep
    TestApp.ensure_plugins
  end

  # --- installing -------------------------------------------------------------

  # Nothing in this application mentions the plugin. Its date view is in force
  # because its gem is in the Gemfile, and that is the whole of the contract.
  def test_the_gem_being_there_is_the_installation
    assert_includes with_plugin(%(print Rapid.render(:view_content, {}, :this => #{DATE}))), "<time"
  end

  def test_and_without_the_gem_the_catalogue_paints_it
    assert_equal "2026-08-01", without_plugin(%(print Rapid.render(:view_content, {}, :this => #{DATE})))
  end

  # No initializer, no generator, no taglib: the application's own files are the
  # same in both runs. If installing a plugin ever needs a line somewhere, this
  # is the test that has to be changed first.
  def test_the_application_is_not_edited_to_install_a_plugin
    files = Dir[File.join(TestApp::PATH, "config", "initializers", "*.rb")] +
            Dir[File.join(TestApp::PATH, "app", "views", "taglibs", "*")]

    files.each do |file|
      refute_includes File.read(file), PLUGIN, "#{file} nombra al plugin"
    end
  end

  # --- what the engine brings --------------------------------------------------

  # The tags. `Rapid.definitions` is the runtime's own record, made at the point
  # of definition, so this is not asking the plugin whether it registered.
  def test_the_tags_of_the_plugin_are_in_the_catalogue
    assert_equal "3", with_plugin(<<~RUBY)
      print Rapid.definitions.count { |d| d.source.to_s.include?("#{PLUGIN}") }
    RUBY

    assert_equal "0", without_plugin(<<~RUBY)
      print Rapid.definitions.count { |d| d.source.to_s.include?("#{PLUGIN}") }
    RUBY
  end

  # The stylesheet, from the gem, without the application copying anything.
  def test_the_assets_of_the_plugin_are_on_the_path
    assert_equal "true", with_plugin(<<~RUBY)
      print Rails.application.config.assets.paths.any? { |p| p.to_s.include?("#{PLUGIN}") }
    RUBY
  end

  # And the Stimulus controller, if this application has an import map at all --
  # the bench is built with --skip-javascript, so this is worth asking about
  # rather than assuming.
  def test_the_import_map_of_the_plugin_is_merged
    output = with_plugin(<<~RUBY)
      config = Rails.application.config
      if config.respond_to?(:importmap)
        print config.importmap.paths.any? { |p| p.to_s.include?("#{PLUGIN}") }
      else
        print "sin importmap"
      end
    RUBY

    assert_includes ["true", "sin importmap"], output
  end

  # --- seeing it ----------------------------------------------------------------

  # A plugin that replaces a tag of the catalogue leaves the replaced definition
  # in the record, and `bin/rails hobo:tags` is where an application sees that a
  # name has two owners. Without it, a gem quietly repainting every date in the
  # application looks exactly like no gem at all.
  def test_the_tag_listing_names_the_plugin_and_what_it_replaced
    output = rails("hobo:tags", :groups => TestApp::PLUGIN_GROUP)

    assert_includes output, "#{PLUGIN}/lib/hobo_timeago/tags.rb"
    assert_match(/for Date\s+shadowed\s+hobo\/lib\/hobo_rapid\/tags\/views\.rb/, output)

    # An engine loads its own `lib/tasks/**/*.rake`, so saying it again with
    # `rake_tasks { load ... }` defined the task twice -- and rake *adds* the
    # second body to the first instead of replacing it, so the whole catalogue
    # came out twice.
    assert_equal 1, output.scan(/\d+ tags, \d+ definitions/).size
  end

  def test_the_tag_listing_is_the_catalogue_when_there_is_no_plugin
    output = rails("hobo:tags")

    refute_includes output, PLUGIN
    assert_includes output, "hobo/lib/hobo_rapid/tags/views.rb"
    refute_includes output, "shadowed", "sin plugins no hay dos duenos de un nombre"
  end

  private

  def with_plugin(script) = runner(script, :groups => TestApp::PLUGIN_GROUP)

  def without_plugin(script) = runner(script)

  def runner(script, groups: nil)
    file = File.join(TestApp::PATH, "tmp", "probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    rails("runner #{file}", :groups => groups)
  ensure
    FileUtils.rm_f(file)
  end

  def rails(command, groups: nil)
    env = groups ? "RAILS_GROUPS=#{groups} " : ""
    `cd #{TestApp::PATH} && #{env}bin/rails #{command} 2>&1`.strip
  end

end
