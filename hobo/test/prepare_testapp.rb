# Builds a plain Rails application in tmp with the four gems wired in, so the
# parts that need routing, a request and a rendered response can be checked for
# real. It is a *plain* application on purpose: `hobo new` belongs to layer 7,
# and this has to work before that does.
#
#   cd hobo && rake test:app        # build it (once)
#   cd hobo && rake test:app force=1
#
# The tests that use it skip, loudly, when it is not there. They never pass by
# default -- the same rule as the multi-adapter battery of layer 2.

require "fileutils"
require "tmpdir"

module TestApp

  # Outside the gem tree on purpose. An application nested inside the engine's
  # own directory makes Zeitwerk refuse to start: the engine registers
  # hobo/app/* as autoload roots and the application registers its own, and one
  # ends up inside the other.
  PATH = ENV["HOBO_TESTAPP_PATH"] || File.join(Dir.tmpdir, "hobo_testapp")
  # One gem now (decision 11). This used to list five.
  GEMS = %w[hobo].freeze

  # The example plugin (piece 17), in a Bundler group of its own.
  #
  # The contract says installing a plugin is adding the gem and *nothing else*,
  # and the only way to check a claim like that is to have the same application
  # with the gem and without it. A group Rails does not require by default gives
  # both from one bench: `RAILS_GROUPS=hobo_plugin bin/rails runner ...` loads
  # it, a plain run does not.
  PLUGINS = %w[hobo_timeago].freeze
  PLUGIN_GROUP = "hobo_plugin".freeze

  class << self

    def built? = File.exist?(File.join(PATH, "config", "environment.rb"))

    # Two gems' integration tests share this application, and each one writes
    # the models and views it needs and takes them away afterwards -- in an
    # `ensure`, which covers an exception and does **not** cover the process
    # being killed. A leftover `app/models/story.rb` from an interrupted run is
    # then autoloaded by the next one, and what fails is somebody else's test,
    # in another gem, with a message about a column that was never asked for.
    #
    # That cost a puzzled half hour. Sweeping first is cheaper than reading that
    # message again.
    def sweep
      return unless built?
      Dir[File.join(PATH, "app", "models", "*.rb")].each do |file|
        FileUtils.rm_f(file) unless File.basename(file) == "application_record.rb"
      end
      FileUtils.rm_rf(File.join(PATH, "app", "views", "stories"))
      FileUtils.rm_rf(File.join(PATH, "app", "controllers", "admin"))
      FileUtils.rm_f(File.join(PATH, "tmp", "probe.rb"))
    end

    def why_not
      "no hay aplicacion de pruebas en #{PATH}: montala con `cd hobo && rake test:app`"
    end

    # A command **inside the test application**, with the gem's own bundle out
    # of the way.
    #
    # Run the suite with `bundle exec` -- which is how anybody runs it -- and
    # BUNDLE_GEMFILE names this gem's Gemfile. Every `bin/rails` launched from a
    # test inherits it, so the application boots against *this* gem's
    # dependencies: no propshaft, and it dies in `config/environments/
    # development.rb` with `undefined method 'assets'`, a file nobody in this
    # repository wrote. Five integration tests failed at once with a message
    # that pointed nowhere near the cause.
    def run(command)
      full = "cd #{PATH} && #{command} 2>&1"
      defined?(Bundler) ? Bundler.with_unbundled_env { `#{full}` } : `#{full}`
    end

    def build(force: false)
      FileUtils.rm_rf(PATH) if force
      return puts("ya existe en #{PATH}") if built?

      root = File.expand_path("../..", __dir__)
      FileUtils.mkdir_p(File.dirname(PATH))

      sh %(rails new #{PATH} --skip-git --skip-test --skip-system-test --skip-bundle \
           --skip-javascript --skip-hotwire --skip-jbuilder --skip-action-cable \
           --skip-action-mailbox --skip-action-text --skip-active-storage --skip-bootsnap)

      File.open(File.join(PATH, "Gemfile"), "a") do |f|
        f.puts
        f.puts "# The gems under test, straight from the working tree."
        GEMS.each { |gem| f.puts %(gem "#{gem}", :path => "#{File.join(root, gem)}") }
        f.puts
        f.puts "# The browser bench for the Stimulus controllers (test/hobo_rapid/browser)."
        f.puts %(group :test do)
        f.puts %(  gem "capybara")
        f.puts %(  gem "selenium-webdriver")
        f.puts %(end)
      end

      # Rails blocks requests whose Host it does not recognise, and a request
      # built with Rack::MockRequest has none it likes. It answers 403 through
      # the middleware, which looks exactly like a permission denied and is not.
      File.open(File.join(PATH, "config", "environments", "development.rb"), "a") do |f|
        f.puts
        f.puts "Rails.application.configure { config.hosts.clear }"
      end

      bundle_in(PATH)
      ensure_plugins
      fetch_stimulus
      puts "aplicacion de pruebas lista en #{PATH}"
    end

    # Adds the plugin group to a bench that was built before there was one, so
    # a working tree from last week does not have to be rebuilt from scratch --
    # and does nothing at all the second time.
    def ensure_plugins
      return false unless built?
      gemfile = File.join(PATH, "Gemfile")
      return false if File.read(gemfile).include?("group :#{PLUGIN_GROUP}")

      root = File.expand_path("../..", __dir__)
      File.open(gemfile, "a") do |f|
        f.puts
        f.puts "# The example plugin of piece 17. Not required by default: a test"
        f.puts "# boots this same application with and without it."
        f.puts %(group :#{PLUGIN_GROUP} do)
        PLUGINS.each { |gem| f.puts %(  gem "#{gem}", :path => "#{File.join(root, gem)}") }
        f.puts %(end)
      end
      bundle_in(PATH)
      true
    end

    # `bundle install` **for the application**, and this is not the same as
    # running it in its directory: `bundle exec rake test:app` exports
    # BUNDLE_GEMFILE pointing at the gem's own Gemfile, the child bundler obeys
    # it, and what gets installed is this gem's dependencies again. The
    # application ends up with no Gemfile.lock and no propshaft, and it fails
    # much later with `undefined method 'assets'` in an environment file nobody
    # touched.
    #
    # `with_unbundled_env` is the whole fix: the child gets the environment of a
    # shell that never ran bundler.
    def bundle_in(path)
      Dir.chdir(path) do
        if defined?(Bundler)
          Bundler.with_unbundled_env { sh "bundle install" }
        else
          sh "bundle install"
        end
      end
    end

    # The Stimulus runtime, fetched once, so the browser tests load the
    # controllers through a real import map -- bare `@hotwired/stimulus` and all
    # -- exactly as an application does.
    def fetch_stimulus
      target = File.join(PATH, "public", "vendor", "stimulus.js")
      return if File.exist?(target)

      FileUtils.mkdir_p(File.dirname(target))
      Dir.mktmpdir do |tmp|
        Dir.chdir(tmp) { sh "npm pack @hotwired/stimulus" }
        archive = Dir[File.join(tmp, "*.tgz")].first
        sh %(tar xzf #{archive} -C #{tmp})
        FileUtils.cp(File.join(tmp, "package", "dist", "stimulus.js"), target)
      end
      puts "stimulus en #{target}"
    end

    private

    def sh(command)
      puts command
      raise "fallo: #{command}" unless system(command)
    end

  end

end
