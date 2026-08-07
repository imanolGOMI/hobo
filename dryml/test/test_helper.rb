require "date"
require "minitest/autorun"

require "rapid"
require "rapid/param_contract"

# The ported <table-plus> of spike C. It is required, not copied: the contract
# has to run against the real port, or it proves nothing.
require_relative "tags/table_plus"

# And the ported <form> of spike D, base tag and generated per-model tag.
require_relative "tags/form"

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
