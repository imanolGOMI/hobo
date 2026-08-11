# What the tags are allowed to know about the request they are painting for.
#
# The tag runtime knows nothing about controllers, and it should not: a tag is a
# Ruby object that returns a string. But three things about *this* request have
# to reach it anyway -- who is asking, the forgery token, and whatever the last
# action left in the flash -- and none of them can be passed down as a parameter
# without every tag in between having to carry them.
#
# So the bridge (`rapid_tag`, in helper.rb) puts them here for the length of one
# render, and a tag asks. It lives in its own file because the tags need it and
# the bridge needs it, and the tags must not have to load the Rails half to be
# tested.

module HoboRapid

  class << self

    KEYS = %i[hobo_rapid_token hobo_rapid_user hobo_rapid_flash hobo_rapid_query
              hobo_rapid_subsite hobo_rapid_request].freeze

    def with_request(token, user, flash = {}, query = {}, subsite = nil, request = nil)
      previous = KEYS.map { |key| Thread.current[key] }
      values = [token, user, flash, query, subsite, request]
      KEYS.each_with_index { |key, i| Thread.current[key] = values[i] }
      yield
    ensure
      KEYS.each_with_index { |key, i| Thread.current[key] = previous[i] }
    end

    def authenticity_token = Thread.current[:hobo_rapid_token]

    # The whole request. **The catalogue does not use this and must not**: a tag
    # is an object that returns a string, and what it needs of the request is
    # the four things above.
    #
    # It is here for `hobo_dryml`: a template from 2013 writes `request.format`
    # inside a param -- amenti decides that way whether it is serving a pdf --
    # and the only alternative was the page blowing up. `HoboDryml::Vocabulary`
    # is what offers it as a word, so anybody writing today still cannot say it.
    def request = Thread.current[:hobo_rapid_request]

    # Which part of the application is painting. `nil` is the site itself;
    # "admin" is `app/controllers/admin/`. A subsite can wear another theme, and
    # this is how the runtime knows which table of class names to use.
    def subsite = Thread.current[:hobo_rapid_subsite]

    # Who is asking. Every permission question in the catalogue goes through
    # here, so when it answered nil the whole application was painted for a
    # guest and nothing said a word.
    def current_user = Thread.current[:hobo_rapid_user]

    def flash_messages = Thread.current[:hobo_rapid_flash] || {}

    # What is being filtered right now. A filter that cannot see the query
    # string cannot show what is selected, and cannot keep the other filters
    # when you change one -- which is how a search box and a menu on the same
    # page start cancelling each other out.
    def query_parameters = Thread.current[:hobo_rapid_query] || {}

  end

end
