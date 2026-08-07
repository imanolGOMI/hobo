require "minitest/autorun"
require_relative "../../../hobo/test/prepare_testapp"

# Piece 10 against a real application: a model with `fields do`, and the pages
# exist. Nobody writes a view.
#
# This is the one that says whether the whole stack works: hobo_fields declares
# the types, hobo enforces the permissions, the layer-3 runtime paints, and the
# derivation engine decides what to paint from what the model said.
class DerivedPagesTest < Minitest::Test

  MODELS = <<~RUBY
    ActiveRecord::Base.connection.create_table(:stories, :force => true) do |t|
      t.string :title; t.text :body; t.date :published_on; t.boolean :featured
    end
    ActiveRecord::Base.connection.create_table(:tasks, :force => true) do |t|
      t.string :title; t.boolean :done; t.integer :story_id
    end

    class Story < ActiveRecord::Base
      include Hobo::Model
      fields do
        title        :string
        body         :text
        published_on :date
        featured     :boolean
      end
      has_many :tasks
      children :tasks
      def view_permitted?(field) = true
      def edit_permitted?(field) = true
    end

    class Task < ActiveRecord::Base
      include Hobo::Model
      fields { title :string; done :boolean }
      belongs_to :story, :optional => true
      def view_permitted?(field) = true
    end

    HoboRapid::Derivation.derive(Story)
    HoboRapid::Derivation.derive(Task)

    story = Story.create!(:title => "La luz de Hobo", :body => "Se ve algo",
                          :published_on => Date.new(2026, 8, 7), :featured => true)
    story.tasks.create!(:title => "Portar el catalogo", :done => true)
  RUBY

  def setup
    skip TestApp.why_not unless TestApp.built?
    TestApp.sweep
  end

  def test_a_show_page_is_derived_from_the_model
    output = run_in_app(<<~RUBY)
      #{MODELS}
      puts Rapid.render(:show_page, {}, :this => story)
    RUBY

    assert_includes output, %(<article class="show-page story">), output
    assert_includes output, "La luz de Hobo"
    # Each field painted by its type, with a label nobody wrote.
    assert_includes output, %(<div class="description">), "el contenido principal va arriba y aparte"
    assert_includes output, %(<span class="view story-published-on">2026-08-07</span>)
    # The boolean as a tick, not as "true".
    assert_includes output, "&#10004;"
    # And the children in a section of their own, because `children :tasks` said so.
    assert_includes output, %(<section class="collection-section tasks">)
    assert_includes output, "Portar el catalogo"
  end

  def test_an_index_page_paints_a_card_for_each_record
    output = run_in_app(<<~RUBY)
      #{MODELS}
      Story.create!(:title => "Segunda")
      puts Rapid.render(:index_page, {}, :this => Story.all)
    RUBY

    assert_includes output, %(<div class="index-page stories">), output
    assert_includes output, "<h2>Stories</h2>"
    assert_includes output, %(<table class="table table-striped table-bordered">)
    assert_equal 3, output.scan("<tr>").length, "dos filas y una cabecera"
  end

  # An ActiveRecord relation knows what it holds, and that is how an index of
  # stories knows to paint story cards.
  def test_a_relation_dispatches_on_what_it_holds
    output = run_in_app(<<~RUBY)
      #{MODELS}
      puts "MEMBER \#{Story.all.member_class}"
    RUBY

    assert_includes output, "MEMBER Story", output
  end

  # Where `fields do` pays off: nobody said what control each field gets.
  def test_a_form_gives_each_field_the_control_its_type_asks_for
    output = run_in_app(<<~RUBY)
      #{MODELS}
      puts Rapid.render(:model_form, {}, :this => story)
    RUBY

    assert_includes output, %(<input type="text" value="La luz de Hobo" name="story[title]">), output
    assert_includes output, %(<textarea name="story[body]">Se ve algo</textarea>)
    assert_includes output, %(<input type="date" value="2026-08-07" name="story[published_on]">)
    assert_includes output, %(type="checkbox")
  end

  # The permission layer is not bypassed by the derivation: a field the user may
  # not see does not appear on the page it derives.
  def test_a_field_that_may_not_be_viewed_is_refused
    output = run_in_app(<<~RUBY)
      #{MODELS}
      Story.define_method(:view_permitted?) { |field| field.to_s != "body" }
      begin
        Rapid.render(:show_page, {}, :this => story)
        puts "SIN QUEJA"
      rescue => e
        puts "NEGADO \#{e.class}"
      end
    RUBY

    assert_includes output, "NEGADO", output
    refute_includes output, "SIN QUEJA"
  end

  # The whole thing over HTTP: a model with `fields do`, a controller with
  # `auto_actions`, routes from `hobo_routes`, and a page nobody wrote.
  def test_a_request_returns_the_derived_page
    output = run_in_app(<<~RUBY)
      #{MODELS}

      class StoriesController < ApplicationController
        include Hobo::Controller::Model
        auto_actions :all
      end

      Rails.application.routes.draw { hobo_routes }

      env = Rack::MockRequest.env_for("http://localhost/stories")
      status, _headers, body = Rails.application.call(env)
      html = ""; body.each { |chunk| html << chunk }

      puts "STATUS \#{status}"
      puts "BODY \#{html.gsub(/<!--.*?-->/m, '')}"
    RUBY

    assert_includes output, "STATUS 200", output
    assert_includes output, %(<div class="index-page stories">), output
    assert_includes output, %(<table class="table)
    assert_includes output, "La luz de Hobo"
  end

  # And an application that has written a template still gets its template: the
  # derived page falls back, it does not take over.
  def test_a_template_of_its_own_wins
    output = run_in_app(<<~RUBY, "app/views/stories/index.html.erb" => "MI PROPIA PLANTILLA")
      #{MODELS}

      class StoriesController < ApplicationController
        include Hobo::Controller::Model
        auto_actions :all
      end

      Rails.application.routes.draw { hobo_routes }

      env = Rack::MockRequest.env_for("http://localhost/stories")
      status, _headers, body = Rails.application.call(env)
      html = ""; body.each { |chunk| html << chunk }

      puts "STATUS \#{status}"
      puts "BODY \#{html.gsub(/<!--.*?-->/m, '')}"
    RUBY

    assert_includes output, "MI PROPIA PLANTILLA", output
    refute_includes output, %(<div class="index-page stories">)
  end

  # And nobody has to ask for the derivation: declaring the model is the ask.
  # It happens on every reload, so a model that gains a field in development
  # gains the column on its pages without a restart.
  def test_a_model_in_a_file_is_derived_without_anybody_asking
    output = run_in_app(<<~RUBY, "app/models/note.rb" => NOTE_MODEL)
      ActiveRecord::Base.connection.create_table(:notes, :force => true) { |t| t.string :title }
      puts "DERIVADO \#{Rapid.polymorphic?(:show_page, Note.new)}"
      puts Rapid.render(:show_page, {}, :this => Note.new(:title => "Sin pedirlo"))
    RUBY

    assert_includes output, "DERIVADO true", output
    assert_includes output, %(<article class="show-page note">)
    assert_includes output, "Sin pedirlo"
  end

  NOTE_MODEL = <<~RUBY
    class Note < ActiveRecord::Base
      include Hobo::Model
      fields { title :string }
      def view_permitted?(field) = true
    end
  RUBY

  private

  def run_in_app(script, views = {})
    written = views.map do |path, content|
      full = File.join(TestApp::PATH, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
      full
    end

    file = File.join(TestApp::PATH, "tmp", "derived_probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    written << file

    `cd #{TestApp::PATH} && bin/rails runner #{file} 2>&1`
  ensure
    written.to_a.each do |path|
      FileUtils.rm_f(path)
      dir = File.dirname(path)
      FileUtils.rmdir(dir) if File.directory?(dir) && Dir.empty?(dir)
    end
  end

end
