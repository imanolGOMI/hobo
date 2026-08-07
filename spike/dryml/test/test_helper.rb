require "date"
require "minitest/autorun"

require_relative "../runtime"
require_relative "param_contract"

# The ported <table-plus> of spike C. It is required, not copied: the contract
# has to run against the real port, or it proves nothing.
require_relative "../c_table_plus"

module RapidTest

  # A collection of records, standing in for an ActiveRecord relation.
  Story = Struct.new(:title, :status) do
    def self.name_attribute = :title
    def self.human_attribute_name(name) = name.to_s.capitalize
  end

  class Collection < Array
    def member_class = Story
    def total_pages = 3
  end

  def self.stories
    Collection.new([Story.new("First", "draft"), Story.new("Second", "done")])
  end

end
