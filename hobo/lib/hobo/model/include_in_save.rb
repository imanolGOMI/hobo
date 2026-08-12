module Hobo
  module Model
    module IncludeInSave
      extend ActiveSupport::Concern

      included do
        attr_accessor :included_in_save

        validate         :validate_included_in_save
        before_save      :save_included
        after_save       :clear_included_in_save
      end

      def include_in_save(association, *records)
        self.included_in_save ||= Hash.new {|h, k| h[k] = []}
        included_in_save[association.to_sym].concat records
      end

      def validate_included_in_save
        if included_in_save
          included_in_save&.each_pair do |association, records|
            next if self.class.reflections[association.to_s].options[:validate]==false
            added = false
            records.each do |record|
              # we want to call valid? on each one, but only add the error to self once

              record.with_acting_user(acting_user) do
                unless record.valid?
                  unless added
                    errors.add association, "..."
                    added = true
                  end
                end
              end
            end
          end
        end
      end


      def save_included
        if included_in_save
          included_in_save.each_pair do |association, records|
            records.each do |record|
              # save(:validate => false) means without transactions too
              record.with_acting_user(acting_user) { record.save(:validate => false) }
            end
          end
        end
      end

      def clear_included_in_save
        included_in_save&.clear
      end

    end
  end
end
