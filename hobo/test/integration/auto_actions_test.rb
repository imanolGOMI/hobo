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

  # Routing, `include Hobo::Controller::Model`, `auto_actions`, the rescue_from
  # and the permission layer, end to end.
  #
  # 403 is the answer today, and it is a real one: the request reaches Hobo's
  # own permission check and is turned down there. Getting an index to answer
  # 200 is the next step of piece 11 -- see PLAN.md.
  def test_a_request_reaches_the_hobo_stack_and_gets_its_answer
    output = run_in_app(<<~RUBY)
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

      response = Rack::MockRequest.new(Rails.application).get("/stories")
      puts "STATUS \#{response.status}"
    RUBY

    status = output[/STATUS (\d+)/, 1]
    refute_nil status, "la peticion no llego a contestar:\n#{output}"
    refute_equal "500", status, "la peticion revento en vez de contestar:\n#{output}"
    assert_equal "403", status, "hoy el indice se deniega; si esto cambia, actualiza PLAN.md"
  end

  private

  def run_in_app(script)
    file = File.join(TestApp::PATH, "tmp", "probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    `cd #{TestApp::PATH} && bin/rails runner #{file} 2>&1`
  end

end
