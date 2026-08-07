require "test_helper"

# Piece 5: lifecycles.
#
# The verdict in PLAN.md is that this one stays and stays Hobo's own: no state
# machine gem gives what it gives, because a lifecycle here is not only states
# and transitions, it also says *who* may make each move and what parameters
# each move takes. That is what feeds the generated forms and buttons.
#
# The example is the one from the old doctest, which is the canonical one.
class LifecyclesTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:articles, :force => true) do |t|
      t.string   :title
      t.string   :state
      t.datetime :key_timestamp
    end

    Object.const_set(:Article, Class.new(ActiveRecord::Base))
    Article.class_eval do
      include Hobo::Model
      fields { title :string }

      # `:available_to` names something on the record: an association, or a
      # method like this one.
      def owner = "the boss"

      def create_permitted?  = true
      def update_permitted?  = true
      def destroy_permitted? = true

      lifecycle do
        state :draft, :default => true
        state :published

        create :write, :params => [:title], :become => :draft
        transition :publish, { :draft => :published }
        transition :retract, { :published => :draft }
        transition :bin,     { :draft => :destroy }
      end
    end
  end

  def teardown
    HoboTest.clean_up(:Article)
  end

  # --- declaring one ----------------------------------------------------------

  def test_a_model_with_a_lifecycle_says_so
    assert Article.has_lifecycle?
    assert_equal Article::Lifecycle, Article.lifecycle
  end

  def test_the_state_field_is_declared_with_the_default_state
    assert_includes Article.field_specs.keys.map(&:to_s), "state"
    assert_equal "draft", Article.field_specs[:state].options[:default]
  end

  def test_the_states_and_transitions_are_registered
    assert_equal %w[draft published], Article::Lifecycle.states.keys.map(&:to_s).sort
    assert_equal %w[bin publish retract], Article::Lifecycle.transitions.map { |t| t.name.to_s }.sort
    assert_equal %w[write], Article::Lifecycle.creators.keys.map(&:to_s)
  end

  # --- creating through a creator ---------------------------------------------

  def test_a_creator_creates_the_record_in_the_state_it_names
    article = Article::Lifecycle.write(nil, :title => "First")

    assert article.persisted?
    assert_equal "draft", article.state
  end

  # The creator declares its parameters, and anything else is left alone: the
  # state field is not something a form may set.
  def test_the_creator_ignores_parameters_it_does_not_declare
    article = Article::Lifecycle.write(nil, :title => "First", :state => "published")

    assert_equal "draft", article.state
  end

  # --- transitions ------------------------------------------------------------

  def test_a_transition_moves_the_record_to_the_next_state
    article = Article::Lifecycle.write(nil, :title => "First")
    article.lifecycle.publish!(nil)

    assert_equal "published", article.reload.state
  end

  def test_a_transition_that_does_not_start_here_is_not_available
    article = Article::Lifecycle.write(nil, :title => "First")

    refute_includes article.lifecycle.available_transitions.map(&:name), :retract
    assert_includes article.lifecycle.available_transitions.map(&:name), :publish
  end

  def test_a_transition_out_of_its_state_is_refused
    article = Article::Lifecycle.write(nil, :title => "First")

    assert_raises(Hobo::Model::Lifecycles::LifecycleError) { article.lifecycle.retract!(nil) }
  end

  # `:destroy` is a pseudo-state: arriving at it destroys the record.
  def test_a_transition_into_destroy_destroys_the_record
    article = Article::Lifecycle.write(nil, :title => "First")
    article.lifecycle.bin!(nil)

    assert_equal 0, Article.count
  end

  # --- who may do what --------------------------------------------------------

  def test_a_transition_can_be_restricted_to_some_users
    Article.class_eval do
      lifecycle do
        transition :archive, { :draft => :published }, :available_to => :owner
      end
    end
    article = Article::Lifecycle.write(nil, :title => "First")

    assert article.lifecycle.can_archive?("the boss")
    refute article.lifecycle.can_archive?("anybody else")
  end

  def test_the_transitions_available_to_a_user_are_listed
    Article.class_eval do
      lifecycle do
        transition :archive, { :draft => :published }, :available_to => :owner
      end
    end
    article = Article::Lifecycle.write(nil, :title => "First")

    names = article.lifecycle.available_transitions_for("the boss").map(&:name)
    assert_includes names, :archive

    names = article.lifecycle.available_transitions_for("anybody else").map(&:name)
    refute_includes names, :archive
  end

  # --- the step in progress ---------------------------------------------------
  #
  # While a step is running, `valid?` validates in the context of that step and
  # the permission checks stand aside: the lifecycle is the authority on what is
  # allowed, not create_permitted? / update_permitted?.

  def test_a_step_in_progress_exempts_the_record_from_permission_checks
    Article.class_eval { def update_permitted? = false }

    article = Article::Lifecycle.write(nil, :title => "First")
    article.lifecycle.publish!(nil)

    assert_equal "published", article.reload.state
  end

  def test_there_is_no_active_step_once_the_transition_is_done
    article = Article::Lifecycle.write(nil, :title => "First")
    article.lifecycle.publish!(nil)

    assert_nil article.lifecycle.active_step
  end

end
