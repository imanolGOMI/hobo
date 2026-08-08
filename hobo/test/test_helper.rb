# One gem, one load path, one helper.
#
# There used to be five of these, one per gem, each unshifting the other four
# onto `$LOAD_PATH` -- the andamiaje that decision 12 accepted "until layer 7"
# so that each layer's diff would stay readable. This is layer 7.
#
# What was specific to one suite is next to that suite and required by name:
#
#   test/hobo_fields/databases.rb   the multi-adapter battery (Deuda 1)
#   test/dryml/rapid_fixtures.rb    the ported tags the param contract runs on
#   test/hobo_rapid/browser_helper.rb   the headless browser bench

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "active_record"
require "hobo"

# Quiet: the schema statements are chatty.
ActiveRecord::Base.logger = Logger.new(IO::NULL)
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

module HoboTest

  # Defining a model registers it for good -- Hobo keeps a list, and so does
  # ActiveSupport's DescendantsTracker -- so each test that defines one has to
  # clean up after itself or the next test sees it. The same lesson as layer 2.
  def self.clean_up(*names)
    names.each do |name|
      next unless Object.const_defined?(name)
      klass = Object.const_get(name)
      Object.send(:remove_const, name)
      ActiveSupport::DescendantsTracker.clear([klass]) if klass.is_a?(Class)
    end
  end

end
