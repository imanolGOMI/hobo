# A Hobo plugin, and the whole of what a plugin is (piece 17 of PLAN.md).
#
# Three things, none of them a Hobo API:
#
#   1. a Rails engine, so the assets and the import map of the gem reach the
#      application (lib/hobo_timeago/engine.rb);
#   2. a file that defines tags, required from here (lib/hobo_timeago/tags.rb);
#   3. assets under app/assets and app/javascript, where Rails looks.
#
# Installing it is `bundle add hobo_timeago`. There is nothing else: no
# generator, no `<include gem="...">` in a taglib, no `//= require` in the
# JavaScript, no `*= require` in the stylesheet. Hobo 2 needed those four
# because a DRYML tag lived in a file that had to be named before it existed;
# a Ruby tag is registered by being defined, and the gem's own files run when
# Bundler requires the gem.
#
# What it does: dates and times paint as "3 days ago", and keep themselves up to
# date in the browser.

require "date"

module HoboTimeago

  VERSION = File.read(File.expand_path("../VERSION", __dir__)).strip

  # Largest first: the first one that fits is the one used.
  UNITS = [["year", 31_557_600], ["month", 2_629_800], ["week", 604_800],
           ["day", 86_400], ["hour", 3600], ["minute", 60]].freeze

  class << self

    # "3 days ago", "in 2 hours", "just now".
    #
    # Written out rather than taken from ActionView's `time_ago_in_words`
    # because a plugin that can only be tested inside a Rails application is a
    # plugin nobody tests.
    def in_words(value, now = Time.now)
      seconds = now.to_f - moment(value).to_f
      past = seconds >= 0
      seconds = seconds.abs

      unit, size = UNITS.find { |_, size| seconds >= size }
      return "just now" unless unit

      count = (seconds / size).floor
      phrase = "#{count} #{unit}#{'s' unless count == 1}"
      past ? "#{phrase} ago" : "in #{phrase}"
    end

    # A Date has no time of day; midnight local is what everybody means by it.
    def moment(value)
      return value.to_time if value.respond_to?(:to_time)
      value
    end

    def iso8601(value) = moment(value).iso8601

  end

end

require "hobo_timeago/tags"
require "hobo_timeago/engine" if defined?(Rails::Engine)
