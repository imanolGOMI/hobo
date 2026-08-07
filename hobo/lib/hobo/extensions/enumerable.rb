# `group_by` on a Hobo collection keeps the collection's metadata -- where it
# came from and what it holds -- so the views still know what each group *is*.
module Hobo
  module GroupByWithMetadata
    def group_by(&block)
      groups = super
      if respond_to?(:origin)
        groups.each_value do |group|
          group.origin = origin
          group.origin_attribute = origin_attribute
          group.member_class = member_class
        end
      end
      groups
    end
  end
end

Enumerable.prepend(Hobo::GroupByWithMetadata)
