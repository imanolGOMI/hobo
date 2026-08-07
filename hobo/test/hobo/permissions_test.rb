require "test_helper"

# Piece 4: the permission checks.
#
# They used to hang off `_create_record` and `_update_record`, which are private
# to ActiveRecord, and off a `destroy` wrapped with alias_method_chain. They hang
# off before_create / before_update / before_destroy now, which mean the same
# thing and also catch the paths those methods do not.
class PermissionsTest < Minitest::Test

  def setup
    connection = ActiveRecord::Base.connection
    connection.create_table(:projects, :force => true) { |t| t.string :name }
    connection.create_table(:tasks, :force => true) do |t|
      t.string  :title
      t.integer :project_id
    end

    Object.const_set(:Project, Class.new(ActiveRecord::Base))
    Object.const_set(:Task, Class.new(ActiveRecord::Base))

    Project.class_eval do
      include Hobo::Model
      fields { name :string }
      has_many :tasks, :dependent => :destroy

      def create_permitted?  = acting_user == "owner"
      def update_permitted?  = acting_user == "owner"
      def destroy_permitted? = acting_user == "owner"
    end

    Task.class_eval do
      include Hobo::Model
      fields { title :string }
      belongs_to :project, :optional => true

      def create_permitted?  = true
      def update_permitted?  = true
      def destroy_permitted? = acting_user == "owner"
    end
  end

  def teardown
    HoboTest.clean_up(:Task, :Project)
  end

  # --- with nobody acting, nothing is checked ---------------------------------

  def test_without_an_acting_user_nothing_is_checked
    project = Project.new(:name => "Silent")
    assert project.save
  end

  # --- create -----------------------------------------------------------------

  def test_creating_is_refused_when_create_permitted_says_no
    error = assert_raises(Hobo::PermissionDeniedError) do
      Project.user_create("stranger", :name => "Nope")
    end

    assert_includes error.message, "create"
    assert_equal 0, Project.count
  end

  def test_creating_is_allowed_when_create_permitted_says_yes
    project = Project.user_create("owner", :name => "Yes")

    assert project.persisted?
    assert_equal 1, Project.count
  end

  # --- update -----------------------------------------------------------------

  def test_updating_is_refused_when_update_permitted_says_no
    project = Project.user_create("owner", :name => "Mine")

    assert_raises(Hobo::PermissionDeniedError) do
      project.user_update_attributes("stranger", :name => "Yours")
    end

    assert_equal "Mine", project.reload.name
  end

  def test_updating_is_allowed_when_update_permitted_says_yes
    project = Project.user_create("owner", :name => "Mine")
    project.user_update_attributes("owner", :name => "Still mine")

    assert_equal "Still mine", project.reload.name
  end

  # The old check sat on `_update_record`, which only runs when there is
  # something to write. before_update runs on the save either way, so an update
  # with no changes is checked too.
  def test_an_update_with_no_changes_is_still_checked
    project = Project.user_create("owner", :name => "Mine")

    assert_raises(Hobo::PermissionDeniedError) { project.user_save("stranger") }
  end

  # --- destroy ----------------------------------------------------------------

  def test_destroying_is_refused_when_destroy_permitted_says_no
    project = Project.user_create("owner", :name => "Mine")

    assert_raises(Hobo::PermissionDeniedError) { project.user_destroy("stranger") }
    assert_equal 1, Project.count
  end

  def test_destroying_is_allowed_when_destroy_permitted_says_yes
    project = Project.user_create("owner", :name => "Mine")
    project.user_destroy("owner")

    assert_equal 0, Project.count
  end

  # --- dependent destroy ------------------------------------------------------
  #
  # This is what the three association wrappers were meant to do, and had not
  # done since Rails 4.1 stopped generating the methods they redefined.

  def test_the_children_of_a_dependent_destroy_are_checked_too
    project = Project.user_create("owner", :name => "Mine")
    project.tasks.create!(:title => "First")

    # The project itself may be destroyed by "owner", but the check happens on
    # each task as well, and Task only lets "owner" destroy.
    project.user_destroy("owner")

    assert_equal 0, Project.count
    assert_equal 0, Task.count
  end

  def test_a_child_that_refuses_stops_the_whole_destroy
    Task.class_eval { def destroy_permitted? = false }

    project = Project.user_create("owner", :name => "Mine")
    project.tasks.create!(:title => "Stubborn")

    assert_raises(Hobo::PermissionDeniedError) { project.user_destroy("owner") }

    assert_equal 1, Project.count, "el proyecto no se borra si su hijo se niega"
    assert_equal 1, Task.count
  end

  # The check runs before Rails' own dependent-destroy callback: there is no
  # point destroying the children of a record you may not destroy.
  def test_a_refused_destroy_leaves_the_children_alone
    project = Project.user_create("owner", :name => "Mine")
    project.tasks.create!(:title => "Safe")

    assert_raises(Hobo::PermissionDeniedError) { project.user_destroy("stranger") }

    assert_equal 1, Task.count
  end

  # --- creating through an association ----------------------------------------
  #
  # The block that used to cover this reopened AssociationProxy, a class that
  # went away in Rails 4.0, so it had not run in twelve years. The callbacks
  # catch it without anyone having to wrap anything.

  def test_creating_through_an_association_is_checked
    Task.class_eval { def create_permitted? = acting_user == "owner" }

    project = Project.user_create("owner", :name => "Mine")
    project.acting_user = "stranger"

    assert_raises(Hobo::PermissionDeniedError) { project.tasks.create!(:title => "Sneaky") }
    assert_equal 0, Task.count
  end

end
