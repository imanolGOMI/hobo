# The records and the ported tags the param contract runs against.
#
# The tags are **required, not copied**: the contract has to run against the
# real port, or it proves nothing.

require "date"
require "rapid/param_contract"

# The ports of layer 3, which the contract runs against -- required, not
# copied, or it would prove nothing.
#
# Three of them are named `spike_*`: `<input>`, `<view>` and `<search-filter>`
# stood in for tags the catalogue did not have yet, and it has all three now.
# The registry is global -- a tag is looked up by name and an application has
# one catalogue -- so while each gem had its own test process nobody noticed,
# and the merge of layer 7 put them in one, where whichever loaded last won.
# What failed was a test in another suite.
require_relative "tags/table_plus"
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
