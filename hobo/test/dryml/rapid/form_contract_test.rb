require "test_helper"
require_relative "../rapid_fixtures"

# <form>, the second big tag. See spike/dryml/d_form.rb for what it is and what
# is stubbed.
class FormContractTest < Minitest::Test
  include ParamContract::Assertions

  def new_story = FormSpike::Story.new(:title => "")
  def saved_story = FormSpike::Story.new(:id => 1, :title => "First", :status => "draft")

  # Both halves of the form's own logic: creating and updating.
  def scenarios
    [{ :name => "registro nuevo", :this => new_story },
     { :name => "registro guardado", :this => saved_story }]
  end

  # No exceptions. Every extension point <form> declares -- its own, and those
  # of the tags it calls -- is reachable from a caller who only names <form>.
  def test_every_param_of_the_form_is_overridable
    assert_every_param_overridable(:form, scenarios)
  end

  # --- what the form itself does ----------------------------------------------

  def test_a_new_record_posts_to_the_collection
    output = Rapid.render(:form, {}, :this => new_story)

    assert_includes output, %(<form class="new story" action="/stories" method="post">)
    refute_includes output, "_method"
  end

  # Browsers do not do PUT, so Rails reads the method from a hidden field.
  def test_a_saved_record_puts_through_the_method_field
    output = Rapid.render(:form, {}, :this => saved_story)

    assert_includes output, %(action="/stories/1" method="post")
    assert_includes output, %(<input type="hidden" name="_method" value="PUT">)
  end

  # Without permission there is no form and no complaint -- what leaves DRYML's
  # `<else>` to take over.
  def test_no_permission_means_no_form_at_all
    locked = FormSpike::Story.new(:id => 2, :title => "Locked", :editable => false)

    assert_equal "", Rapid.render(:form, {}, :this => locked)
  end

  def test_an_explicit_action_skips_both_the_permission_check_and_the_css_classes
    locked = FormSpike::Story.new(:id => 2, :title => "Locked", :editable => false)
    output = Rapid.render(:form, { :action => "/custom" }, :this => locked)

    assert_includes output, %(<form action="/custom" method="post">)
  end

  def test_the_base_form_renders_without_a_record
    output = Rapid.render(:form, { :action => "/search", :method => "get" }, :this => nil)

    assert_includes output, %(<form action="/search" method="get">)
    refute_includes output, "authenticity_token"
  end

  # --- polymorphic dispatch ----------------------------------------------------

  def test_the_model_gets_its_own_form
    assert_includes Rapid.render(:form, {}, :this => new_story), %(name="story[title]")
    refute_includes Rapid.render(:form, { :action => "/x" }, :this => nil), "field-list"
  end

  # The regression this port found: `<form>` inside `<def tag="form" for="Story">`
  # used to dispatch back to itself, for ever.
  def test_the_generated_form_calls_the_base_one_and_not_itself
    assert_equal 1, Rapid.render(:form, {}, :this => new_story).scan("<form ").length
  end

  # --- the params --------------------------------------------------------------

  def test_the_submit_button_can_be_replaced
    output = Rapid.render(:form, {}, :this => new_story,
                          :submit => Rapid.parameter(:replace => true) do
                            tag("button", { :class => "primary" }) { text "Publish" }
                          end)

    assert_includes output, %(<button class="primary">Publish</button>)
    refute_includes output, %(<input type="submit")
  end

  def test_the_actions_are_an_element_param_so_attributes_merge
    output = Rapid.render(:form, {}, :this => new_story,
                          :actions => Rapid.parameter(:attributes => { :class => "footer" }))

    assert_includes output, %(<div class="actions footer">)
    assert_includes output, %(<input type="submit" value="Save">)
  end

  # A field's input lives two tag calls below the <form> the caller names:
  # <form> calls <field-list>, which declares one param per field.
  def test_a_field_is_reached_by_nesting_through_the_field_list
    output = Rapid.render(:form, {}, :this => saved_story,
                          :field_list => Rapid.parameter(
                            :params => { :title_view => Rapid.markup { tag("textarea") { text this.title } } }))

    assert_includes output, "<textarea>First</textarea>"
    assert_includes output, %(name="story[status]")
  end

  def test_a_single_field_input_can_be_replaced_without_touching_its_label
    output = Rapid.render(:form, {}, :this => saved_story,
                          :field_list => Rapid.parameter(
                            :params => { :title_tag => Rapid.parameter(:replace => true) { text "-" } }))

    assert_includes output, "<label>Title</label>-"
    assert_includes output, %(name="story[status]")
  end

  # <legend param if="&all_parameters[:legend]"/>: the param only exists when
  # the caller asks for it, and the caller is two levels up.
  def test_the_legend_appears_only_when_it_is_passed
    without = Rapid.render(:form, {}, :this => new_story)
    with = Rapid.render(:form, {}, :this => new_story,
                        :field_list => Rapid.parameter(
                          :params => { :legend => Rapid.markup { text "Details" } }))

    refute_includes without, "<legend>"
    assert_includes with, "<legend>Details</legend>"
  end

  # `<form merge param="default">`: the caller's content replaces the whole body
  # of the form, and `old` gives the standard one back.
  def test_the_body_of_the_form_can_be_replaced_wholesale
    output = Rapid.render(:form, {}, :this => new_story,
                          :default => Rapid.markup { text "just this" })

    assert_includes output, "just this"
    refute_includes output, "field-list"
    assert_includes output, "hidden-fields"
  end

  def test_the_replaced_body_can_wrap_the_standard_one
    output = Rapid.render(:form, {}, :this => new_story,
                          :default => Rapid.markup { tag("div", { :class => "extra" }) { old } })

    assert_includes output, %(<div class="extra"><fieldset class="field-list">)
  end

  # The errors only render when there are any, but the extension point is there
  # either way.
  #
  # What renders is the **catalogue's** `<error-messages>`, not a stand-in: this
  # port used to carry one of its own, from before the catalogue had one, and
  # the merge of layer 7 made the two meet in one registry. Asserting against
  # the real tag is the better test anyway -- it is what an application gets.
  def test_the_error_messages_render_when_the_record_has_errors
    broken = FormSpike::Story.new(:title => "", :errors => ["Title can't be blank"])
    output = Rapid.render(:form, {}, :this => broken)

    assert_includes output, %(class="error-messages")
    assert_includes output, %(<li>Title can&#39;t be blank</li>)
  end

  # --- ajax and the odd attributes ---------------------------------------------

  def test_the_ajax_attributes_are_taken_out_of_the_html_ones
    output = Rapid.render(:form, { :update => "comments" }, :this => new_story)

    assert_includes output, %(data-rapid-form="update")
    refute_includes output, %(update="comments")
  end

  def test_multipart_sets_the_encoding
    output = Rapid.render(:form, { :multipart => true }, :this => new_story)

    assert_includes output, %(enctype="multipart/form-data")
  end

end


# The pseudo-parameters against the real port, where the params sit behind tag
# calls rather than elements.
class FormPseudoParameterTest < Minitest::Test

  def new_story = FormSpike::Story.new(:title => "")

  # `<append-default:>` on a tag call goes *inside* the content the call was
  # handed -- inside the <form>, after the standard body -- which is the
  # "append parameter uses the default parameter" scenario of the feature.
  def test_append_on_a_tag_call_goes_inside_the_content_it_was_given
    output = Rapid.render(:form, {}, :this => new_story,
                          :append_default => Rapid.markup { tag("p") { text "Small print" } })

    assert_includes output, "<p>Small print</p></form>"
  end

  def test_prepend_on_a_tag_call_goes_before_the_content
    output = Rapid.render(:form, {}, :this => new_story,
                          :prepend_default => Rapid.markup { tag("p") { text "Heads up" } })

    assert_includes output, %(<p>Heads up</p><fieldset class="field-list">)
  end

  # It is applied once, not once per level: <form> forwards its params to the
  # base <form>, which declares a param of the same name.
  def test_it_is_applied_once_even_though_the_params_are_forwarded
    output = Rapid.render(:form, {}, :this => new_story,
                          :append_default => Rapid.markup { text "ONCE" })

    assert_equal 1, output.scan("ONCE").length
  end

  def test_before_and_after_go_outside_the_whole_call
    output = Rapid.render(:form, {}, :this => new_story,
                          :before_submit => Rapid.markup { text "[" },
                          :after_submit => Rapid.markup { text "]" })

    assert_includes output, %([<input type="submit" value="Save">])
  end

  def test_without_removes_a_tag_call
    output = Rapid.render(:form, { :without_submit => true }, :this => new_story)

    refute_includes output, %(<input type="submit")
    assert_includes output, "Cancel"
  end

  def test_they_are_reached_through_nesting_too
    output = Rapid.render(:form, {}, :this => new_story,
                          :field_list => Rapid.parameter(
                            :params => { :append_title_label => Rapid.markup { text " *" } }))

    assert_includes output, "<label>Title *</label>"
  end

  # <submit> renders <input type="submit"> and never paints the content it is
  # given, so appending to it cannot work. Saying so beats dropping it.
  def test_appending_to_a_tag_that_ignores_its_content_is_refused
    error = assert_raises(ArgumentError) do
      Rapid.render(:form, {}, :this => new_story,
                   :append_submit => Rapid.markup { text "!" })
    end

    assert_includes error.message, "does not paint the content"
  end

end
