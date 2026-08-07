module Hobo
  module Model
  	module Permissions


      def self.included(klass)
        klass.class_eval do
          extend ClassMethods

          # The check used to wrap _create_record, _update_record and destroy
          # with alias_method_chain. The first two are private to ActiveRecord;
          # all three have a public callback that means the same thing, and the
          # callbacks also catch the paths that do not go through those methods
          # -- creating through an association, for one.
          #
          # `prepend` so the check runs before anything else on the same
          # callback, Rails' own dependent-destroy included: no point destroying
          # the children of a record you are not allowed to destroy.
          before_create  :hobo_check_create_permission,  :prepend => true
          before_update  :hobo_check_update_permission,  :prepend => true
          before_destroy :hobo_check_destroy_permission, :prepend => true

          attr_accessor :acting_user, :origin, :origin_attribute

          bool_attr_accessor :exempt_from_edit_checks
        end
      end

      module ClassMethods

        def user_find(user, *args)
          record = find(*args)
          yield(record) if block_given?
          record.user_view user
          record
        end


        def user_new(user, attributes={})
          new(attributes) do |r|
            r.set_creator user
            yield r if block_given?
            r.user_view(user)
            r.with_acting_user(user) { r.try(:after_user_new) }
          end
        end


        def user_create(user, attributes={}, &block)
          if attributes.is_a?(Array)
            attributes.map { |attrs| user_create(user, attrs) }
          else
            record = user_new(user, attributes, &block)
            record.user_save(user)
            record
          end
        end


        def user_create!(user, attributes={}, &block)
          if attributes.is_a?(Array)
            attributes.map { |attrs| user_create(user, attrs) }
          else
            record = user_new(user, attributes, &block)
            record.user_save!(user)
            record
          end
        end

        def viewable_by?(user, attribute=nil)
          new.viewable_by?(user, attribute)
        end

        #  ensure active_user gets passed down to :dependent => destroy
        #  associations  (Ticket #528)

        # There were three wrappers here, around has_many, has_one and
        # belongs_to. Each one redefined `<macro>_dependent_destroy_for_<name>`,
        # a method ActiveRecord generated for `:dependent => :destroy`, so that
        # the children went through `user_destroy` instead of `destroy`.
        #
        # Rails stopped generating those methods in 4.1: since then dependent
        # destruction goes through a before_destroy callback that calls
        # `association.handle_dependency`. So the three wrappers have been
        # redefining methods nobody calls for over a decade, and the children
        # have been destroyed without any permission check at all.
        #
        # What replaces them is smaller and does not touch the association
        # macros: the parent hands its acting_user down to the children it is
        # about to destroy, and each child then checks its own permission
        # through the same before_destroy as everybody else. See
        # hobo_propagate_acting_user_to_dependents below.

      end


      # --- Hook ActiveRecord CRUD actions --- #


      def permission_check_required?
        # Lifecycle steps are exempt from permission checks
        acting_user && !(self.class.has_lifecycle? && lifecycle.active_step)
      end

      def hobo_check_create_permission
        return unless permission_check_required?
        create_permitted? or raise PermissionDeniedError, "#{self.class.name} #{self.id}#create"
      end

      def hobo_check_update_permission
        return unless permission_check_required?
        update_permitted? or raise PermissionDeniedError, "#{self.class.name} #{self.id}#update"
      end

      def hobo_check_destroy_permission
        if permission_check_required?
          destroy_permitted? or raise PermissionDeniedError, "#{self.class.name} #{self.id}#.destroy"
        end
        hobo_propagate_acting_user_to_dependents
      end

      # Rails destroys `:dependent => :destroy` children through a callback of
      # its own, which knows nothing about who is acting. Handing them the
      # acting_user before it runs is all it takes for each child to check its
      # own destroy permission on the way out.
      def hobo_propagate_acting_user_to_dependents
        return unless acting_user
        self.class.reflect_on_all_associations.each do |reflection|
          next unless reflection.options[:dependent] == :destroy
          Array(send(reflection.name)).each do |record|
            record.acting_user = acting_user if record.is_a?(Hobo::Model)
          end
        end
      end

      # -------------------------------------- #


      # --- Permissions API --- #


      def with_acting_user(user)
        return yield if user == acting_user
        old = acting_user
        self.acting_user = user
        result = yield
        self.acting_user = old
        result
      end

      def user_save(user, validate = true)
        with_acting_user(user) { save(:validate => validate) }
      end

      def user_save!(user)
        with_acting_user(user) { save! }
      end

      def user_destroy(user)
        with_acting_user(user) { destroy }
      end

      def user_view(user, attribute=nil)
        raise PermissionDeniedError unless viewable_by?(user, attribute)
      end

      def user_update_attributes(user, attributes)
        with_acting_user(user) do
          self.attributes = attributes
          save
        end
      end

      def user_update_attributes!(user, attributes)
        with_acting_user(user) do
          self.attributes = attributes
          save!
        end
      end

      def creatable_by?(user)
        with_acting_user(user) { create_permitted? }
      end

      def updatable_by?(user)
        with_acting_user(user) { update_permitted? }
      end

      def destroyable_by?(user)
        with_acting_user(user) { destroy_permitted? }
      end

      def method_callable_by?(user, method)
        permission_method = "#{method}_permitted?"
        respond_to?(permission_method) && with_acting_user(user) { send(permission_method) }
      end

      def viewable_by?(user, attribute=nil)
        if attribute
          attribute = attribute.to_s.sub(/\?$/, '').to_sym
          return false if attribute && self.class.never_show?(attribute)
        end
        with_acting_user(user) { view_permitted?(attribute) }
      end


      def editable_by?(user, attribute=nil)
        return false if attribute_protected?(attribute)

        return true if exempt_from_edit_checks?

        # Can't view implies can't edit
        return false unless viewable_by?(user, attribute)

        if attribute
          attribute = attribute.to_s.sub(/\?$/, '').to_sym

          # Try the attribute-specific edit-permission method if there is one
          if has_hobo_method?(meth = "#{attribute}_edit_permitted?")
            return with_acting_user(user) { send(meth) }
          end

          # No setter = no edit permission
          return false if !respond_to?("#{attribute}=")

          refl = self.class.reflections[attribute.to_s]
          if refl && refl.macro != :belongs_to # a belongs_to is handled the same as a regular attribute
            return association_editable_by?(user, refl)
          end
        end

        with_acting_user(user) { edit_permitted?(attribute) }
      end


      def attribute_protected?(attribute)
        return false if attribute.nil?
        attribute = attribute.to_s

        return true if self.class.send(:attributes_protected_by_default).include? attribute

        if !self.class.accessible_attributes.empty?
          return true if !self.class.accessible_attributes.include?(attribute)
        elsif self.class.protected_attributes
          return true if self.class.protected_attributes.include?(attribute)
        end

        # Readonly attributes can be set on creation but not thereafter
        return self.class.readonly_attributes.include?(attribute) if !new_record? && self.class.readonly_attributes

        false
      end


      def association_editable_by?(user, reflection)
        # has_one and polymorphic associations are not editable (for now)
        return false if reflection.macro == :has_one || reflection.options[:polymorphic]

        return false unless reflection.options[:accessible]

        record = if (through = reflection.through_reflection)
                   # For edit permission on a has_many :through,
                   # the user needs create+destroy permission on the join model
                   send(through.name).new_candidate
                 else
                   # For edit permission on a regular has_many,
                   # the user needs create/destroy permission on the member model
                   send(reflection.name).new_candidate
                 end
        record.creatable_by?(user) && record.destroyable_by?(user)
      end

      # ----------------------- #


      # --- Permission Declaration Helpers --- #

      def only_changed?(*attributes)
        attributes = attributes.map do |attr|
          with_attribute_or_belongs_to_keys(attr) { |a, ftype| ftype ? [a, ftype] : a }
        end.flatten

        changed.all? { |attr| attributes.include?(attr) }
      end

      def none_changed?(*attributes)
        attributes = attributes.map do |attr|
          with_attribute_or_belongs_to_keys(attr) { |a, ftype| ftype ? [a, ftype] : a }
        end.flatten

        attributes.all? { |attr| !changed.include?(attr) }
      end

      def any_changed?(*attributes)
        attributes.any? do |attr|
          with_attribute_or_belongs_to_keys(attr) do |a, ftype|
            if ftype
              changed.include?(a) || changed.include?(ftype)
            else
              changed.include?(a)
            end
          end
        end
      end

      def all_changed?(*attributes)
        attributes = prepare_attributes_for_change_helpers(attributes)
        attributes.all? do |attr|
          with_attribute_or_belongs_to_keys(attr) do |a, ftype|
            if ftype
              changed.include?(a) || changed.include?(ftype)
            else
              changed.include?(a)
            end
          end
        end
      end

      def with_attribute_or_belongs_to_keys(attribute)
        if (refl = self.class.reflections[attribute.to_s]) && refl.macro == :belongs_to
          if refl.options[:polymorphic]
            yield refl.foreign_key, refl.options[:foreign_type]
          else
            yield refl.foreign_key, nil
          end
        else
          yield attribute.to_s, nil
        end
      end



      # -------------------------------------- #


      # --- Default *_permitted? methods --- #

      # Conservative default permissions #
      def create_permitted?;  false end
      def update_permitted?;  false end
      def destroy_permitted?; false end

      # Allow viewing by default
      def view_permitted?(attribute) true end

      # By default, attempt to derive edit permission from create/update permission
      def edit_permitted?(attribute)
        unknownify_attribute(attribute) if attribute
        new_record? ? create_permitted? : update_permitted?
      rescue Hobo::UndefinedAccessError
        # The permission is dependent on the unknown value
        # so this attribute is not editable
        false
      ensure
        deunknownify_attribute(attribute) if attribute
      end


      # Add some singleton methods to +record+ to give the effect that +attribute+ is unknown. That is,
      # attempts to access the attribute will result in a Hobo::UndefinedAccessError
      def unknownify_attribute(attr)
        singleton_class.class_eval do
          define_method attr do
            raise Hobo::UndefinedAccessError
          end
        end

        if (refl = self.class.reflections[attr.to_s]) && refl.macro == :belongs_to
          # A belongs_to -- also unknownify the underlying fields
          unknownify_attribute refl.foreign_key
          unknownify_attribute refl.options[:foreign_type] if refl.options[:polymorphic]
        else
          # A regular field -- hack the dirty tracking methods

          singleton_class.class_eval do

            define_method "#{attr}_change" do
              raise Hobo::UndefinedAccessError
            end

            define_method "#{attr}_was" do
              read_attribute attr
            end

            define_method "#{attr}_changed?" do
              true
            end

            def changed?
              true
            end

            define_method :changed do
              changed_attributes.keys | [attr.to_s]
            end

            def changes
              raise Hobo::UndefinedAccessError
            end

          end
        end
      end

      # Best. Name. Ever
      def deunknownify_attribute(attr, remove_globals = true)
        attr = attr.to_sym

        singleton_class.send :remove_method, attr

        if (refl = self.class.reflections[attr.to_s]) && refl.macro == :belongs_to
          # A belongs_to -- restore the underlying fields
          deunknownify_attribute refl.foreign_key
          deunknownify_attribute(refl.options[:foreign_type], false) if refl.options[:polymorphic]
        else
          # A regular field -- restore the dirty tracking methods
          # if remove_globals is false, skip the top-level methods, as we have already removed them
          to_remove = remove_globals ? [:changed?, :changed, :changes] : []
          (["#{attr}_change", "#{attr}_was", "#{attr}_changed?"] + to_remove).each do |m|
            singleton_class.send :remove_method, m.to_sym
          end
        end
      end

    end
  end
end

