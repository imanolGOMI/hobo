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

    def with_request(token, user, flash = {}, query = {})
      previous = [Thread.current[:hobo_rapid_token], Thread.current[:hobo_rapid_user],
                  Thread.current[:hobo_rapid_flash], Thread.current[:hobo_rapid_query]]
      Thread.current[:hobo_rapid_token] = token
      Thread.current[:hobo_rapid_user] = user
      Thread.current[:hobo_rapid_flash] = flash
      Thread.current[:hobo_rapid_query] = query
      yield
    ensure
      Thread.current[:hobo_rapid_token], Thread.current[:hobo_rapid_user],
        Thread.current[:hobo_rapid_flash], Thread.current[:hobo_rapid_query] = previous
    end

    def authenticity_token = Thread.current[:hobo_rapid_token]

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
