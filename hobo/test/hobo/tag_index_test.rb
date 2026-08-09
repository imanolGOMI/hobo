require "test_helper"
require "hobo/tag_index"

# The catalogue is one global table keyed by name, which is what lets a plugin
# install itself by loading (piece 17) and what let a spike's `<view>` paint the
# real pages when the gems were merged. The difference between those two is
# whether anybody can see it, so the registry keeps who defined what and this is
# the reading of it.
class TagIndexTest < Minitest::Test

  def definition(name, kind: :define, type: nil, source: "/gems/hobo/lib/x.rb")
    Rapid::Definition.new(:name => name, :kind => kind, :type => type, :source => source)
  end

  def index(*definitions) = Hobo::TagIndex.new(definitions)

  # --- what is in force -------------------------------------------------------

  def test_a_lone_definition_is_in_force
    rows = index(definition(:view)).rows

    assert_equal 1, rows.size
    refute rows.first.shadowed
  end

  # The second definition of a name wins, silently, at render time. Here it says
  # so.
  def test_the_first_of_two_definitions_of_a_name_is_shadowed
    rows = index(definition(:view), definition(:view)).rows

    assert rows.first.shadowed
    refute rows.last.shadowed
  end

  # A polymorphic definition only shadows one for the *same* type: `for Date`
  # and `for Time` are two entries in the table, not one.
  def test_a_type_view_only_shadows_its_own_type
    rows = index(definition(:view_content, :kind => :define_for, :type => Date),
                 definition(:view_content, :kind => :define_for, :type => Time)).rows

    assert_empty rows.select(&:shadowed)
  end

  def test_a_type_view_shadows_the_same_type
    rows = index(definition(:view_content, :kind => :define_for, :type => Date),
                 definition(:view_content, :kind => :define_for, :type => Date)).rows

    assert rows.first.shadowed
  end

  # `Rapid.extend_tag` prepends: two extensions of one tag both run, so neither
  # shadows the other. Extending is the honest way to change somebody else's
  # tag, and the index has to stop saying "shadowed" about it.
  def test_extensions_do_not_shadow_each_other
    rows = index(definition(:page), definition(:page, :kind => :extend),
                 definition(:page, :kind => :extend)).rows

    assert_empty rows.select(&:shadowed)
  end

  # --- who ---------------------------------------------------------------------

  # A gem in the working tree is named by its gemspec, which is what a plugin
  # under development is, and an installed one by its spec: the same name either
  # way, so a name in this listing means a gem you can look up.
  def test_a_file_in_the_working_tree_is_named_by_its_gemspec
    row = index(definition(:view, :source => File.expand_path("../../lib/hobo/tag_index.rb", __dir__))).rows.first

    assert_equal "hobo", row.owner
    assert_equal "lib/hobo/tag_index.rb", row.file
    assert_equal "hobo/lib/hobo/tag_index.rb", row.source
  end

  def test_a_file_that_belongs_to_nobody_is_shown_whole
    row = index(definition(:view, :source => "/somewhere/else.rb")).rows.first

    assert_nil row.owner
    assert_equal "/somewhere/else.rb", row.file
  end

  def test_the_owners_are_listed_once_each_in_order
    hobo = File.expand_path("../../lib/hobo/tag_index.rb", __dir__)

    assert_equal ["hobo"], index(definition(:a, :source => hobo), definition(:b, :source => hobo)).owners
  end

  # --- the listing --------------------------------------------------------------

  def test_the_listing_puts_the_type_views_under_their_tag
    text = index(definition(:view_content),
                 definition(:view_content, :kind => :define_for, :type => Date)).render

    assert_match(/^view_content\s+\S/, text)
    assert_match(/^  for Date\s+\S/, text)
  end

  def test_the_listing_counts_what_is_shadowed
    text = index(definition(:view), definition(:view)).render

    assert_includes text, "shadowed"
    assert_includes text, "1 tags, 2 definitions, 1 shadowed"
  end

  # --- the registry ------------------------------------------------------------

  # The record is made by the runtime itself, at the point of definition, with
  # no cooperation from whoever defines the tag -- a plugin cannot forget to
  # register and cannot lie about where it came from.
  def test_the_runtime_records_the_file_that_defined_the_tag
    Rapid.define(:tag_index_probe) { text "hola" }

    definition = Rapid.definitions_for(:tag_index_probe).last

    assert_equal :define, definition.kind
    assert_equal __FILE__, definition.source
  end

  def test_the_runtime_records_extensions_and_type_views
    Rapid.define(:tag_index_probe_two) { text "hola" }
    Rapid.define_for(:tag_index_probe_two, Date) { text "fecha" }
    Rapid.extend_tag(:tag_index_probe_two) { old }

    kinds = Rapid.definitions_for(:tag_index_probe_two).map(&:kind)

    assert_equal [:define, :define_for, :extend], kinds
    assert_equal Date, Rapid.definitions_for(:tag_index_probe_two)[1].type
  end

end
