$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)

require "minitest/autorun"
require "active_record"
require "hobo_fields"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

# Quiet: the schema statements are chatty.
ActiveRecord::Base.logger = Logger.new(IO::NULL)
ActiveRecord::Migration.verbose = false

module HoboFields
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
