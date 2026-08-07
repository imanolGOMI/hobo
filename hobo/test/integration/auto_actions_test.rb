require "test_helper"
require_relative "../prepare_testapp"

# The half of piece 11 that cannot be checked without a real application:
# booting, routing, a request and a response.
#
# It skips -- loudly, saying how to fix it -- when the application has not been
# built. The rule is the one layer 2 set with the database adapters: something
# that is not being checked must never look like something that passes.
#
#   cd hobo && rake test:app
class AutoActionsIntegrationTest < Minitest::Test

  def setup
    skip TestApp.why_not unless TestApp.built?
  end

  # Everything layer 4 has fixed so far, in one assertion: the four gems load
  # inside a real Rails 8 application and the engine's initializers run.
  def test_the_application_boots_with_the_four_gems_in_it
    assert_equal "BOOT OK", run_in_app(%(puts "BOOT OK")).lines.last.to_s.strip
  end

  # The whole stack, end to end: routing, `include Hobo::Controller::Model`,
  # `auto_actions`, the permission layer, the finder, and a rendered view with
  # the record in it.
  #
  # The view is plain ERB and reads `@stories`, which is the contract the
  # controller side offers: `this=` sets the instance variable named after the
  # model. `this` itself only reaches a template through the tag runtime, and
  # that is layers 5 and 6.
  def test_an_index_answers_200_with_the_record_in_it
    output = run_in_app(<<~RUBY, "stories/index.html.erb" => "<ul><% @stories.each do |s| %><li><%= s.title %></li><% end %></ul>")
      ActiveRecord::Base.connection.create_table(:stories, :force => true) { |t| t.string :title }

      class Story < ActiveRecord::Base
        include Hobo::Model
        fields { title :string }
        def view_permitted?(field) = true
      end

      class StoriesController < ApplicationController
        include Hobo::Controller::Model
        auto_actions :index, :show
      end

      Rails.application.routes.draw { resources :stories }
      Story.create!(:title => "Hello")

      status, _headers, body = StoriesController.action(:index).call(Rack::MockRequest.env_for("/stories"))
      puts "STATUS \#{status}"
      puts "BODY \#{body.body.to_s.gsub(/<!--.*?-->/m, '').strip}"
    RUBY

    assert_includes output, "STATUS 200", output
    assert_includes output, "<li>Hello</li>", "el registro no llego a la vista:\n#{output}"
  end

  # The write half: create, update and destroy through real requests, with the
  # permission checks of piece 4 in the way. `1-nueva` in the redirect is Hobo's
  # friendly id, working too.
  def test_the_write_actions_go_through_and_redirect
    output = run_in_app(<<~RUBY)
      #{model_and_controller}
      Rails.application.routes.draw { resources :stories }

      #{caller_helper}

      call(:create, "POST", "/stories", "story" => { "title" => "Nueva" })
      puts "CREADAS \#{Story.count}"

      story = Story.first
      call(:update, "PATCH", "/stories/\#{story.id}", "id" => story.id.to_s, "story" => { "title" => "Cambiada" })
      puts "TITULO \#{Story.first.title}"

      call(:destroy, "DELETE", "/stories/\#{story.id}", "id" => story.id.to_s)
      puts "QUEDAN \#{Story.count}"
    RUBY

    assert_includes output, "CREATE 302", output
    assert_includes output, "CREADAS 1", output
    assert_includes output, "TITULO Cambiada", output
    assert_includes output, "QUEDAN 0", output
    assert_match(%r{CREATE 302 .*/stories/\d+-nueva}, output, "el id amistoso no salio")
  end

  # And the same request against a model that says no. This is the rewrite of
  # piece 4 -- the before_create callback -- seen from outside.
  def test_a_refused_create_answers_403_and_writes_nothing
    output = run_in_app(<<~RUBY)
      #{model_and_controller(:create_permitted => false)}
      Rails.application.routes.draw { resources :stories }

      #{caller_helper}

      call(:create, "POST", "/stories", "story" => { "title" => "Nueva" })
      puts "CREADAS \#{Story.count}"
    RUBY

    assert_includes output, "CREATE 403", output
    assert_includes output, "CREADAS 0", output
  end

  # Nobody logged in, and the application has no Guest model of its own. That
  # used to be a NameError on *every* request, before any action ran: the helper
  # named a bare `::Guest` that only the classic autoloader could resolve.
  def test_a_request_without_a_user_gets_hobos_own_guest
    output = run_in_app(<<~RUBY)
      ActiveRecord::Base.connection.create_table(:stories, :force => true) { |t| t.string :title }
      class Story < ActiveRecord::Base
        include Hobo::Model
        fields { title :string }
      end

      class StoriesController < ApplicationController
        include Hobo::Controller::Model
      end

      controller = StoriesController.new
      controller.define_singleton_method(:session) { {} }
      user = controller.send(:current_user)
      puts "GUEST \#{user.class} \#{user.guest?}"
    RUBY

    assert_includes output, "GUEST Hobo::Model::Guest true", output
  end

  private

  def model_and_controller(create_permitted: true)
    <<~RUBY
      ActiveRecord::Base.connection.create_table(:stories, :force => true) { |t| t.string :title }

      class Story < ActiveRecord::Base
        include Hobo::Model
        fields { title :string }
        def view_permitted?(field) = true
        def create_permitted?  = #{create_permitted}
        def update_permitted?  = true
        def destroy_permitted? = true
      end

      class StoriesController < ApplicationController
        include Hobo::Controller::Model
        auto_actions :all
      end
    RUBY
  end

  # Calls an action straight, without the middleware that swallows exceptions:
  # a rendered error page looks like an answer, and that is how a NameError
  # spent a whole session pretending to be a 403.
  def caller_helper
    <<~RUBY
      def call(action, verb, path, params = {})
        env = Rack::MockRequest.env_for(path, :method => verb, :params => params)
        status, headers, _body = StoriesController.action(action).call(env)
        puts "\#{action.to_s.upcase} \#{status} \#{headers['location']}"
      rescue Hobo::PermissionDeniedError
        puts "\#{action.to_s.upcase} 403"
      rescue => e
        puts "\#{action.to_s.upcase} EXCEPCION \#{e.class}: \#{e.message.lines.first}"
        puts e.backtrace.select { |l| l =~ /RubymineProjects/ }.first(4)
      end
    RUBY
  end

  def run_in_app(script, views = {})
    views.each do |path, content|
      full = File.join(TestApp::PATH, "app", "views", path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
    end

    file = File.join(TestApp::PATH, "tmp", "probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    `cd #{TestApp::PATH} && bin/rails runner #{file} 2>&1`
  end

end
