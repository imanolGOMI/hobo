require "test_helper"
require "generators/hobo/migration/migrator"

# Ported from test/migration_generator.rdoctest, with the piece that file never
# had: the generated migrations are *executed*, up and then down, and the schema
# is compared before and after. The original only ever compared the generated
# text, which is why a `down` that could not run went unnoticed for years --
# see HALLAZGOS.md.
class MigrationGeneratorTest < Minitest::Test

  Migrator = Generators::Hobo::Migration::Migrator

  def setup
    drop_all_tables
    Migrator.ignore_tables = []
  end

  def teardown
    super
    drop_all_tables
  end

  # --- helpers --------------------------------------------------------------

  def generate
    Migrator.run
  end

  def run_migration(source)
    ActiveRecord::Migration.new.instance_eval(source)
    ActiveRecord::Base.descendants.each { |c| c.reset_column_information rescue nil }
  end

  # A comparable picture of the whole schema. It has to carry limit, default and
  # null as well as the type: a change_column that only moves a default would
  # otherwise look like no change at all.
  def schema_snapshot
    connection.tables.sort.map do |table|
      columns = connection.columns(table).map do |c|
        [c.name, c.type.to_s, c.limit, c.default, c.null, c.precision, c.scale]
      end.sort_by(&:first)
      indexes = connection.indexes(table).map { |i| [i.name, i.columns, i.unique] }.sort_by(&:first)
      [table, columns, indexes]
    end
  end

  # The assertion this whole file exists for.
  def assert_reversible(up, down, message = nil)
    before = schema_snapshot

    run_migration(up)
    after = schema_snapshot
    refute_equal before, after, "the up migration changed nothing#{" (#{message})" if message}"

    run_migration(down)
    assert_equal before, schema_snapshot,
                 "the down migration did not undo the up#{" (#{message})" if message}"
  end

  # --- introduction ---------------------------------------------------------

  def test_an_empty_application_has_nothing_to_migrate
    assert_equal ["", ""], generate
  end

  def test_models_without_a_fields_declaration_are_ignored
    define_model(:Advert)

    assert_equal ["", ""], generate
  end

  def test_ignored_tables_are_left_alone
    connection.create_table(:green_fishes) { |t| t.string :name }
    Migrator.ignore_tables = ["green_fishes"]

    assert_equal ["", ""], generate
  end

  # --- creating a table -----------------------------------------------------

  def test_create_the_table
    define_model(:Advert) { fields { name :string, :limit => 250 } }

    up, down = generate

    assert_match(/create_table :adverts/, up)
    assert_match(/t\.string\s+:name, :limit => 250/, up)
    assert_match(/drop_table :adverts/, down)
    assert_reversible(up, down)
  end

  def test_create_the_table_with_several_types
    define_model(:Advert) do
      fields do
        name         :string, :limit => 250
        body         :text
        published_at :datetime
        price        :integer
        live         :boolean
      end
    end

    up, down = generate
    assert_reversible(up, down)
  end

  # --- adding and removing fields -------------------------------------------

  def test_add_fields_to_an_existing_table
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) do
      fields do
        name :string, :limit => 250
        body :text
        price :integer
      end
    end

    up, down = generate

    assert_match(/add_column :adverts, :body, :text/, up)
    assert_match(/add_column :adverts, :price, :integer/, up)
    assert_match(/remove_column :adverts, :body/, down)
    assert_reversible(up, down)
  end

  def test_remove_fields_from_an_existing_table
    connection.create_table :adverts do |t|
      t.string :name, :limit => 250
      t.text   :body
    end
    define_model(:Advert) { fields { name :string, :limit => 250 } }

    up, down = generate

    assert_match(/remove_column :adverts, :body/, up)
    assert_match(/add_column :adverts, :body, :text/, down)
    assert_reversible(up, down)
  end

  # --- changing a field -----------------------------------------------------

  def test_change_a_type
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :text } }

    up, down = generate

    assert_match(/change_column :adverts, :name/, up)
    assert_reversible(up, down)
  end

  def test_add_a_default
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :string, :limit => 250, :default => "No Name" } }

    up, down = generate

    assert_match(/change_column :adverts, :name.*:default => "No Name"/, up)
    assert_reversible(up, down)
  end

  def test_change_a_limit
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :string, :limit => 100 } }

    up, down = generate

    assert_match(/change_column :adverts, :name.*:limit => 100/, up)
    assert_reversible(up, down)
  end

  # --- timestamps -----------------------------------------------------------

  def test_timestamps_are_created_as_a_pair
    define_model(:Advert) do
      fields do
        name :string, :limit => 250
        timestamps
      end
    end

    up, down = generate

    assert_match(/created_at/, up)
    assert_match(/updated_at/, up)
    assert_reversible(up, down)
  end

  # --- indexes --------------------------------------------------------------

  def test_an_index_is_added_and_removed
    define_model(:Advert) do
      fields { name :string, :limit => 250 }
      index :name
    end

    up, down = generate

    assert_match(/add_index :adverts, \[:name\]/, up)
    assert_reversible(up, down)
  end

  def test_a_unique_index
    define_model(:Advert) do
      fields { name :string, :limit => 250 }
      index :name, :unique => true
    end

    up, down = generate

    assert_match(/:unique => true/, up)
    assert_reversible(up, down)
  end

  # --- associations ---------------------------------------------------------

  def test_a_belongs_to_creates_its_foreign_key_and_index
    define_model(:Category) { fields { name :string, :limit => 250 } }
    define_model(:Advert) do
      fields { name :string, :limit => 250 }
      belongs_to :category
    end

    up, down = generate

    assert_match(/category_id/, up)
    assert_reversible(up, down)
  end

  # --- dropping a table -----------------------------------------------------

  def test_drop_a_table_that_no_model_claims
    connection.create_table(:adverts) { |t| t.string :name }

    up, down = generate

    assert_match(/drop_table :adverts/, up)
    # The down has to be able to recreate it -- this is the case that used to
    # be generated without column types and only failed when actually run.
    assert_match(/create_table "adverts"/, down)
    assert_reversible(up, down)
  end

  # --- several changes at once ----------------------------------------------

  def test_several_changes_in_one_migration
    connection.create_table :adverts do |t|
      t.string :name, :limit => 250
      t.text   :body
    end
    define_model(:Advert) do
      fields do
        name  :string, :limit => 100
        price :integer
      end
    end

    up, down = generate
    assert_reversible(up, down, "rename, change and add together")
  end

end
