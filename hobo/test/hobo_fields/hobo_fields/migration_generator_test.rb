require "test_helper"
require_relative "../databases"
require "generators/hobo/migration/migrator"

# Ported from test/migration_generator.rdoctest, with the two pieces that file
# never had:
#
#   1. The generated migrations are *executed*, up and then down, and the schema
#      is compared before and after. The original only compared the generated
#      text, which is why a `down` that could not run went unnoticed for years
#      -- see HALLAZGOS.md.
#   2. It runs against every reachable adapter, not just sqlite. The generator
#      asks the adapter for native types, schema dumping and column
#      introspection, so an adapter it is not tested against is an adapter it
#      does not support.
#
# Assertions on the generated *text* are deliberately loose, because the wording
# legitimately differs per adapter (native limits, quoting). The real assertion
# is assert_reversible.
module MigrationGeneratorBattery

  Migrator = Generators::Hobo::Migration::Migrator

  def setup
    HoboFields::TestDatabases.connect(self.class.adapter)
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
    context = message ? " (#{message})" : ""
    before = schema_snapshot

    run_migration(up)
    refute_equal before, schema_snapshot, "the up migration changed nothing#{context}"

    run_migration(down)
    assert_equal before, schema_snapshot, "the down migration did not undo the up#{context}"
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
    assert_match(/t\.string\s+:name/, up)
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
        name  :string, :limit => 250
        body  :text
        price :integer
      end
    end

    up, down = generate

    assert_match(/add_column :adverts, :body, :text/, up)
    assert_match(/add_column :adverts, :price, :integer/, up)
    assert_match(/remove_column :adverts, :body/, down)
    assert_reversible(up, down)
  end

  # Somebody else's table.
  #
  # Hobo goes into an application that already exists -- `include Hobo::Model` on
  # a model Rails made, or a lifecycle putting its state columns on the `User`
  # that `bin/rails generate authentication` wrote. There, Hobo did not describe
  # the table: it added to it, and everything else belongs to somebody else.
  #
  # The generator offered to **drop `email_address` and `password_digest`**, and
  # then asked for confirmation on a terminal -- which in a script is a question
  # nobody answers and in front of a person is one question too many. Whoever
  # said yes lost their users.
  def test_a_table_hobo_did_not_describe_only_gets_what_hobo_adds
    connection.create_table(:users) do |t|
      t.string :email_address, :null => false
      t.string :password_digest, :null => false
    end

    define_model(:User) do
      # No `fields do` block. This is what a lifecycle does when it declares its
      # state and its key timestamp: it asks to be migrated (`fields` with no
      # block) and then adds its columns one by one. Written out here because
      # lifecycles live a layer above this suite.
      fields
      declare_field(:state, :string)
      declare_field(:key_timestamp, :datetime)
    end

    up, down = generate

    assert_match(/add_column :users, :state/, up)
    assert_match(/add_column :users, :key_timestamp/, up)
    refute_match(/remove_column :users, :email_address/, up, "esa columna no es de Hobo")
    refute_match(/remove_column :users, :password_digest/, up, "esa columna no es de Hobo")
    assert_reversible(up, down)
  end

  # The same thing said out loud, which is what an application writes.
  def test_add_fields_says_these_are_mine_and_the_rest_is_not
    connection.create_table(:users) { |t| t.string :email_address, :null => false }
    define_model(:User) { add_fields { administrator :boolean, :default => false } }

    up, down = generate

    assert_match(/add_column :users, :administrator, :boolean/, up)
    refute_match(/remove_column :users, :email_address/, up)
    assert_reversible(up, down)
  end

  # And a model that does describe its table keeps saying what is not in it.
  def test_a_table_the_model_describes_still_loses_what_is_not_declared
    connection.create_table(:adverts) do |t|
      t.string :name
      t.string :sobra
    end
    define_model(:Advert) { fields { name :string } }

    up, _down = generate

    assert_match(/remove_column :adverts, :sobra/, up)
  end

  def test_remove_fields_from_an_existing_table
    connection.create_table :adverts do |t|
      t.string :name, :limit => 250
      t.text   :body
    end
    define_model(:Advert) { fields { name :string, :limit => 250 } }

    up, down = generate

    assert_match(/remove_column :adverts, :body/, up)
    # The type has to survive the round trip through the schema dumper: this is
    # exactly what used to come out empty.
    assert_match(/add_column :adverts, :body, :\w+/, down)
    assert_reversible(up, down)
  end

  # --- changing a field -----------------------------------------------------

  def test_change_a_type
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :text } }

    up, down = generate

    assert_match(/change_column :adverts, :name/, up)
    assert_match(/change_column :adverts, :name, :\w+/, down)
    assert_reversible(up, down)
  end

  def test_add_a_default
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :string, :limit => 250, :default => "No Name" } }

    up, down = generate

    assert_match(/change_column :adverts, :name/, up)
    assert_match(/:default => "No Name"/, up)
    assert_reversible(up, down)
  end

  def test_change_a_limit
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) { fields { name :string, :limit => 100 } }

    up, down = generate

    assert_match(/change_column :adverts, :name/, up)
    assert_match(/:limit => 100/, up)
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

  def test_an_index_added_to_an_existing_table
    connection.create_table(:adverts) { |t| t.string :name, :limit => 250 }
    define_model(:Advert) do
      fields { name :string, :limit => 250 }
      index :name
    end

    up, down = generate
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
    # The down has to be able to recreate it. This is the case that used to be
    # generated without column types and only failed when actually run.
    assert_match(/create_table "adverts"/, down)
    refute_match(/Could not dump table/, down)
    assert_reversible(up, down)
  end

  # --- the migration file itself --------------------------------------------

  # The battery above evals the up/down bodies directly, which would not have
  # caught a broken *template*: inheriting from ActiveRecord::Migration with no
  # version raises since Rails 5, and def self.up is Rails 3 style.
  def test_the_generated_migration_file_is_a_runnable_migration_class
    define_model(:Advert) { fields { name :string, :limit => 250 } }
    up, down = generate

    # The template reads instance variables of the generator, so fill them in
    # by substitution rather than setting up a Thor generator here.
    source = File.read(template_path)
      .gsub("<%= @migration_class_name %>", "CreateAdverts")
      .gsub("<%= ActiveRecord::Migration.current_version %>", ActiveRecord::Migration.current_version.to_s)
      .gsub("<%= @up %>", up)
      .gsub("<%= @down %>", down)

    Object.class_eval(source)
    migration = Object.const_get(:CreateAdverts).new

    migration.up
    assert_includes connection.tables, "adverts"
    migration.down
    refute_includes connection.tables, "adverts"
  ensure
    Object.send(:remove_const, :CreateAdverts) if Object.const_defined?(:CreateAdverts)
  end

  def template_path
    File.expand_path("../../../lib/generators/hobo/migration/templates/migration.rb.erb", __dir__)
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
    assert_reversible(up, down, "change, remove and add together")
  end

  # --- todos los tipos, no una muestra --------------------------------------
  #
  # La bateria probaba media docena de tipos. Los diecisiete que declara
  # HoboFields pasan por el mismo camino --el generador le pregunta al adaptador
  # por su tipo nativo-- y el que no se prueba es el que se rompe: un `:markdown`
  # y un `:textile` son columnas de texto, un `:password` es una cadena, y un
  # `:serialized` es texto con un serializador detras.
  #
  # Lo que se comprueba es la vuelta entera: se genera, se ejecuta, y se deshace
  # dejando la base como estaba. Comparar el texto generado no dice si el `down`
  # se puede ejecutar siquiera -- por eso paso desapercibido durante anos.

  ALL_TYPES = %w[
    boolean date datetime time integer decimal float string email_address text
    raw_html html password raw_markdown markdown serialized textile
  ].freeze

  # `declare_field` y no el DSL de `fields`: dentro de ese bloque no se puede
  # llamar a nada dinamicamente, porque es blank-slate y **cualquier** metodo
  # que no conozca es el nombre de un campo. `send(:campo, :float)` no declara
  # `campo` de tipo float: declara un campo llamado `send` de tipo `campo`, y el
  # error sale tres capas mas abajo diciendo "nil is not a class/module".
  def declare_types(model, types)
    lineas = types.map { |type| "campo_#{type} :#{type}" }.join("\n")
    model.class_eval("fields do\n#{lineas}\nend", __FILE__, __LINE__)
    model
  end

  def test_every_declared_type_survives_a_round_trip
    declared = ALL_TYPES
    declare_types(define_model(:Advert), declared)

    up, down = generate

    declared.each do |type|
      assert_match(/campo_#{type}/, up, "el tipo #{type} no ha llegado a la migracion")
    end

    assert_reversible(up, down, "los #{declared.size} tipos")
  end

  # Y cada tipo por separado, para que el que falle diga su nombre. Con todos
  # juntos, un fallo dice "la migracion de diecisiete columnas" y hay que
  # bisecar a mano.
  ALL_TYPES.each do |type|
    define_method("test_the_#{type}_type_round_trips") do
      declare_types(define_model(:Advert), [type])

      up, down = generate

      assert_match(/create_table :adverts/, up)
      assert_match(/:campo_#{type}/, up)
      assert_reversible(up, down, "el tipo #{type}")
    end
  end

  # Un tipo nuevo en HoboFields sin su fila aqui es un tipo que nadie migra.
  def test_no_type_is_left_untested
    faltan = HoboFields.field_types.keys.map(&:to_s) - ALL_TYPES

    assert_empty faltan, "tipos sin probar en la migracion: #{faltan.join(", ")}"
  end

end


# One test class per reachable adapter.
HoboFields::TestDatabases.available.each do |adapter|
  klass = Class.new(Minitest::Test) do
    include MigrationGeneratorBattery
    define_singleton_method(:adapter) { adapter }
  end
  Object.const_set("MigrationGenerator#{adapter.camelize}Test", klass)
end

# And a visible skip for the ones that did not answer, so a missing adapter is
# never mistaken for a passing one.
unless HoboFields::TestDatabases.unavailable.empty?
  klass = Class.new(Minitest::Test) do
    HoboFields::TestDatabases.unavailable.each do |adapter|
      define_method("test_#{adapter}_was_not_reachable") do
        skip "#{adapter} is not reachable: the migration battery did not run against it"
      end
    end
  end
  Object.const_set("MigrationGeneratorAdapterCoverageTest", klass)
end
