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
