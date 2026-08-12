# The sort link of one column, in one place.
#
# Two things want it and they are in different worlds: `sortable_headings`, a
# verb a view or a taglib writes, and `<table-plus>`, a tag. The verb lives on
# the view and the tag on `Rapid::Tag`, so neither can call the other -- and
# writing the link twice is how the two of them start disagreeing about which
# arrow means what.
#
# What it answers is a `Rapid::Parameter`: the heading of that column, as a link
# that puts `?sort=` in the url. The controller reads it in `find_or_paginate`.

require "rapid"

module HoboRapid

  module Sorting

    class << self

      # Which of a model's columns can be sorted by: the ones the table has.
      # An association cannot be handed to an ORDER BY, and a heading that does
      # not sort is worse than a heading of plain text.
      def columns_of(model, only = [])
        return [] unless model.respond_to?(:column_names)

        asked = Array(only).map(&:to_s)
        asked = HoboRapid::Derivation.index_columns(model).map(&:to_s) if asked.empty?
        asked.select { |field| model.column_names.include?(field) }
      end

      # The heading of one column, as the parameter that replaces it.
      def heading_for(model, field, sorted_by = nil)
        sorted_by = sorted_by.to_s
        label = HoboRapid::Derivation.label_for(model, field)

        # Already sorting by this one and upwards: the next click turns it over.
        ascending = sorted_by == field.to_s
        arrow = if sorted_by.delete_prefix("-") == field.to_s
                  ascending ? " ↑" : " ↓"
                else
                  ""
                end

        target = HoboRapid.query_parameters.merge("sort" => "#{"-" if ascending}#{field}")

        Rapid.parameter do
          tag("a", { :href => "?#{target.to_query}", :class => "sort-link" }) { text "#{label}#{arrow}" }
        end
      end

      # All of them, as a hash of params ready to hand to a tag call.
      def headings_for(model, only = [])
        sorted_by = HoboRapid.query_parameters["sort"]

        columns_of(model, only).to_h do |field|
          [:"#{field}_heading", heading_for(model, field, sorted_by)]
        end
      end

      # The model a collection is of, however it was handed over.
      def model_of(records)
        return records.klass if records.respond_to?(:klass)
        Array(records).first&.class
      end

    end

  end

end
