require "minitest/autorun"
require "fileutils"
require_relative "../../prepare_testapp"

# The application's taglib -- `app/views/taglibs/application.html.erb`, which is
# what `application.dryml` was -- against a real application.
#
# It has to be a real one. The whole point of the piece is that a block of ERB
# written at boot is painted later, once per record, with the markup landing in
# the right buffer; and a buffer is exactly the thing that does not exist
# outside Rails. The first attempt looked right in a unit test and put the
# markup of every card at the bottom of the page.
class TaglibTest < Minitest::Test

  # The model is a **file**, and the table is made in an initializer, because a
  # taglib is loaded when the application boots: `<% define :card, :for => Chapter
  # %>` names a constant, and a model defined afterwards by the probe does not
  # exist yet when the taglib is read. Which is the right way round -- a taglib
  # that could not name the application's models would be no use at all.
  MODEL = <<~RUBY
    class Chapter < ActiveRecord::Base
      include Hobo::Model
      fields do
        title :string
        body  :text
        rank  :integer
      end
      def view_permitted?(field) = true
      def edit_permitted?(field) = true
    end
  RUBY

  TABLE = <<~RUBY
    ActiveRecord::Base.connection.create_table(:chapters, :force => true) do |t|
      t.string :title; t.text :body; t.integer :rank
    end
  RUBY

  RECORDS = <<~RUBY
    Chapter.create!(:title => "La luz de Hobo", :body => "Se ve algo", :rank => 2)
    Chapter.create!(:title => "Segunda", :body => "Tambien", :rank => 1)
  RUBY

  def setup
    skip TestApp.why_not unless TestApp.built?
    TestApp.sweep
  end

  # --- define ----------------------------------------------------------------

  def test_a_taglib_defines_how_a_record_is_painted_everywhere
    output = run_with_taglib(<<~ERB, "puts Rapid.render(:card, {}, :this => Chapter.first)")
      <% define :card, :for => Chapter do %>
        <div class="mine"><h4><%= this.title %></h4></div>
      <% end %>
    ERB

    assert_includes output, %(<div class="mine">), output
    assert_includes output, "<h4>La luz de Hobo</h4>"
  end

  # The block is written once and painted once per record. If it captured on the
  # request's view instead of its own, the second card would come out empty --
  # or worse, both would come out somewhere else on the page.
  def test_the_same_block_paints_a_different_record_each_time
    output = run_with_taglib(<<~ERB, "Chapter.all.each { |s| puts Rapid.render(:card, {}, :this => s) }")
      <% define :card, :for => Chapter do %>
        <div class="mine"><%= this.title %></div>
      <% end %>
    ERB

    assert_includes output, "La luz de Hobo", output
    assert_includes output, "Segunda"
  end

  # --- extend_tag ------------------------------------------------------------

  def test_extend_tag_retouches_what_is_already_painted
    output = run_with_taglib(<<~ERB, "puts Rapid.render(:index_page, {}, :this => Chapter.all)")
      <% extend_tag :index_page do %>
        <% append_heading " — all of them" %>
        <%= old %>
        <p class="note">two of them</p>
      <% end %>
    ERB

    assert_includes output, "<h2>Chapters — all of them</h2>", output
    assert_includes output, %(<p class="note">two of them</p>)
    # `old` is what was painted before, in its place and only once.
    assert_equal 1, output.scan(%(<table class="collection-table")).length
  end

  def test_extend_tag_for_one_model_leaves_the_others_alone
    output = run_with_taglib(<<~ERB, "puts Rapid.render(:index_page, {}, :this => Chapter.all)")
      <% extend_tag :index_page, :for => Chapter do %>
        <% append_heading " — only here" %>
        <%= old %>
      <% end %>
    ERB

    assert_includes output, "<h2>Chapters — only here</h2>", output
  end

  # A taglib without `old` replaces the tag, which is what leaving it out means.
  def test_leaving_out_old_replaces_the_tag
    output = run_with_taglib(<<~ERB, "puts Rapid.render(:index_page, {}, :this => Chapter.all)")
      <% extend_tag :index_page do %>
        <p class="instead">nothing else</p>
      <% end %>
    ERB

    assert_includes output, %(<p class="instead">nothing else</p>), output
    refute_includes output, "collection-table"
  end

  # --- sortable headings ------------------------------------------------------

  def test_sortable_headings_turns_every_heading_into_a_link
    output = run_with_taglib(<<~ERB, "puts Rapid.render(:index_page, {}, :this => Chapter.all)")
      <% extend_tag :index_page do %>
        <% sortable_headings %>
        <%= old %>
      <% end %>
    ERB

    assert_includes output, %(<a href="?sort=title" class="sort-link">Title</a>), output
    assert_includes output, %(<a href="?sort=rank" class="sort-link">Rank</a>)
  end

  # --- the tag helpers --------------------------------------------------------

  def test_every_tag_has_a_helper_named_after_it
    output = run_with_taglib("", <<~RUBY)
      view = ApplicationController.new.view_context
      puts "CARD \#{view.respond_to?(:card)}"
      puts "INDEX \#{view.respond_to?(:index_page)}"
      puts "SEARCH \#{view.respond_to?(:search_filter)}"
      puts "RENDER \#{view.method(:render).owner}"
    RUBY

    assert_includes output, "CARD true", output
    assert_includes output, "INDEX true"
    assert_includes output, "SEARCH true"
    # And a name Rails already answers is left alone.
    refute_includes output, "RENDER #<Module"
  end

  private

  def run_with_taglib(taglib, script)
    run_in_app("#{RECORDS}\n#{script}",
               "app/models/chapter.rb" => MODEL,
               "config/initializers/zz_taglib_test.rb" => TABLE,
               "app/views/taglibs/application.html.erb" => taglib)
  end

  def run_in_app(script, views = {})
    written = views.map do |path, content|
      full = File.join(TestApp::PATH, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
      full
    end

    file = File.join(TestApp::PATH, "tmp", "taglib_probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    written << file

    TestApp.run("bin/rails runner #{file}")
  ensure
    written.to_a.each do |path|
      FileUtils.rm_f(path)
      dir = File.dirname(path)
      FileUtils.rmdir(dir) if File.directory?(dir) && Dir.empty?(dir)
    end
  end

end
