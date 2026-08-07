$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)

require "minitest/autorun"
require "active_record"
require "hobo_fields"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

# Quiet: the migration generator and the schema statements are chatty.
ActiveRecord::Base.logger = Logger.new(IO::NULL)
ActiveRecord::Migration.verbose = false

module HoboFields
  module TestHelper

    # Defines an anonymous ActiveRecord model backed by +table+, so each test
    # can declare its own fields without leaking constants between tests.
    def model_class(table, &block)
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = table.to_s
      end
      name = "Test#{table.to_s.classify}#{object_id.abs}"
      Object.const_set(name, klass) unless Object.const_defined?(name)
      (@defined_models ||= []) << name
      klass.class_eval(&block) if block
      klass
    end

    def teardown
      Array(@defined_models).each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
      super
    end

  end
end

class Minitest::Test
  include HoboFields::TestHelper
end
