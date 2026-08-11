# `hobo_will_paginate` still speaks Hobo 1's `try`.
#
# That `try` took no arguments and answered a proxy, so `array.try.member_class`
# meant "member_class if there is one". Rails' `try` takes the method name, and
# with no arguments and no block it ends up asking `respond_to?(nil)` -- which
# raises `TypeError: nil is not a symbol nor a string`.
#
# It fires on `replace`, which is where a paginated relation turns itself into
# an array. So **any** `to_a` on a paginated list raised, and the page that
# raised was whichever one happened to count its own records:
#
#   <% append_heading " · #{this.to_a.count { |loan| loan.pending? }}" %>
#
# The gem is not ours to change -- it is read from the organisation's repo -- so
# the same three lines are written here in the `try` that exists now.
#
# Applied from an initializer and not at require time. Requiring the gem's file
# from here and patching it straight away looks like it works and does not:
# Bundler requires the gem afterwards on its own account, the class is reopened,
# and the old method comes back. An initializer runs when every gem is already
# in, which is the only moment at which the answer does not depend on the order
# of somebody else's Gemfile.

module Hobo
  module Extensions
    module WillPaginate

      def self.apply!
        return false unless defined?(::WillPaginate::Collection)

        # `replace` and not `replace_with_hobo_metadata`, even though that is the
        # one with the bug in it. `alias_method_chain` **copies** the body:
        # after it has run, `replace` is a copy of the original, and rewriting
        # the method it was copied from changes nothing at all -- the page went
        # on raising from a method that no longer existed as written.
        ::WillPaginate::Collection.class_eval do
          def replace(array)
            result = replace_without_hobo_metadata(array)
            self.member_class = array.try(:member_class)
            self.origin = array.try(:origin)
            self.origin_attribute = array.try(:origin_attribute)
            result
          end
        end
        true
      end

    end
  end
end
