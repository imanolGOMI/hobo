# The tags of the plugin.
#
# `Rapid.define_for(:view_content, Date)` is the Ruby of DRYML's
# `<def tag="view" for="Date">`, and it is the reason plugins existed: a gem
# that changes how a *type* is painted changes every page that paints one,
# without any page mentioning the gem.
#
# The catalogue already defines `view_content for Date`. This replaces it --
# the registry is one table and the last definition of a name wins -- so after
# this file runs, `rails hobo:tags` shows the catalogue's line as `shadowed`.
# That is on purpose, and being able to see it is the point of that task.

require "rapid"
require "hobo_timeago"

module HoboTimeago

  # One definition, registered for each type that means a moment in time.
  # `ActiveSupport::TimeWithZone` is not a subclass of `Time` -- it only
  # behaves like one -- so a `datetime` column read back from the database
  # needs its own registration, not an ancestor's.
  RELATIVE = lambda do
    moment = HoboTimeago.iso8601(this)
    tag("time", { :datetime => moment, :class => "timeago",
                  :title => this.to_s,
                  :data_controller => "timeago", :data_timeago_at_value => moment }) do
      text HoboTimeago.in_words(this)
    end
  end

  TYPES = [Date, Time, defined?(ActiveSupport::TimeWithZone) && ActiveSupport::TimeWithZone].compact

end

HoboTimeago::TYPES.each do |type|
  Rapid.define_for(:view_content, type, &HoboTimeago::RELATIVE)
end
