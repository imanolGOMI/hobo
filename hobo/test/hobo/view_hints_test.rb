require "test_helper"

# Piece 7: view hints.
#
# The verdict in PLAN.md is that this one stays and grows: it is the only place
# that says how a model wants to be *shown*, and there is nothing like it in
# Rails or in the ecosystem. So the first job is to pin down what it does today.
class ViewHintsTest < Minitest::Test

  def setup
    connection = ActiveRecord::Base.connection
    connection.create_table(:projects, :force => true) { |t| t.string :name }
    connection.create_table(:tasks, :force => true) do |t|
      t.string  :title
      t.boolean :done
      t.boolean :urgent
      t.integer :project_id
    end

    Object.const_set(:Project, Class.new(ActiveRecord::Base))
    Object.const_set(:Task, Class.new(ActiveRecord::Base))

    Project.class_eval do
      include Hobo::Model
      fields { name :string }
      has_many :tasks
    end

    Task.class_eval do
      include Hobo::Model
      fields do
        title  :string
        done   :boolean
        urgent :boolean
      end
      belongs_to :project, :optional => true
    end
  end

  def teardown
    HoboTest.clean_up(:TaskHints, :ProjectHints, :Task, :Project)
  end

  # --- the hints class --------------------------------------------------------

  def test_a_model_gets_a_hints_class_on_demand
    assert_equal "ProjectHints", Project.view_hints.name
    assert_operator Project.view_hints, :<, Hobo::Model::ViewHints
  end

  def test_the_hints_class_knows_its_model
    assert_equal Project, Project.view_hints.model
  end

  def test_asking_twice_gives_the_same_class
    assert_same Project.view_hints, Project.view_hints
  end

  # --- children ---------------------------------------------------------------
  #
  # `children` says which associations are *part of* the record for display
  # purposes. It is read lazily on purpose: declaring it in the model would
  # otherwise force the child model to load while the parent is still loading.

  def test_children_are_empty_by_default
    assert_equal [], Project.view_hints.children
  end

  def test_children_are_resolved_when_they_are_read_and_not_when_declared
    Project.children :tasks

    assert_equal [:tasks], Project.view_hints.children
  end

  def test_the_first_child_is_the_primary_one_and_the_rest_are_secondary
    Project.children :tasks

    assert_equal :tasks, Project.view_hints.primary_children
    assert_equal [], Project.view_hints.secondary_children
  end

  # Declaring the children of a parent tells the child who its parent is, which
  # is what lets a child page link back up without saying so twice.
  def test_declaring_children_teaches_the_child_who_its_parent_is
    Project.children :tasks
    Project.view_hints.children # force the lazy read

    assert_equal :project, Task.view_hints.parent
  end

  def test_a_parent_declared_by_hand_is_not_overwritten
    Task.view_hints.parent :something_else
    Project.children :tasks
    Project.view_hints.children

    assert_equal :something_else, Task.view_hints.parent
  end

  # --- inline booleans --------------------------------------------------------

  def test_inline_booleans_are_empty_by_default
    assert_equal [], Task.view_hints.inline_booleans
  end

  def test_inline_booleans_can_be_named
    Task.inline_booleans :done

    assert_equal %w[done], Task.view_hints.inline_booleans
  end

  # `inline_booleans true` means "all of them", worked out from the columns.
  def test_inline_booleans_true_means_every_boolean_column
    Task.inline_booleans true

    assert_equal %w[done urgent], Task.view_hints.inline_booleans
  end

  # --- pagination and sorting -------------------------------------------------

  def test_a_model_paginates_unless_it_is_sortable
    assert Task.view_hints.paginate?
  end

  def test_pagination_can_be_turned_off
    Task.view_hints.paginate? false

    refute Task.view_hints.paginate?
  end

  # `sortable?` asks acts_as_list, which is not installed here. It has to answer
  # false rather than blow up.
  def test_sortable_is_false_without_acts_as_list
    refute Task.view_hints.sortable?
  end

  def test_sorting_can_be_turned_on_by_hand
    Task.view_hints.sortable? true

    assert Task.view_hints.sortable?
    refute Task.view_hints.paginate?, "lo ordenable no se pagina"
  end

  # --- the methods that were removed on purpose -------------------------------
  #
  # They raise instead of quietly doing the wrong thing: translation belongs to
  # Rails' i18n now, not to the hints.

  def test_the_translation_methods_say_where_to_go_instead
    %i[model_name model_name_plural field_name field_names].each do |method|
      error = assert_raises(NotImplementedError) { Task.view_hints.send(method) }
      assert_includes error.message, "no longer supported"
    end
  end

end
