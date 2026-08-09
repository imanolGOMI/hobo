require "test_helper"
require "hobo_rapid/tags/front_page"

# Making an account: the first one and all the others.
#
# Hobo 2 had both, and they were the same shape: the front page asked for the
# site administrator while there were no users, and after that anybody could
# sign up -- `/users/signup`, with its link in the bar. Hobo 3 delegates the
# user to Rails 8 (decision 15), and **Rails' authentication generator writes a
# session and a password reset and no registration**, so the second half went
# missing without a sound: the front page covers the first person, and nothing
# covered the next one. An application ended up with exactly one user, forever.
#
# Nothing here could fail before, which is the point: no test of ours ever
# needed a second person, and the generated application never noticed.
class FrontPageTest < Minitest::Test

  # What `<signup-form>` asks the user model for. In an application this is the
  # real User; the tag only wants to know which field is the login.
  class User
    def self.column_names = %w[id email_address password_digest]
  end

  def setup
    Object.const_set(:User, User) unless Object.const_defined?(:User)
  end

  def teardown
    HoboTest.clean_up(:User) if Object.const_defined?(:User) && Object.const_get(:User) == User
  end

  # Con llaves, y a proposito: `Rapid.render(:x, :a => 1)` sin ellas manda `:a`
  # a los **params**, no a los atributos, porque `render` tiene keywords. Es la
  # misma trampa que anota el PLAN para `call_tag`.
  def signup(attributes = {}) = Rapid.render(:signup_form, attributes)

  # --- the form ----------------------------------------------------------------

  def test_it_asks_for_the_login_field_and_a_password_twice
    html = signup

    assert_includes html, %(name="user[email_address]")
    assert_includes html, %(name="user[password]")
    assert_includes html, %(name="user[password_confirmation]")
  end

  def test_it_posts_where_it_is_told
    assert_includes signup({ :action => "/signup" }), %(action="/signup")
  end

  def test_it_carries_the_forgery_token
    assert_includes HoboRapid.with_request("un-token", nil) { signup }, "un-token"
  end

  # --- the two callers ------------------------------------------------------------

  # The first user is a different event -- somebody is about to own the
  # application -- so it says so, while being the same form.
  def test_the_first_user_form_is_the_signup_form_with_other_words
    html = Rapid.render(:first_user_form, { :action => "/first-user" })

    assert_includes html, %(action="/first-user")
    assert_includes html, %(name="user[email_address]")
    assert_includes html, "administrator"
    assert_includes html, "first-user"
  end

  def test_the_ordinary_signup_does_not_promise_anybody_the_application
    html = signup

    refute_includes html, "administrator"
  end

  # A theme has to be able to change the words without rewriting the form, and
  # that is what the attributes are for.
  def test_the_words_can_be_replaced
    html = signup({ :heading => "Unete", :button_label => "Vamos" })

    assert_includes html, "Unete"
    assert_includes html, "Vamos"
  end

  # --- the front page ----------------------------------------------------------

  # The front page still decides which of the two an arriving stranger sees, and
  # it decides it from the only thing that matters: whether anybody is here yet.
  def test_the_front_page_offers_the_first_user_when_there_is_nobody
    html = with_users(0) { Rapid.render(:front_page, { :action => "/first-user" }) }

    assert_includes html, "administrator"
  end

  def test_and_stops_offering_it_once_somebody_is
    html = with_users(1) { Rapid.render(:front_page, { :action => "/first-user" }) }

    refute_includes html, "administrator"
  end

  def with_users(count)
    User.define_singleton_method(:count) { count }
    yield
  ensure
    User.singleton_class.send(:remove_method, :count)
  end

end
