require "test_helper"
require "action_controller"
require "responders"
require "hobo/controller/model"

# Piece 11: the auto-actions.
#
# These run without a Rails application on purpose. A controller that can only
# be examined inside a booted app is a controller nobody checks -- and until this
# layer, this one could not even be *defined* outside one: a helper did
# `include Rails.application.routes.url_helpers` at load time.
#
# What needs a real application -- routing, rendering, a request -- is in
# test/integration, against the app that `rake test:app` builds.
class ControllerTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:stories, :force => true) do |t|
      t.string  :title
      t.integer :position
    end

    Object.const_set(:Story, Class.new(ActiveRecord::Base))
    Story.class_eval do
      include Hobo::Model
      fields { title :string }
      def view_permitted?(field) = true
    end

    Story.create!(:title => "Beta")
    Story.create!(:title => "Alpha")
  end

  def teardown
    HoboTest.clean_up(:StoriesController, :Story)
  end

  def controller_class(&block)
    Object.send(:remove_const, :StoriesController) if Object.const_defined?(:StoriesController)
    Object.const_set(:StoriesController, Class.new(ActionController::Base))
    StoriesController.class_eval do
      include Hobo::Controller::Model
    end
    StoriesController.class_eval(&block) if block
    StoriesController
  end

  # --- what the controller works out for itself -------------------------------

  def test_the_model_is_worked_out_from_the_controller_name
    assert_equal Story, controller_class.model
    # `model_name` here is the controller's own, the underscored one Rails uses
    # for params and routes -- not ActiveModel's.
    assert_equal "story", controller_class.model_name.to_s
  end

  # --- auto_actions -----------------------------------------------------------

  def test_auto_actions_defines_the_actions_it_is_given_and_no_others
    klass = controller_class { auto_actions :index, :show }

    assert_equal %i[index show], klass.instance_methods(false).sort & %i[index show new create edit update destroy]
  end

  def test_auto_actions_all_defines_the_usual_seven
    klass = controller_class { auto_actions :all }

    %i[index show new create edit update destroy].each do |action|
      assert_includes klass.instance_methods(false), action, "falta #{action}"
    end
  end

  def test_auto_actions_can_leave_some_out
    klass = controller_class { auto_actions :all, :except => [:destroy, :edit] }

    assert_includes klass.instance_methods(false), :index
    refute_includes klass.instance_methods(false), :destroy
    refute_includes klass.instance_methods(false), :edit
  end

  def test_include_action_answers_for_each_one
    klass = controller_class { auto_actions :index, :show }

    assert klass.include_action?(:index)
    refute klass.include_action?(:destroy)
  end

  # --- the helpers must not become actions ------------------------------------
  #
  # Everything public a controller picks up is a routable action. `hide_action`
  # kept Hobo's helpers out of that list until Rails 5 removed it; without a
  # replacement, `object_url` and friends would be reachable over HTTP.

  def test_the_helper_methods_are_not_actions
    klass = controller_class { auto_actions :index }

    assert_includes klass.action_methods, "index"
    refute_includes klass.action_methods, "object_url"
    refute_includes klass.action_methods, "can_view?"
  end

  def test_the_hidden_names_are_inherited_by_a_subclass
    parent = controller_class { auto_actions :index }
    child = Class.new(parent)

    refute_includes child.action_methods, "object_url"
  end

  # --- sorting ----------------------------------------------------------------

  def with_params(params)
    controller = controller_class.new
    controller.define_singleton_method(:params) { params }
    controller
  end

  def test_a_sort_parameter_becomes_an_order_clause
    controller = with_params(:sort => "title")

    assert_equal "title asc", controller.send(:parse_sort_param, :title).to_s
    assert_equal "title", controller.instance_variable_get(:@sort_field)
    assert_equal "asc", controller.instance_variable_get(:@sort_direction)
  end

  def test_a_leading_minus_means_descending
    controller = with_params(:sort => "-title")

    assert_equal "title desc", controller.send(:parse_sort_param, :title).to_s
  end

  # The whitelist: a field the caller did not offer is not sortable, whatever
  # the parameter says.
  def test_a_field_that_was_not_offered_is_refused
    controller = with_params(:sort => "position")

    assert_nil controller.send(:parse_sort_param, :title)
  end

  def test_a_parameter_that_is_not_a_field_name_at_all_is_refused
    controller = with_params(:sort => "title; drop table stories")

    assert_nil controller.send(:parse_sort_param, :title)
  end

  def test_no_sort_parameter_means_no_order
    controller = with_params({})

    assert_nil controller.send(:parse_sort_param, :title)
  end

  # --- find_or_paginate -------------------------------------------------------

  def test_order_by_is_applied_to_the_relation
    controller = with_params({})
    result = controller.send(:find_or_paginate, Story, :order_by => Arel.sql("title asc"), :paginate => false)

    assert_equal %w[Alpha Beta], result.map(&:title)
  end

  def test_the_model_default_order_is_used_when_nothing_else_says
    Story.send(:set_default_order, "title desc")
    controller = with_params({})
    result = controller.send(:find_or_paginate, Story, :paginate => false)

    assert_equal %w[Beta Alpha], result.map(&:title)
  end

  def test_a_scope_option_is_applied
    Story.singleton_class.define_method(:only_alpha) { where(:title => "Alpha") }
    controller = with_params({})
    result = controller.send(:find_or_paginate, Story, :scope => :only_alpha, :paginate => false)

    assert_equal %w[Alpha], result.map(&:title)
  end

  # --- who is logged in ---------------------------------------------------------
  #
  # `guest?` is Hobo's own idea, and the User that `bin/rails generate
  # authentication` writes has never heard of it. Piece 15 handed the user to
  # Rails, so `logged_in?` cannot assume Hobo's user model -- it did, in a
  # before_action, and every request of a signed-in person died before any
  # action ran. It stayed hidden while the session was never resumed, which is
  # to say: behind the bug that made everybody a guest.

  # The helper methods are protected, as they are in a controller, so the
  # stand-in exposes the one under test rather than the test reaching in.
  class PlainHelper
    include HoboPermissionsHelper
    attr_accessor :user
    def current_user = @user
    public :logged_in?
  end

  RailsUser = Struct.new(:email_address)
  HoboUser  = Struct.new(:name) { def guest? = false }

  def test_a_rails_user_counts_as_logged_in
    helper = PlainHelper.new
    helper.user = RailsUser.new("admin@example.com")

    assert helper.logged_in?
  end

  def test_hobos_own_guest_still_counts_as_nobody
    helper = PlainHelper.new
    helper.user = Hobo::Model::Guest.new

    refute helper.logged_in?
  end

  def test_a_hobo_user_still_counts_as_logged_in
    helper = PlainHelper.new
    helper.user = HoboUser.new("Imanol")

    assert helper.logged_in?
  end

  def test_nobody_at_all_is_not_logged_in
    assert_equal false, PlainHelper.new.logged_in?
  end

end
