require "test_helper"
require "rapid/param_contract"
require "hobo_rapid/tags/structure"

# Piece 13a: the tags that used to live in the Bootstrap theme and should never
# have. A flash message, a list of errors, the moves a record offers -- an
# application *has* those, whatever it looks like.
class StructureTest < Minitest::Test
  include ParamContract::Assertions

  Errors = Struct.new(:messages) do
    def empty? = messages.empty?
    def size = messages.size
    def to_a = messages
  end

  ModelName = Struct.new(:human)

  class Story
    attr_accessor :errors
    def initialize(messages = []) = @errors = Errors.new(messages)
    def self.model_name = ModelName.new("Historia")
    def viewable_by?(_user, _field = nil) = true
  end

  Transition = Struct.new(:name)

  class Lifecycle
    def initialize(names) = @names = names
    def available_transitions_for(_user) = @names.map { |n| Transition.new(n) }
  end

  class Article
    def initialize(names) = @names = names
    def lifecycle = Lifecycle.new(@names)
    def viewable_by?(_user, _field = nil) = true
  end

  def render(tag_name, this = nil, flash: {})
    Rapid::Tag.class_eval { define_method(:flash_messages) { flash } }
    Rapid.render(tag_name, {}, :this => this)
  ensure
    Rapid::Tag.class_eval { define_method(:flash_messages) { {} } }
  end

  # --- flash ------------------------------------------------------------------

  def test_a_flash_message_paints_what_the_application_left
    html = render(:flash_message, nil, :flash => { :notice => "Guardado" })

    assert_includes html, "Guardado"
    assert_includes html, %(class="flash flash-notice")
    assert_includes html, %(role="alert")
  end

  def test_no_message_means_nothing_painted
    assert_equal "", render(:flash_message, nil, :flash => {})
  end

  # The kinds are the application's, not a fixed list.
  def test_every_kind_the_application_left_is_painted
    html = render(:flash_messages, nil, :flash => { :notice => "Guardado", :error => "Ups" })

    assert_includes html, "Guardado"
    assert_includes html, "Ups"
    assert_includes html, "flash-error"
  end

  # --- errors -----------------------------------------------------------------

  def test_the_errors_of_a_record_are_listed
    html = render(:error_messages, Story.new(["El titulo no puede estar en blanco", "El cuerpo tampoco"]))

    assert_includes html, "2 errors stopped this Historia from being saved"
    assert_includes html, "<li>El titulo no puede estar en blanco</li>"
  end

  def test_one_error_is_said_in_singular
    assert_includes render(:error_messages, Story.new(["Uno solo"])), "1 error stopped"
  end

  # A form should not carry an empty box about.
  def test_a_record_with_no_errors_paints_nothing
    assert_equal "", render(:error_messages, Story.new)
  end

  # --- transitions ------------------------------------------------------------

  # The buttons are not written anywhere: they are what the record can do right
  # now, for this user. That is what lifecycles are for.
  def test_the_buttons_are_the_moves_the_record_offers
    html = render(:transition_buttons, Article.new(%i[publish retract]))

    assert_includes html, "Publish"
    assert_includes html, "Retract"
    assert_includes html, "?transition=publish"
  end

  def test_a_record_with_no_moves_paints_nothing
    assert_equal "", render(:transition_buttons, Article.new([]))
  end

  # --- the contract -----------------------------------------------------------

  def test_every_param_of_the_error_messages_is_overridable
    assert_every_param_overridable(:error_messages, { :name => "con errores", :this => Story.new(["Uno"]) })
  end

  def test_every_param_of_the_transitions_is_overridable
    assert_every_param_overridable(:transition_buttons, { :name => "con transiciones", :this => Article.new(%i[publish]) })
  end

  # --- quien esta usando la aplicacion ----------------------------------------

  # Hobo's `current_user` never answers nil: it answers a Guest, an object that
  # says no to everything. That is right for the model layer, which asks it
  # questions, and wrong for the tags -- a generated model says
  # `acting_user.present?`, and **a Guest is present**, so a stranger was
  # offered an edit and a delete on every row.
  class Guestish
    def guest? = true
    def id = nil
  end

  def test_a_guest_is_nobody
    painted = HoboRapid.with_request(nil, Guestish.new) do
      Rapid.render(:session_links)
    end

    refute_includes painted, "Logged in as"
  end

  def test_somebody_is_somebody
    user = Struct.new(:id, :email_address).new(1, "imanol@example.com")

    painted = HoboRapid.with_request(nil, user) { Rapid.render(:session_links) }

    assert_includes painted, "Logged in as imanol@example.com"
  end

  # --- signing up ---------------------------------------------------------------

  # The other half of the bar. Hobo 2 offered signup next to log in; Hobo 3 lost
  # it, because Rails' authentication generator writes a session and a password
  # reset and **no registration**, and the front page covers only the *first*
  # user. Nothing failed: no test of ours ever needed a second person.
  #
  # The route is the switch, so a stranger only sees the offer when the
  # application has actually drawn one.
  def with_route(name, path)
    Rapid::Tag.class_eval do
      alias_method :route_path_without_stub, :route_path
      define_method(:route_path) { |route| route == name ? path : nil }
    end
    yield
  ensure
    Rapid::Tag.class_eval do
      alias_method :route_path, :route_path_without_stub
      remove_method :route_path_without_stub
    end
  end

  def test_a_stranger_is_offered_a_way_to_get_an_account
    painted = with_route(:signup_path, "/signup") { Rapid.render(:session_links) }

    assert_includes painted, %(href="/signup")
    assert_includes painted, "Sign up"
  end

  def test_and_nothing_is_offered_when_the_application_has_no_signup
    painted = with_route(:new_session_path, "/session/new") { Rapid.render(:session_links) }

    refute_includes painted, "Sign up"
  end

  # Somebody already logged in is not offered an account.
  def test_signing_up_is_not_offered_to_whoever_is_already_in
    user = Struct.new(:id, :email_address).new(1, "imanol@example.com")

    painted = with_route(:signup_path, "/signup") do
      HoboRapid.with_request(nil, user) { Rapid.render(:session_links) }
    end

    refute_includes painted, "Sign up"
  end

  # --- searching the whole site ---------------------------------------------------
  #
  # Hobo 2 had a box in the bar that looked for the words in every model. The
  # engine that does the looking is still here (`Hobo.find_by_search`); what was
  # missing was somewhere to type and somewhere to read.

  def test_there_is_no_box_when_the_application_has_no_search
    assert_empty Rapid.render(:search_box).strip
  end

  def test_the_box_appears_when_the_route_does
    painted = with_route(:site_search_path, "/search") { Rapid.render(:search_box) }

    assert_includes painted, %(action="/search")
    assert_includes painted, %(name="query")
  end

  # And it says what you last looked for, so the page you land on is about the
  # question you asked.
  def test_the_box_remembers_the_question
    painted = with_route(:site_search_path, "/search") do
      HoboRapid.with_request(nil, nil, {}, { "query" => "gatos" }) { Rapid.render(:search_box) }
    end

    assert_includes painted, %(value="gatos")
  end

  # --- and the answers ---------------------------------------------------------

  Found = Struct.new(:id, :name) do
    def self.name_attribute = :name
    def viewable_by?(_user, _field = nil) = true
  end

  def test_the_results_come_grouped_by_model
    painted = Rapid.render(:search_results, { :query => "gatos",
                                              :results => { "Story" => [Found.new(1, "Una historia")],
                                                            "Category" => [Found.new(2, "Gatos"), Found.new(3, "Otra")] } })

    assert_includes painted, "Story (1)"
    assert_includes painted, "Category (2)"
    assert_includes painted, "Una historia"
  end

  # A search that found nothing says so. A page that answers an empty page to a
  # question looks broken.
  def test_nothing_found_is_an_answer_too
    painted = Rapid.render(:search_results, { :query => "loquesea", :results => {} })

    assert_includes painted, "Nothing matched"
  end

  # The user changer is a way to become anybody. Outside development it must not
  # exist -- not hidden, not disabled: absent.
  def test_the_user_changer_paints_nothing_outside_development
    assert_empty Rapid.render(:dev_user_changer).strip
  end

end
