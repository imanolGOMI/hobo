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
  GEMS = %w[hobo_support hobo_fields dryml hobo].freeze

  class << self

    def built? = File.exist?(File.join(PATH, "config", "environment.rb"))

    def why_not
      "no hay aplicacion de pruebas en #{PATH}: montala con `cd hobo && rake test:app`"
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
      end

      Dir.chdir(PATH) { sh "bundle install" }
      puts "aplicacion de pruebas lista en #{PATH}"
    end

    private

    def sh(command)
      puts command
      raise "fallo: #{command}" unless system(command)
    end

  end

end
