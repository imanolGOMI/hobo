require 'hobo/model/scopes/apply_scopes'

module Hobo
  module Model
    module Scopes

      # There used to be a `:scope => :my_scope` option on associations here.
      # Its implementation (extensions/active_record/associations/scope.rb) was
      # wrapped in `if false` when Rails 3.1 came out, so for a decade the
      # option was accepted and quietly did nothing. Rails has taken the scope
      # as a block since Rails 4 -- `has_many :xs, -> { contributor }` -- so the
      # option is gone, and with it the registration, which in Rails 8 could not
      # work anyway: valid_options is private and takes an argument.

      def self.included_in_class(klass)
        klass.class_eval do
          extend ClassMethods
        end
      end

      module ClassMethods

        include ApplyScopes

      end

    end
  end
end
