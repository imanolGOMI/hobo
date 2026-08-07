module ActiveRecord

  class Relation
    attr_accessor :origin, :origin_attribute

    def member_class
      @klass
    end
  end

  # Where a relation came from -- which record and which association -- so the
  # views can work out what a collection *is*, not just what it holds.
  module MergeWithOrigin
    def merge(other, *args)
      merged = super
      # LH#1002: cannot call respond_to? because default_scope ends up calling
      # merge and we end up with infinite recursion
      merged.origin = other.origin rescue nil unless merged.instance_variable_defined?("@origin")
      merged.origin_attribute = other.origin_attribute rescue nil unless merged.instance_variable_defined?("@origin_attribute")
      merged
    end
  end
  Relation.prepend(MergeWithOrigin)

  module Associations
    class CollectionProxy

      # FIXME Ralis4:  really hoping that we can replace this with
      # something based on https://github.com/rails/rails/issues/5717
      # def scoped_with_origin
      #   relation = scoped_without_origin.clone
      #   relation.origin = proxy_association.owner
      #   relation.origin_attribute = proxy_association.reflection.name
      #   relation
      # end
      # alias_method_chain :scoped, :origin

    end

    module ProxyOrigin
      def method_missing(method, *args, &block)
        res = super
        res.origin = proxy_association.owner if res.respond_to?(:origin)
        res.origin_attribute = proxy_association.reflection.name if res.respond_to?(:origin_attribute)
        res
      end
    end
    CollectionProxy.prepend(ProxyOrigin)
  end
end
