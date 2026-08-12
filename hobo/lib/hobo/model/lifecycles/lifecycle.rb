module Hobo
  module Model
    module Lifecycles

      class Lifecycle

        def self.init(model, options)
          @model   = model
          @options = options
          reset
        end

        def self.reset
          @states        = {}
          @creators      = {}
          @transitions   = []
          @invariants    = []
        end

        class << self
          attr_accessor :model, :options, :states, :default_state,
                        :creators, :transitions, :invariants
        end

        def self.def_state(name, on_enter)
          name = name.to_sym
          class_eval "def #{name}_state?; state_name == :#{name} end"
          states[name] = Lifecycles::State.new(name, on_enter)
        end


        def self.def_creator(name, on_create, options)
          class_eval %{
                       def self.#{name}(user, attributes=nil)
                         create(:#{name}, user, attributes)
                       end
                       def self.can_#{name}?(user, attributes=nil)
                         can_create?(:#{name}, user)
                       end
                      }
          Creator.new(self, name.to_s, on_create, options)
        end

        def self.def_transition(name, start_states, end_state, on_transition, options)
          class_eval %{
                       def #{name}!(user, attributes=nil)
                         transition(:#{name}, user, attributes)
                       end
                       def can_#{name}?(user, attributes=nil)
                         can_transition?(:#{name}, user)
                       end
                      }
          Transition.new(self, name.to_s, start_states, end_state, on_transition, options)
        end

        def self.state_names
          states.keys
        end

        def self.publishable_creators
          creators.values.select(&:publishable?)
        end

        def self.publishable_transitions
          transitions.select(&:publishable?)
        end

        def self.step_names
          (creators.keys | transitions.map(&:name)).uniq
        end


        def self.creator(name)
          creators[name.to_sym] or raise ArgumentError, "No such creator in lifecycle: #{name}"
        end


        def self.can_create?(name, user)
          creators[name.to_sym].allowed?(user)
        end


        def self.create(name, user, attributes=nil)
          creator = creators[name.to_sym] or raise LifecycleError, "No creator #{name} available"
          creator.run!(user, attributes)
        end


        def self.state_field
          options[:state_field]
        end

        # What signs the keys. An application's own secret, and nothing else:
        # a key signed with a blank secret is not a key.
        #
        # Outside Rails -- the piece tests of this file -- there is no
        # application to ask, so the environment can say. Refusing loudly beats
        # signing with nil, which is what the old line effectively did wherever
        # `secret_token` happened to be unset.
        def self.key_secret
          secret = if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
                     ::Rails.application.secret_key_base
                   end
          secret ||= ENV["HOBO_LIFECYCLE_SECRET"]
          secret.presence or
            raise LifecycleError, "a lifecycle key needs a secret to sign it: set the application's " \
                                  "secret_key_base, or HOBO_LIFECYCLE_SECRET outside Rails"
        end

        def self.key_timeout
          options[:key_timeout]
        end


        # --- Instance Features --- #

        attr_reader :record

        attr_accessor :provided_key, :active_step


        def initialize(record)
          @record = record
        end


        def can_transition?(name, user)
          available_transitions_for(user, name).any?
        end


        def transition(name, user, attributes)
          transition = find_transition(name, user) or raise LifecycleError, "No transition #{name} available"
          transition.run!(record, user, attributes)
        end


        def find_transition(name, user)
          available_transitions_for(user, name).first
        end


        def state_name
          name = record.read_attribute(self.class.state_field)
          name.to_sym if name
        end


        def state
          self.class.states[state_name]
        end


        def available_transitions
          state ? state.transitions_out : []
        end

        # see also publishable_transitions_for
        def available_transitions_for(user, name=nil)
          name = name.to_sym if name
          matches = available_transitions
          matches = matches.select { |t| t.name == name } if name
          record.with_acting_user(user) do
            matches.select { |t| t.can_run?(record) }
          end
        end

        def publishable_transitions_for(user)
          record.with_acting_user(user) do
            available_transitions_for(user).select do |t|
              t.publishable_by(user, t.available_to, record)
            end
          end
        end


        def become(state_name, validate=true)
          state_name = state_name.to_sym
          record.send :write_attribute, self.class.state_field, state_name.to_s

          if state_name == :destroy
            record.destroy
            true
          else
            s = self.class.states[state_name]
            raise ArgumentError, "No such state '#{state_name}' for #{record.class.name}" unless s

            if record.save(:validate => validate)
              s.activate! record
              self.active_step = nil # That's the end of this step
              true
            else
              false
            end
          end
        end


        def key_timestamp_field
          record.class::Lifecycle.options[:key_timestamp_field]
        end

        def key_timeout
          record.class::Lifecycle.options[:key_timeout]
        end

        def generate_key
          # There used to be a `raise unless Time.zone` here, and it guarded
          # nothing: the next line is `Time.now.utc`, which does not use the
          # zone. In an application `Time.zone` is always set, so the check only
          # ever fired outside Rails -- which is to say, in the one place that
          # wanted to test this without booting an application.
          key_timestamp = Time.now.utc
          record.send :write_attribute, key_timestamp_field, key_timestamp
          key
        end


        # The one-use key that travels in an activation or an invitation mail.
        #
        # It used to be signed with `Rails.application.config.secret_token`, and
        # **Rails removed that in 5.2**: on Rails 8 the line raises NoMethodError,
        # so every key-bearing step of every lifecycle was broken -- activation
        # mails, invitations, anything with `:new_key => true`. Nothing in the
        # suite failed, because nothing in the suite had ever asked for a key:
        # the piece was tested for its states and its transitions, and keys are
        # the part that only an application uses.
        def key
          require 'digest/sha1'
          timestamp = record.read_attribute(key_timestamp_field)
          if timestamp
            timestamp = timestamp.getutc
            Digest::SHA1.hexdigest("#{record.id}-#{state_name}-#{timestamp}-#{Lifecycle.key_secret}")
          end
        end

        def key_expired?
          timestamp = record.read_attribute(key_timestamp_field)
          timestamp.nil? || (timestamp.getutc + key_timeout < Time.now.utc)
        end

        def valid_key?
          provided_key && provided_key == key && !key_expired?
        end

        def clear_key
          record.send :write_attribute, key_timestamp_field, nil
        end

        def invariants_satisfied?
          self.class.invariants.all? { |i| record.instance_eval(&i) }
        end


        def active_step_is?(name)
          active_step && active_step.name == name.to_sym
        end

        def method_missing(name, *args)
          if name.to_s =~ /^(.*)_in_progress\?$/
            active_step_is?($1)
          else
            super
          end
        end

      end

    end
  end
end
