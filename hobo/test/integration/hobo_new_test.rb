require "test_helper"
require "fileutils"
require "tmpdir"

# `hobo new` from end to end: generate an application, migrate it, and ask it
# for a page.
#
# It builds a whole Rails application and runs bundler, so it takes a couple of
# minutes and does not run by default. It is the only test that checks the thing
# a person actually does first:
#
#   HOBO_TEST_NEW=1 rake test
class HoboNewTest < Minitest::Test

  ROOT = File.expand_path("../../..", __dir__)

  def setup
    skip "lento: ponle HOBO_TEST_NEW=1 para generar una aplicacion de verdad" unless ENV["HOBO_TEST_NEW"]
  end

  def test_hobo_new_leaves_an_application_that_serves_a_derived_page
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "prueba")

      output = run_command(tmp, "#{ROOT}/hobo/bin/hobo new prueba " \
                                "--skip-git --skip-test --skip-system-test --skip-javascript " \
                                "--skip-hotwire --skip-jbuilder --skip-action-cable " \
                                "--skip-action-mailbox --skip-action-text --skip-active-storage --skip-bootsnap")

      assert File.exist?(File.join(app, "config", "environment.rb")), "no se genero la aplicacion:\n#{output}"

      # The model and the controller, and **no views**: those are derived.
      assert File.exist?(File.join(app, "app", "models", "story.rb")), output
      assert File.exist?(File.join(app, "app", "controllers", "stories_controller.rb")), output
      assert_empty Dir[File.join(app, "app", "views", "stories", "*")],
                   "hobo new no deberia escribir vistas: las deriva"

      # The migration is written from the model, not by hand: one for Story, and
      # the two Rails' authentication generator brings.
      assert_equal 3, Dir[File.join(app, "db", "migrate", "*.rb")].length, output

      # And it is *run*. `hobo:migration` refuses to work while another
      # generator has left pending migrations, so this used to come out as an
      # application that answered 500 on its first page -- and quietly, because
      # the call was wrapped in `rescue nil`.
      File.write(File.join(app, "tmp", "pending.rb"),
                 "print ActiveRecord::Base.connection_pool.migration_context.needs_migration?")
      pending = run_command(app, "bin/rails runner tmp/pending.rb")

      assert_includes pending, "false", "hobo new deja migraciones sin correr:\n#{pending}"

      File.write(File.join(app, "tmp", "smoke.rb"), <<~RUBY)
        Story.create!(:title => "Hobo 2027", :body => "Sin escribir vistas")
        # The index of the model, not "/": since `hobo:front_page` joined the
        # template, the root of a fresh application is the page that asks for
        # the first user.
        env = Rack::MockRequest.env_for("http://localhost/stories")
        env["action_dispatch.show_exceptions"] = :none
        # Rails blocks a request whose Host it does not recognise, and
        # `env_for` leaves that header empty: the answer is a 403 from the
        # middleware, which looks exactly like a permission denied and is not.
        env["HTTP_HOST"] = "localhost"
        status, _headers, body = Rails.application.call(env)
        html = ""; body.each { |chunk| html << chunk }
        puts "STATUS \#{status}"
        puts html.gsub(/<!--.*?-->/m, "")
      RUBY

      served = run_command(app, "bin/rails runner tmp/smoke.rb")

      assert_includes served, "STATUS 200", served
      assert_includes served, %(<div class="index-page stories">), served
      assert_includes served, "Hobo 2027"
    end
  end

  private

  def run_command(dir, command)
    `cd #{dir} && HOBODEV=#{ROOT} #{command} 2>&1`
  end

end
