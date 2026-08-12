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
    HoboTest.clean_up(:Article, :Keyed)
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

  # A lifecycle declares two columns, so the model has to be one the migration
  # generator looks at. It was not: `include_in_migration` is turned on by a
  # model writing its own `fields do`, and a user model whose only Hobo fields
  # came from its lifecycle was skipped -- `hobo:migration` said "database and
  # models match" while `key_timestamp` did not exist, and the first signup died
  # with "can't write unknown attribute".
  def test_a_model_whose_fields_come_from_the_lifecycle_is_migrated
    Object.const_set(:Bare, Class.new(ActiveRecord::Base))
    ::Bare.class_eval do
      self.table_name = "articles"
      include Hobo::Model
      def create_permitted?  = true
      def update_permitted?  = true
      def destroy_permitted? = true

      lifecycle do
        state :new, :default => true
        state :old
        transition :age, { :new => :old }
      end
    end

    assert ::Bare.include_in_migration, "un modelo con lifecycle tiene columnas que migrar"
    assert_includes ::Bare.field_specs.keys.map(&:to_s), "key_timestamp"
  ensure
    HoboTest.clean_up(:Bare)
  end

  # --- the keys -----------------------------------------------------------------
  #
  # The half of lifecycles that only an application uses: a step with
  # `:new_key => true` puts a one-use key in a mail, and whoever comes back with
  # it is allowed to make the next move. Activation mails and invitations are
  # built on this.
  #
  # It was **broken for every Rails 8 application** and no test could see it: the
  # key was signed with `Rails.application.config.secret_token`, which Rails
  # removed in 5.2, and this suite had never asked for a key.
  # Declared inside the test and taken away afterwards, like `Article`: a model
  # defined at load time stays in `Hobo::Model.all_models` for the whole run,
  # and the migration generator's suite -- which checks that an empty
  # application has nothing to migrate -- then finds it. Same lesson as layer 2,
  # third time.
  def keyed_model
    return ::Keyed if Object.const_defined?(:Keyed)

    Object.const_set(:Keyed, Class.new(ActiveRecord::Base))
    ::Keyed.class_eval do
      self.table_name = "articles"
      include Hobo::Model
      fields { title :string }
      def create_permitted?  = true
      def update_permitted?  = true
      def destroy_permitted? = true

      lifecycle :key_timeout => 1.day do
        state :invited, :default => true
        state :active

        create :invite, :params => [:title], :become => :invited, :new_key => true
        transition :accept, { :invited => :active }, :available_to => :key_holder
      end
    end
    ::Keyed
  end

  def with_secret(secret = "un-secreto-de-pruebas")
    was = ENV["HOBO_LIFECYCLE_SECRET"]
    ENV["HOBO_LIFECYCLE_SECRET"] = secret
    yield
  ensure
    ENV["HOBO_LIFECYCLE_SECRET"] = was
  end

  def invited
    with_secret { keyed_model.lifecycle.invite(nil, :title => "Invitada") }
  end

  def test_a_step_with_a_new_key_hands_one_out
    key = with_secret { invited.lifecycle.key }

    refute_nil key, "un paso con :new_key tiene que dar una clave"
    assert_equal 40, key.length, "sha1 en hexadecimal"
  end

  def test_the_same_record_gives_the_same_key
    record = invited

    assert_equal with_secret { record.lifecycle.key }, with_secret { record.lifecycle.key }
  end

  # Two records, two keys: a key that did not depend on the record would open
  # everybody's door.
  def test_two_records_get_different_keys
    refute_equal with_secret { invited.lifecycle.key }, with_secret { invited.lifecycle.key }
  end

  def test_another_secret_gives_another_key
    record = invited

    refute_equal with_secret("uno") { record.lifecycle.key },
                 with_secret("otro") { record.lifecycle.key }
  end

  # Whoever comes back with the key may make the move; whoever comes back with
  # somebody else's may not.
  def test_the_key_holder_may_make_the_move
    record = invited

    with_secret do
      record.lifecycle.provided_key = record.lifecycle.key
      assert record.lifecycle.can_accept?(nil), "con la clave buena se puede"

      record.lifecycle.provided_key = "0" * 40
      refute record.lifecycle.can_accept?(nil), "con una clave inventada, no"
    end
  end

  # A key with nothing to sign it is not a key.
  def test_it_refuses_to_sign_with_nothing
    record = invited

    with_secret(nil) do
      assert_raises(Hobo::Model::Lifecycles::LifecycleError) { record.lifecycle.key }
    end
  end

end
