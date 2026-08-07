module Hobo
  module Model
    module AccessibleAssociations

      extend self

      def prepare_has_many_assignment(association, association_name, array_or_hash)
        owner = association.proxy_association.owner

        array = params_hash_to_array(array_or_hash)
        array.map! do |record_hash_or_string|
          finder = association.member_class
          conditions = association.proxy_association.reflection.options[:conditions]
          finder = finder.where(conditions) unless conditions == [[]] || conditions == [[],[]]
          find_or_create_and_update(owner, association_name, finder, record_hash_or_string) do |id|
            # The block is required to either locate find an existing record in the collection, or build a new one
            if id
              # TODO: We don't really want to find these one by one
              association.find(id)
            else
              association.build
            end
          end
        end
        array.compact
      end


      def find_or_create_and_update(owner, association_name, finder, record_hash_or_string)
        if record_hash_or_string.is_a?(String)
          return nil if record_hash_or_string.blank?

          # An ID or a name - the passed block will find the record
          record = find_by_name_or_id(finder, record_hash_or_string)

        elsif record_hash_or_string.is_a?(Hash)
          # A hash of attributes
          hash = record_hash_or_string

          # Remove completely blank hashes
          return nil if hash.values.all?(&:blank?)

          id = hash.delete(:id)

          record = yield id
          record.attributes = hash
          if owner.new_record? && record.new_record?
            # work around
            # https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/3510-has_many-build-does-not-set-reverse-reflection
            # https://hobo.lighthouseapp.com/projects/8324/tickets/447-validation-problems-with-has_many-accessible-true
            reverse = owner.class.reverse_reflection(association_name)
            if reverse && reverse.macro==:belongs_to
              method = "#{reverse.name}=".to_sym
              record.send(method, owner) if record.respond_to? method
            end
          else
            owner.include_in_save(association_name, record) unless owner.class.reflections[association_name.to_s].options[:through]
          end
        else
          # It's already a record
          record = record_hash_or_string
        end
        record
      end


      def params_hash_to_array(array_or_hash)
        if array_or_hash.is_a?(Hash)
          array = array_or_hash.get(*array_or_hash.keys.sort_by(&:to_i))
        elsif array_or_hash.is_a?(String)
          # Due to the way that rails works, there's no good way to tell
          # the difference between an empty array and a params hash that
          # just isn't making any updates to the array.  So we're
          # hacking this in: if you pass an empty string where an array
          # is expected, we assume you wanted an empty array.
          array_or_hash.split(',')
        else
          array_or_hash
        end
      end


      def find_by_name_or_id(finder, id_or_name)
        if id_or_name =~ /^@(.*)/
          id = $1
          finder.find(id)
        else
          finder.named(id_or_name)
        end
      end

      def finder_for_belongs_to(record, name)
        refl = record.class.reflections[name.to_s]
        #conditions = ActiveRecord::Associations::BelongsToAssociation.new(record, refl).reflection.send(:conditions)
        conditions = [[]]
        conditions == [[]] || conditions == [[],[]] ? refl.klass : refl.klass.scoped(:conditions => conditions)
      end

    end


    # The `:accessible => true` option on an association, and the writer it
    # generates. Everything here used to be alias_method_chain: five of them,
    # two on the association macros themselves and three on the generated
    # writers. They are `prepend` + `super` now.
    #
    # The macros also carried a hack that guessed whether the second argument
    # was a scope or an options hash, and when it guessed "options" it passed
    # the hash *positionally* -- so Rails took it as the scope and asked it for
    # its arity. Since Rails 5 the signature is `(name, scope = nil, **options)`
    # and there is nothing left to guess. It is the same bug layer 2 found in
    # hobo_fields' belongs_to.
    module AccessibleMacros

      def has_many(name, scope = nil, **options, &block)
        super
        return unless options[:accessible]

        hobo_accessible_writers.module_eval do
          define_method("#{name}=") do |array_or_hash|
            items = AccessibleAssociations.prepare_has_many_assignment(send(name), name.to_sym, array_or_hash)
            super(items)
            # ensure the loaded array contains any changed records
            association(name.to_sym).target[0..-1] = items
          end
        end
      end

      def belongs_to(name, scope = nil, **options, &block)
        super
        options[:accessible] ? define_accessible_writer(name) : define_finder_writer(name)
      end

      # A module of our own, prepended once, where the generated writers live.
      # `super` from inside it reaches the writer ActiveRecord generated, which
      # is what alias_method_chain used to arrange by renaming.
      def hobo_accessible_writers
        @hobo_accessible_writers ||= Module.new.tap { |mod| prepend(mod) }
      end

      private

      def define_accessible_writer(name)
        hobo_accessible_writers.module_eval do
          define_method("#{name}=") do |record_hash_or_string|
            finder = AccessibleAssociations.finder_for_belongs_to(self, name.to_sym)
            record = AccessibleAssociations.find_or_create_and_update(self, name.to_sym, finder, record_hash_or_string) do |id|
              if id
                current = send(name)
                unless current && id.to_s == current.id.to_s
                  raise ArgumentError, "attempted to update the wrong record in belongs_to association #{self}##{name}"
                end
                current
              else
                finder.new
              end
            end
            super(record)
          end
        end
      end

      # Not accessible, but finding by name or id is still supported.
      def define_finder_writer(name)
        hobo_accessible_writers.module_eval do
          define_method("#{name}=") do |record_or_string|
            record = if record_or_string.is_a?(String)
                       finder = AccessibleAssociations.finder_for_belongs_to(self, name.to_sym)
                       AccessibleAssociations.find_by_name_or_id(finder, record_or_string)
                     else
                       record_or_string
                     end
            super(record)
          end
        end
      end

    end

    def self.included(base)
      base.singleton_class.prepend(AccessibleMacros)
    end

    # Tell AR that `:accessible` is a legitimate association option.
    #
    # It used to be `valid_options << :accessible`, a class-level array. In
    # Rails 8 valid_options is a private method that takes the options hash.
    ::ActiveRecord::Associations::Builder::Association.singleton_class.prepend(Module.new do
      def valid_options(options)
        super + [:accessible]
      end
    end)

  end
end
