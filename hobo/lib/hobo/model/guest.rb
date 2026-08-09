module Hobo
  module Model
    class Guest

      alias_method :has_hobo_method?, :respond_to?

      def to_s
        "guest"
      end

      def guest?
        true
      end

      # **A guest is nobody, and `present?` has to say so.**
      #
      # Hobo 2's generated models asked the acting user questions -- `acting_user.
      # administrator?` -- and this object answered no. Hobo 3's models are
      # written the Rails way, `acting_user.present?`, and an object is present:
      # so the model layer let a stranger create records. In a generated
      # application a visitor could open `/stories/new` and POST one in, while
      # the same page correctly refused to paint an edit or a delete for them --
      # the tags normalise a guest to nil and the model layer did not.
      #
      # The obvious fix is the wrong one: making `current_user` answer nil for a
      # stranger removes the *acting user* altogether, and Hobo reads that as
      # "nothing is acting" -- the console, a seed script -- and **skips the
      # permission checks entirely**. That is how this object earns its keep: it
      # is the difference between nobody watching and somebody who is nobody.
      #
      # So it stays an object, and it is blank. `present?` is `!blank?`.
      def blank?
        true
      end

      def signed_up?
        false
      end

      def login
        "guest"
      end

    end
  end
end
