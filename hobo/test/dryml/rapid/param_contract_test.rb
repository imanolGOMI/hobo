require "test_helper"
require_relative "../rapid_fixtures"

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
      override = parameter_for(name, :bare)
      override ? instance_exec(&override.content) : default&.call
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
    assert_includes failure.message, "no se puede sobreescribir desde fuera"
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

  # <page> exposes its call to <panel> as a param, which is what makes the
  # panel's own params reachable from a caller of <page>: nested parameters.
  Rapid.define(:spike_page, :attrs => [:title]) do
    tag("body") { call_tag(:panel, { :title => attributes[:title] }, :as => :panel) }
  end

  # One more level, to show the nesting has no depth limit.
  Rapid.define(:site, :attrs => [:title]) do
    call_tag(:spike_page, { :title => attributes[:title] }, :as => :page)
  end

  # The fixture of dryml/features/cookbook/06_pseudo_parameters.feature, so the
  # tests below can be read against the specification.
  Rapid.define(:pseudo_page, :attrs => [:title]) do
    tag("body") do
      tag("h1", {}, :heading) { text attributes[:title] }
      tag("div", {}, :content)
    end
  end

  Rapid.define(:spike_view) { text this.to_s }
  Rapid.define_for(:spike_view, Integer) { text "##{this}" }
  Rapid.define_for(:spike_view, String)  { text this.upcase }

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
                          :box => Rapid.parameter(:replace => true) { tag("section") { old } },
                          :heading => Rapid.markup { tag("div", { :class => "wrap" }) { old } })

    assert_includes output, %(<section><div class="panel"><div class="wrap"><h1>Stories</h1></div>)
  end

  # The DRYML semantics of a parameter tag on an element: the element stays, its
  # attributes are merged -- `class` by concatenation, as DRYML does -- and only
  # the content is replaced. `replace` is what takes the element away.
  def test_a_parameter_keeps_the_element_and_merges_its_attributes
    output = Rapid.render(:panel, { :title => "Stories" },
                          :box => Rapid.parameter(:attributes => { :class => "wide", :id => "main" }) { text "Mine" })

    assert_includes output, %(<div class="panel wide" id="main">Mine</div>)
  end

  def test_replace_takes_the_element_away
    output = Rapid.render(:panel, { :title => "Stories" },
                          :box => Rapid.parameter(:replace => true) { text "Mine" })

    assert_equal "Mine", output
  end

  # A parameter that carries no content of its own leaves the default alone.
  def test_a_parameter_with_only_attributes_leaves_the_default_content
    output = Rapid.render(:panel, { :title => "Stories" },
                          :box => Rapid.parameter(:attributes => { :id => "main" }))

    assert_includes output, %(<div class="panel" id="main"><h1>Stories</h1>)
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
    assert_equal "#42", Rapid.render(:spike_view, {}, :this => 42)
    assert_equal "SHOUT", Rapid.render(:spike_view, {}, :this => "shout")
    assert_equal "2026-08-07", Rapid.render(:spike_view, {}, :this => Date.new(2026, 8, 7))
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

  # --- nested parameters ------------------------------------------------------
  #
  # <page><panel:><body:>Mine</body:></panel:></page>

  def test_a_param_of_a_called_tag_is_reached_by_nesting
    output = Rapid.render(:spike_page, { :title => "Stories" },
                          :panel => Rapid.parameter(:params => { :body => Rapid.markup { text "Mine" } }))

    assert_includes output, %(<div class="panel"><h1>Stories</h1>Mine</div>)
  end

  def test_the_nesting_has_no_depth_limit
    output = Rapid.render(:site, { :title => "Stories" },
                          :page => Rapid.parameter(
                            :params => { :panel => Rapid.parameter(
                              :params => { :heading_text => Rapid.markup { text "Deep" } }) }))

    assert_includes output, "<h1>Deep</h1>"
  end

  # A nested parameter is a parameter tag like any other, so it merges
  # attributes at its own level too.
  def test_a_nested_parameter_merges_attributes_at_its_own_level
    output = Rapid.render(:spike_page, { :title => "Stories" },
                          :panel => Rapid.parameter(
                            :params => { :box => Rapid.parameter(:attributes => { :id => "main" }) }))

    assert_includes output, %(<div class="panel" id="main"><h1>Stories</h1>)
  end

  # Nesting only means something at a tag call: an element has no other tag's
  # params to pass them to. Saying so out loud beats dropping them in silence.
  def test_nested_params_on_something_that_is_not_a_tag_call_are_refused
    error = assert_raises(ArgumentError) do
      Rapid.render(:panel, { :title => "Stories" },
                   :box => Rapid.parameter(:params => { :heading => Rapid.markup { text "x" } }))
    end

    assert_includes error.message, "no admite params anidados"
  end

  def test_every_param_reachable_through_two_levels_is_overridable
    assert_every_param_overridable(:site, { :name => "site", :attributes => { :title => "Stories" } })
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

  # <table-plus> calls <with-field-names> without exposing the call as a param,
  # so nothing leads to the params of <with-field-names> and no amount of
  # nesting reaches them. That is a decision of <table-plus>, not a hole in the
  # runtime -- and it is written down here instead of being discovered by
  # someone's theme quietly not working.
  #
  # :field_heading_row used to be here too. It is a param of <table>, and now
  # that nesting exists it is reachable as <table:><field-heading-row:>.
  EXCEPTIONS = {
    :default => "<table-plus> llama a <with-field-names> sin exponer la llamada",
  }.freeze

  def test_every_param_of_table_plus_is_overridable
    assert_every_param_overridable(:table_plus, scenarios, :except => EXCEPTIONS)
  end

  # The params whose name is computed at render time are the ones spike C lost.
  # Named here so a regression says which one broke.
  def test_the_params_with_a_computed_name_are_overridable_one_by_one
    %i[title_heading title_heading_link status_heading status_heading_link].each do |name|
      output = render_tag(:table_plus, scenarios.first, name => ParamContract.replacement)
      assert_includes output, ParamContract::SENTINEL, "se perdio #{name.inspect}"
    end
  end

  # `<title-heading: class="shouty">TITLE!</title-heading:>`: the <th> stays,
  # the class is merged onto it and only the content changes.
  def test_overriding_one_computed_param_leaves_its_neighbour_alone
    output = render_tag(:table_plus, scenarios.first,
                        :title_heading => Rapid.parameter(:attributes => { :class => "shouty" }) { text "TITLE!" })

    assert_includes output, %(<th class="shouty">TITLE!</th>)
    assert_includes output, "Status"
  end

  # The gap this closes: a param of <table>, reached from a caller of
  # <table-plus> by nesting through the call <table-plus> makes to it.
  def test_a_param_of_the_table_is_reached_by_nesting_through_it
    output = render_tag(:table_plus, scenarios.first,
                        :table => Rapid.parameter(
                          :params => { :row => Rapid.markup { tag("td", { :class => "mine" }) { text this.title } } }))

    assert_includes output, %(<tr><td class="mine">First</td></tr>)
    assert_includes output, %(<tr><td class="mine">Second</td></tr>)
  end

  def test_the_heading_row_of_the_table_is_reached_by_nesting_through_it
    output = render_tag(:table_plus, scenarios.first,
                        :table => Rapid.parameter(
                          :params => { :field_heading_row => Rapid.markup { tag("th") { text "Just one" } } }))

    assert_includes output, "<thead><th>Just one</th></thead>"
  end

  # all_parameters: a tag can ask whether the caller supplied a param at all.
  def test_all_parameters_reports_what_the_caller_passed
    without = render_tag(:table_plus, scenarios.first)
    with    = render_tag(:table_plus, scenarios.first, :controls => Rapid.markup { text "" })

    refute_includes without, %(<th class="controls">)
    assert_includes with, %(<th class="controls">)
  end

end


# --- the pseudo-parameters ----------------------------------------------------
#
# The scenarios of dryml/features/cookbook/06_pseudo_parameters.feature, which
# is the specification. `append-` and `prepend-` go *inside*, around the
# content; `before-` and `after-` go *outside*, around the whole element.

class PseudoParameterTest < Minitest::Test
  include ParamContract::Assertions

  def page(**params) = Rapid.render(:pseudo_page, { :title => "A Blog Post" }, **params)

  def test_append_adds_after_the_content_inside_the_element
    assert_includes page(:append_heading => Rapid.markup { text " -- The Hobo Blog" }),
                    "<h1>A Blog Post -- The Hobo Blog</h1>"
  end

  def test_prepend_adds_before_the_content_inside_the_element
    assert_includes page(:prepend_heading => Rapid.markup { text "The Hobo Blog -- " }),
                    "<h1>The Hobo Blog -- A Blog Post</h1>"
  end

  def test_before_adds_outside_the_element
    assert_includes page(:before_heading => Rapid.markup { tag("h1") { text "The Hobo Blog" } }),
                    "<h1>The Hobo Blog</h1><h1>A Blog Post</h1>"
  end

  def test_after_adds_outside_the_element
    assert_includes page(:after_heading => Rapid.markup { tag("h1") { text "The Hobo Blog" } }),
                    "<h1>A Blog Post</h1><h1>The Hobo Blog</h1>"
  end

  def test_without_takes_the_extension_point_away
    output = Rapid.render(:pseudo_page, { :title => "A Blog Post", :without_heading => true })

    assert_equal "<body><div></div></body>", output
  end

  # ...and `without-x` is consumed, so it never reaches the markup.
  def test_without_is_not_written_out_as_an_attribute
    refute_includes Rapid.render(:pseudo_page, { :title => "x", :without_heading => true }),
                    "without"
  end

  def test_a_replace_parameter_with_no_content_also_takes_the_element_away
    output = page(:heading => Rapid.parameter(:replace => true))

    assert_equal "<body><div></div></body>", output
  end

  # The pseudo-parameters do not need the param itself to have been supplied,
  # which is the whole point of them.
  def test_they_combine_with_an_override_of_the_param_itself
    output = page(:heading => Rapid.parameter(:attributes => { :class => "big" }) { text "Mine" },
                  :prepend_heading => Rapid.markup { text "[" },
                  :append_heading => Rapid.markup { text "]" })

    assert_includes output, %(<h1 class="big">[Mine]</h1>)
  end

  def test_a_bare_param_takes_them_too
    output = Rapid.render(:panel, { :title => "Stories" },
                          :append_heading_text => Rapid.markup { text "!" })

    assert_includes output, "<h1>Stories!</h1>"
  end

  # Reached by nesting, like any other parameter of a tag one calls.
  def test_they_are_reached_through_nesting
    output = Rapid.render(:spike_page, { :title => "Stories" },
                          :panel => Rapid.parameter(
                            :params => { :append_heading_text => Rapid.markup { text "!" } }))

    assert_includes output, "<h1>Stories!</h1>"
  end

  # Declaring them does not make the params they hang off unreachable.
  def test_the_contract_still_holds_with_pseudo_parameters_around
    assert_every_param_overridable(:pseudo_page, { :name => "pagina", :attributes => { :title => "x" } })
  end

end
