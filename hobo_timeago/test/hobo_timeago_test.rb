require "minitest/autorun"
require "hobo_rapid/tags/views"   # the catalogue's date view, the one this replaces
require "hobo_timeago"
require "hobo/tag_index"

# What a plugin has to be able to do, checked on a real one.
#
# The contract of piece 17 is short enough to be checked here: require the gem
# and its tags are in the catalogue, replacing the catalogue's own. Nothing in
# this file names a Hobo API for installing anything, because there is not one.
class HoboTimeagoTest < Minitest::Test

  NOW = Time.new(2026, 8, 9, 12, 0, 0)

  # --- the phrase -------------------------------------------------------------

  def test_a_moment_ago
    assert_equal "just now", HoboTimeago.in_words(NOW - 30, NOW)
  end

  def test_the_largest_unit_that_fits_wins
    assert_equal "3 days ago", HoboTimeago.in_words(NOW - (3 * 86_400), NOW)
    assert_equal "2 hours ago", HoboTimeago.in_words(NOW - (2 * 3600), NOW)
    assert_equal "1 week ago", HoboTimeago.in_words(NOW - (8 * 86_400), NOW)
  end

  # A singular is not a plural with the s taken off in every language, but it is
  # in this one, and the plugin only claims this one.
  def test_one_of_something_is_singular
    assert_equal "1 hour ago", HoboTimeago.in_words(NOW - 3600, NOW)
  end

  def test_the_future_reads_forwards
    assert_equal "in 2 days", HoboTimeago.in_words(NOW + (2 * 86_400), NOW)
  end

  # --- the tag ----------------------------------------------------------------

  def test_a_date_paints_as_a_time_element
    html = paint(Date.today - 3)

    assert_includes html, "<time"
    assert_includes html, "3 days ago"
    assert_includes html, %(class="timeago")
    assert_includes html, %(data-controller="timeago")
  end

  # The machine-readable moment is what the Stimulus controller re-paints from,
  # so it has to be there and it has to be parseable.
  def test_the_element_carries_the_moment
    html = paint(Date.new(2026, 8, 1))

    assert_includes html, %(data-timeago-at-value="#{HoboTimeago.iso8601(Date.new(2026, 8, 1))}")
    assert_includes html, %(title="2026-08-01")
  end

  def test_a_time_paints_the_same_way
    assert_includes paint(Time.now - 7200), "2 hours ago"
  end

  # --- the contract -----------------------------------------------------------

  # Requiring the gem is installing it: no generator ran, no taglib was edited,
  # nothing was added to a stylesheet or to the JavaScript, and the date view of
  # the application is the plugin's.
  def test_defining_a_tag_is_installing_it
    date = Date.new(2026, 8, 1)

    refute_equal date.strftime("%Y-%m-%d"), paint(date),
                 "el catalogo pinta la fecha asi; el plugin tiene que haberla reemplazado"
  end

  # And the one it replaced is still in the record, marked. This is what makes
  # a second owner of a name visible instead of silent -- see lib/hobo/tag_index.rb.
  def test_the_replaced_definition_shows_as_shadowed
    index = Hobo::TagIndex.new
    dates = index.rows.select { |row| row.name == :view_content && row.type == Date }

    assert_equal 2, dates.size, "el catalogo y el plugin definen `view_content for Date`"
    assert dates.first.shadowed, "la del catalogo ya no pinta nada y tiene que decirlo"
    refute dates.last.shadowed
    assert_equal "hobo_timeago", dates.last.owner
    assert_equal "hobo", dates.first.owner
  end

  def test_the_index_names_the_plugin_among_the_owners
    assert_includes Hobo::TagIndex.new.owners, "hobo_timeago"
    assert_includes Hobo::TagIndex.new.render, "hobo_timeago/lib/hobo_timeago/tags.rb"
  end

  # The import map of the engine is the only wiring the JavaScript needs, and it
  # is wrong in a way no rendering test would notice: a controller that is not
  # pinned under `controllers/` with that name is never loaded by anybody.
  def test_the_stimulus_controller_is_pinned_where_the_application_looks
    pins = {}
    stub = Object.new
    stub.define_singleton_method(:pin) { |name, to:| pins[name] = to }
    stub.instance_eval(File.read(File.expand_path("../config/importmap.rb", __dir__)))

    assert_equal "controllers/timeago_controller.js", pins["controllers/timeago_controller"]
    assert File.exist?(File.expand_path("../app/javascript/controllers/timeago_controller.js", __dir__))
  end

  private

  def paint(value) = Rapid.render(:view_content, {}, :this => value)

end
