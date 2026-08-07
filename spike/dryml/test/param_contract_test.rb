require "test_helper"

# --- the contract check itself, proved to have teeth --------------------------
#
# A check that never fails is worse than no check. These two tests make it fail
# on purpose: once on the exact bug spike C found, and once on a stale
# exception list.

module Canary

  # The runtime spike C started with: the override is run with `instance_exec`
  # on the tag that *reaches* the param, instead of `call` on the tag that
  # *wrote* it. That is the whole bug, in four lines.
  module NaiveParamLookup
    def param(name, &default)
      override = @params[name]
      override ? instance_exec(&override) : default&.call
      nil
    end
  end

  # <naive-inner> just renders whatever body it is given.
  Rapid.define(:naive_inner) { param(:default) }

  # <naive-outer> writes a param *inside the body it hands to another tag*.
  # In DRYML that param belongs to <naive-outer>, not to <naive-inner>.
  Rapid.define(:naive_outer) do
    call_tag(:naive_inner, {},
             :default => proc { tag("span", {}, :inner_heading) { text "default heading" } })
  end

  # The same pair, on the runtime we actually have.
  Rapid.define(:sound_inner) { param(:default) }
  Rapid.define(:sound_outer) do
    call_tag(:sound_inner, {},
             :default => proc { tag("span", {}, :inner_heading) { text "default heading" } })
  end

  # The recorder normally sits in front of Rapid::Tag#param, which is where a
  # real regression would live. Here the naive lookup is a module on one class,
  # so the recorder has to be put in front of it explicitly.
  Rapid.tags[:naive_inner].prepend(NaiveParamLookup)
  Rapid.tags[:naive_inner].prepend(ParamContract::Recorder)

end

class ParamContractTeethTest < Minitest::Test
  include ParamContract::Assertions

  SCENARIO = { :name => "pelado" }.freeze

  def test_the_check_catches_a_param_lost_in_silence
    failure = assert_raises(Minitest::Assertion) do
      assert_every_param_overridable(:naive_outer, SCENARIO,
                                     :except => { :default => "lo rellena <naive-outer>" })
    end

    assert_includes failure.message, "inner_heading"
    assert_includes failure.message, "se perdio en silencio"
  end

  def test_the_same_tags_on_the_real_runtime_pass
    assert_every_param_overridable(:sound_outer, SCENARIO,
                                   :except => { :default => "lo rellena <sound-outer>" })
  end

  def test_an_exception_that_is_no_longer_true_fails
    failure = assert_raises(Minitest::Assertion) do
      assert_every_param_overridable(:sound_outer, SCENARIO,
                                     :except => { :default => "lo rellena <sound-outer>",
                                                  :inner_heading => "supuestamente inalcanzable" })
    end

    assert_includes failure.message, "quita la excepcion"
  end

  def test_an_exception_for_a_param_nobody_declares_fails
    failure = assert_raises(Minitest::Assertion) do
      assert_every_param_overridable(:sound_outer, SCENARIO,
                                     :except => { :default => "lo rellena <sound-outer>",
                                                  :ghost => "ya no existe" })
    end

    assert_includes failure.message, "ya no corresponden"
  end

end


# --- the four properties of DRYML we promised to keep -------------------------

module Fixtures

  # Five extension points, nested three deep. `param` on an element makes the
  # whole element the extension point, which is what <h1 param="heading-box">
  # means in DRYML; the text inside it is a separate one.
  PANEL = proc do
    tag("div", { :class => "panel" }, :box) do
      param(:heading) do
        tag("h1", {}, :heading_box) { param(:heading_text) { text attributes[:title].to_s } }
      end
      param(:body) { tag("p") { text "default body" } }
    end
  end

  Rapid.define(:panel, :attrs => [:title], &PANEL)

  # The same tag under another name, so the tests that extend one -- which
  # mutates the registry for good -- cannot leak into the ones that do not.
  Rapid.define(:extendable_panel, :attrs => [:title], &PANEL)

  Rapid.define(:view) { text this.to_s }
  Rapid.define_for(:view, Integer) { text "##{this}" }
  Rapid.define_for(:view, String)  { text this.upcase }

end

class RuntimeContractTest < Minitest::Test
  include ParamContract::Assertions

  SCENARIO = { :name => "panel", :attributes => { :title => "Stories" } }.freeze

  def test_every_param_of_the_panel_is_overridable
    assert_every_param_overridable(:panel, SCENARIO)
  end

  # Property 1: params nest, and overriding an inner one leaves the outer ones
  # doing their job. This is where ViewComponent slots stop being enough.
  def test_overriding_an_inner_param_leaves_the_outer_markup_alone
    output = Rapid.render(:panel, { :title => "Stories" },
                          :heading_text => Rapid.markup { text "Mine" })

    assert_includes output, %(<div class="panel">)
    assert_includes output, "<h1>Mine</h1>"
    assert_includes output, "<p>default body</p>"
  end

  # Property 2: <old-x> -- an override may *wrap* the default instead of
  # replacing it. A slot that can only substitute is exactly the failure of the
  # first attempt.
  def test_an_override_can_wrap_the_default_instead_of_replacing_it
    output = Rapid.render(:panel, { :title => "Stories" },
                          :heading => Rapid.markup { tag("div", { :class => "wrap" }) { old } })

    assert_includes output, %(<div class="wrap"><h1>Stories</h1></div>)
  end

  def test_old_is_available_at_every_level_of_nesting
    output = Rapid.render(:panel, { :title => "Stories" },
                          :box => Rapid.markup { tag("section") { old } },
                          :heading => Rapid.markup { tag("div", { :class => "wrap" }) { old } })

    assert_includes output, %(<section><div class="panel"><div class="wrap"><h1>Stories</h1></div>)
  end

  # Property 2, the other half: <extend> from another gem, without knowing which
  # class the tag is. `super` is <old-panel>. It happens once, at load, because
  # extending a tag mutates the registry for good -- which is what stacking
  # themes does.
  Rapid.extend_tag(:extendable_panel) { tag("aside", { :class => "themed" }) { super() } }

  def test_a_tag_can_be_extended_from_outside_and_super_is_the_old_one
    output = Rapid.render(:extendable_panel, { :title => "Stories" })

    assert_includes output, %(<aside class="themed"><div class="panel">)
    assert_includes output, "<h1>Stories</h1>"
  end

  # ...and every param of the extended tag survives the extension.
  def test_the_params_survive_an_extension
    assert_every_param_overridable(:extendable_panel, SCENARIO.merge(:name => "panel extendido"))
  end

  # Property 3: dispatch on the type of `this`.
  def test_view_dispatches_on_the_type_of_this
    assert_equal "#42", Rapid.render(:view, {}, :this => 42)
    assert_equal "SHOUT", Rapid.render(:view, {}, :this => "shout")
    assert_equal "2026-08-07", Rapid.render(:view, {}, :this => Date.new(2026, 8, 7))
  end

  # Property 4: `this` is dynamic, so a param block sees the record of whoever
  # is rendering it, not of whoever wrote it.
  def test_a_param_block_sees_the_this_of_whoever_renders_it
    Rapid.define(:each_story) do
      Array(this).each { |story| with_this(story) { param(:default) } }
    end

    output = Rapid.render(:each_story, {},
                          :this => RapidTest.stories,
                          :default => Rapid.markup { tag("li") { text this.title } })

    assert_equal "<li>First</li><li>Second</li>", output
  end

  # The spike C rule, stated on its own: a param written inside a body handed to
  # another tag belongs to the tag that *wrote* it.
  def test_a_param_written_inside_another_tags_body_belongs_to_the_writer
    output = Rapid.render(:sound_outer, {}, :inner_heading => Rapid.markup { text "overridden" })

    assert_includes output, "overridden"
    refute_includes output, "default heading"
  end

end


# --- the real port: <table-plus> ---------------------------------------------

class TablePlusContractTest < Minitest::Test
  include ParamContract::Assertions

  # Two scenarios, because the sort arrows sit behind a condition and are only
  # declared when the column being rendered is the one being sorted on.
  def scenarios
    [{ :name => "ordenado ascendente",
       :attributes => { :fields => "title, status", :sort_field => "title", :sort_direction => "asc" },
       :this => RapidTest.stories },
     { :name => "ordenado descendente",
       :attributes => { :fields => "title, status", :sort_field => "title", :sort_direction => "desc" },
       :this => RapidTest.stories }]
  end

  # The two exceptions are not params of <table-plus>: they belong to the tags
  # it calls, and <table-plus> fills them itself. Reaching them from outside
  # needs DRYML's nested param syntax (<table:><field-heading-row:>...), which
  # the runtime does not have yet. They are listed so the gap is on the record
  # instead of being discovered by someone's theme not working.
  EXCEPTIONS = {
    :field_heading_row => "es un param de <table>, y <table-plus> lo rellena",
    :default => "es un param de <with-field-names>, y <table-plus> lo rellena",
  }.freeze

  def test_every_param_of_table_plus_is_overridable
    assert_every_param_overridable(:table_plus, scenarios, :except => EXCEPTIONS)
  end

  # The params whose name is computed at render time are the ones spike C lost.
  # Named here so a regression says which one broke.
  def test_the_params_with_a_computed_name_are_overridable_one_by_one
    %i[title_heading title_heading_link status_heading status_heading_link].each do |name|
      output = render_tag(:table_plus, scenarios.first, name => ParamContract.sentinel)
      assert_includes output, ParamContract::SENTINEL, "se perdio #{name.inspect}"
    end
  end

  def test_overriding_one_computed_param_leaves_its_neighbour_alone
    output = render_tag(:table_plus, scenarios.first,
                        :title_heading => Rapid.markup { tag("th", { :class => "shouty" }) { text "TITLE!" } })

    assert_includes output, %(<th class="shouty">TITLE!</th>)
    assert_includes output, "Status"
  end

  # all_parameters: a tag can ask whether the caller supplied a param at all.
  def test_all_parameters_reports_what_the_caller_passed
    without = render_tag(:table_plus, scenarios.first)
    with    = render_tag(:table_plus, scenarios.first, :controls => Rapid.markup { text "" })

    refute_includes without, %(<th class="controls">)
    assert_includes with, %(<th class="controls">)
  end

end
