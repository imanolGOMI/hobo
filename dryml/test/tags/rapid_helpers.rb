# Bits the ported tags lean on that are **not** the runtime: they belong to the
# RAPID catalogue, and layer 5 is where they will live. They sit here so the
# runtime stays honest about what is its own.

module RapidHelpers

  AJAX_ATTRS = [:update, :updates, :ajax, :success, :failure, :complete, :before].freeze

  # Stands in for the controller instance variables the original tags read.
  def controller_ivar(_name) = nil

end

Rapid::Tag.include(RapidHelpers)
