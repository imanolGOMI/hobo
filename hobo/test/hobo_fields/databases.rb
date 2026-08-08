# La bateria multi-adaptador de la capa 2 (Deuda 1 de PLAN.md), que vivia en
# el test_helper de hobo_fields cuando hobo_fields era una gema aparte.

module HoboFields

  # The migration generator talks to the adapter for native types, schema
  # dumping and column introspection, so it has to be tested against every
  # adapter it claims to support -- not just sqlite. See PLAN.md, "Deuda 1".
  #
  # Whichever databases are reachable get tested; the rest are skipped with a
  # message. Point them somewhere with:
  #
  #   HOBO_TEST_POSTGRES_URL=postgres://user:pass@localhost/hobo_fields_test
  #   HOBO_TEST_MYSQL_URL=mysql2://user:pass@localhost/hobo_fields_test
  #
  module TestDatabases

    DEFAULTS = {
      "sqlite3" => { "adapter" => "sqlite3", "database" => ":memory:" },
      "postgresql" => ENV["HOBO_TEST_POSTGRES_URL"],
      "mysql2" => ENV["HOBO_TEST_MYSQL_URL"],
    }.freeze

    class << self

      # Names of the adapters that answered, in a stable order.
      def available
        @available ||= DEFAULTS.filter_map { |name, config| name if config && reachable?(config) }
      end

      def unavailable
        DEFAULTS.keys - available
      end

      def config_for(name)
        DEFAULTS[name]
      end

      def connect(name)
        ActiveRecord::Base.establish_connection(config_for(name))
      end

      private

      def reachable?(config)
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue Exception
        false
      ensure
        ActiveRecord::Base.remove_connection rescue nil
      end

    end

  end

  module TestHelper

    def connection
      ActiveRecord::Base.connection
    end

    # Defines a model under a real constant, because the migration generator
    # walks ActiveRecord::Base.descendants and skips anonymous classes.
    def define_model(name, &block)
      forget_model(name)
      klass = Class.new(ActiveRecord::Base)
      Object.const_set(name, klass)
      (@defined_model_names ||= []) << name
      klass.class_eval(&block) if block
      klass
    end

    # Removing the constant is not enough: the descendants tracker still holds
    # the class object, so a model defined in one test would be seen by every
    # test that follows -- including in other files.
    def forget_model(name)
      return unless Object.const_defined?(name)
      klass = Object.const_get(name)
      Object.send(:remove_const, name)
      ActiveSupport::DescendantsTracker.clear([klass]) if klass.is_a?(Class)
    end

    def drop_all_tables
      connection.tables.each { |t| connection.drop_table(t, :if_exists => true) }
    end

    def teardown
      Array(@defined_model_names).each { |name| forget_model(name) }
      super
    end

  end

end

class Minitest::Test
  include HoboFields::TestHelper
end

# Probe first -- checking an adapter tears the connection down again -- and only
# then connect. Everything that is not adapter-specific runs on sqlite.
HoboFields::TestDatabases.available
HoboFields::TestDatabases.connect("sqlite3")
