# Permission checks on the association side.
#
# The model checks its own create, update and destroy in before_ callbacks (see
# hobo/model/permissions.rb). What is left for the association to do is smaller:
# make sure the record knows *who is acting*, so those callbacks have someone to
# check against. Rails builds and destroys associated records with no notion of
# an acting user.
#
# All of this used to be alias_method_chain over ActiveRecord internals, and most
# of it had quietly rotted:
#
#   nullify_keys      reimplemented a method ActiveRecord no longer has, on top
#                     of `quoted_id` (gone in Rails 5.1) and the two-argument
#                     `update_all` (gone in Rails 4)
#   delete_records    replaced ActiveRecord's version wholesale, using `scoped`,
#                     which went away in Rails 4
#   _create_record    on the through association: the chain named the original
#                     `_create_record_without_user_create` and the body called
#                     `create_record_without_user_create`, so it raised
#                     NameError the first time it ran
#
# What replaces them only adds the acting user and calls `super`.

module Hobo
  module AssociationPermissions

    # The user acting on the owner, if there is one.
    def hobo_acting_user
      owner.acting_user if owner.is_a?(Hobo::Model)
    end

    def insert_record(record, *args)
      user = hobo_acting_user
      if user && record.is_a?(Hobo::Model)
        record.with_acting_user(user) { super }
      else
        super
      end
    end

    # `:destroy` runs each record's own callbacks, so handing it the acting user
    # is enough for it to check its own permission. The other methods
    # (:delete_all, :nullify) go straight to SQL and never load a record, so
    # there is nothing to check them against.
    def delete_records(records, method)
      user = hobo_acting_user
      if user && method == :destroy
        records.each { |record| record.acting_user = user if record.is_a?(Hobo::Model) }
      end
      super
    end

    def viewable_by?(user, field = nil)
      # A view check on an example member is meaningless when the association
      # carries a scope: the example is not a member of it.
      return true if reflection.scope
      new_candidate.viewable_by?(user, field)
    end

  end

  # On a has_many :through it is the *join* record that gets destroyed, so that
  # is the permission that decides.
  module ThroughAssociationPermissions

    def delete_records(records, method)
      user = hobo_acting_user
      if user
        joins = owner.send(send(:through_reflection).name)
        records.each do |record|
          joiner = joins.where(send(:construct_join_attributes, record)).first
          next unless joiner.is_a?(Hobo::Model)
          next if joiner.destroyable_by?(user)
          raise Hobo::PermissionDeniedError,
                "#{owner.class}##{reflection.name}.destroy (#{joiner.class.name})"
        end
      end
      super
    end

  end
end

# HasManyThroughAssociation inherits from HasManyAssociation, so the first
# prepend covers both; the second adds what only the through case needs.
ActiveRecord::Associations::HasManyAssociation.prepend(Hobo::AssociationPermissions)
ActiveRecord::Associations::HasManyThroughAssociation.prepend(Hobo::ThroughAssociationPermissions)
