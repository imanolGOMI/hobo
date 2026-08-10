# The first thing a person sees, and the first thing they can do.
#
# A brand new Hobo application used to open on a form that said "Register
# Administrator": no console, no seeds, no reading the README -- you fill in
# three boxes and the application is yours. It is specified in the old bench, in
# integration_tests/agility_bootstrap/test/integration/create_account_test.rb,
# and losing it is losing the first five minutes of Hobo.
#
# What has changed is who owns the user: Rails 8 generates the model, the
# session and the password handling (`bin/rails generate authentication`), and
# piece 15 delegates all of that. What Hobo keeps is **this page**, because
# Rails does not have it: knowing that an application with no users should ask
# for one is a Hobo idea.

require "rapid"
require "hobo_rapid/translation"
require "hobo_rapid/tags/structure"
require "hobo_rapid/tags/inputs"

module HoboRapid
  module Tags

    module FrontPageSupport

      # The application's user model, whatever it called it.
      def user_model
        return @user_model if defined?(@user_model)
        @user_model = %w[User Account].filter_map { |name| Object.const_get(name) rescue nil }.first
      end

      def no_users_yet?
        model = user_model
        model.respond_to?(:count) && model.count.zero?
      rescue StandardError
        false
      end

      # What the model calls the thing people log in with. Rails 8 generates
      # `email_address`; older applications used `email` or `login`.
      def login_field
        columns = user_model.respond_to?(:column_names) ? user_model.column_names : []
        (%w[email_address email login name] & columns).first || "email_address"
      end

      # And what it calls the person. Hobo shows a record by its `name`, so a
      # user model that has one has to be **asked** for one -- otherwise the
      # account is created nameless and shows up as "User 1" everywhere.
      #
      # `nil` when the model has no such column, which is the case in an
      # application that added Hobo to a user of its own: the form then asks for
      # what there is, as it did before.
      def display_name_field
        columns = user_model.respond_to?(:column_names) ? user_model.column_names : []
        "name" if columns.include?("name") && login_field != "name"
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::FrontPageSupport)

Rapid.define(:front_page, :attrs => [:app_name, :action]) do
  in_page(attributes[:app_name] || t(:"front.title", "Home")) do
    tag("div", { :class => "front-page" }, :body) do
      # Los mensajes los pinta `<page>`, que es por donde pasa esto: pintarlos
      # otra vez aquí es verlos **dos veces** -- «You are now the site
      # administrator» duplicado, que es justo la primera pantalla que ve nadie.
      if no_users_yet?
        call_tag(:first_user_form, { :action => attributes[:action] }, :as => :first_user)
      else
        param(:welcome) do
          tag("h1", {}, :heading) { text attributes[:app_name] || "Hobo" }
          tag("p", { :class => "blurb" }, :blurb) { text t(:"front.blurb", "You can log in and start now.") }
        end
      end
    end
  end
end

# Creating an account: the same form twice.
#
# Hobo 2 had two places to make a user and they were both *there*: the front
# page asked for the site administrator while `User.count == 0`, and after that
# anybody could sign up at `/users/signup` -- a `create :signup` step of the
# user's lifecycle, with its link in the bar.
#
# Hobo 3 delegates the user to Rails 8 (decision 15), and **Rails' own
# authentication generator writes a session and a password reset, not a
# registration**. So the first half was here (the front page) and the second
# half was nowhere: after the first person, an application had no way to make
# another user except the console. The generator's own comment said "anybody
# else signs up normally", and there was no normally.
#
# One tag, then, and two callers: `<first-user-form>` is this with the words of
# somebody who is about to own the application.
Rapid.define(:signup_form, :attrs => [:action, :heading, :blurb, :button_label, :class, :fields]) do
  field = login_field

  # Which halves of the form to paint. The whole thing by default; an invitation
  # asks an administrator only for the address, and asks the person who accepts
  # it only for a password. It is one form because it is one thing -- making an
  # account -- asked in two sittings.
  wanted = Array(attributes[:fields] || %w[name login password]).map(&:to_s)

  tag("div", { :class => attributes[:class] || "signup" }, :box) do
    tag("h1", {}, :heading) { text attributes[:heading] || t(:"front.signup", "Create an account") }
    tag("p", { :class => "blurb" }, :blurb) do
      text attributes[:blurb] || t(:"front.signup_blurb", "Choose an email address and a password.")
    end

    tag("form", { :method => "post", :action => attributes[:action] || "/", :class => "signup-form" }, :form) do
      param(:authenticity_token) { authenticity_token_field }

      # El nombre primero, como en el alta de Hobo 2: nombre, correo,
      # contraseña, repetir contraseña.
      if wanted.include?("name") && (person = display_name_field)
        tag("div", { :class => "field" }, :name_field) do
          tag("label", { :for => "user_#{person}" }, :name_label) { text t(:"front.name", "Name") }
          tag("input", { :type => "text", :name => "user[#{person}]",
                         :id => "user_#{person}", :required => true })
        end
      end

      if wanted.include?("login")
        tag("div", { :class => "field" }, :"#{field}_field") do
          tag("label", { :for => "user_#{field}" }, :"#{field}_label") { text field.humanize }
          tag("input", { :type => field.include?("email") ? "email" : "text",
                         :name => "user[#{field}]", :id => "user_#{field}", :required => true })
        end
      end

      passwords = wanted.include?("password") ? { "password" => t(:"front.password", "Password"),
                                                  "password_confirmation" => t(:"front.password_confirmation", "Repeat the password") } : {}
      passwords.each do |name, label|
        tag("div", { :class => "field" }, :"#{name}_field") do
          tag("label", { :for => "user_#{name}" }, :"#{name}_label") { text label }
          tag("input", { :type => "password", :name => "user[#{name}]", :id => "user_#{name}", :required => true })
        end
      end

      tag("div", { :class => "actions" }, :actions) do
        tag("button", { :type => "submit", :class => "action submit" }, :submit) do
          text attributes[:button_label] || t(:"front.signup_button", "Sign up")
        end
      end
    end
  end
end

# The same form with the words of somebody who is about to own the application.
# It keeps its own name because the front page calls it by name, and because
# "the first user" and "a user" are not the same event: one of them decides who
# the administrator is.
Rapid.define(:first_user_form, :attrs => [:action]) do
  call_tag(:signup_form,
           { :action => attributes[:action],
             :class => "first-user",
             :heading => t(:"front.welcome", "Welcome"),
             :blurb => t(:"front.no_users",
                         "Nobody is here yet. Create the first user and you will be the administrator."),
             :button_label => t(:"front.register", "Register administrator") },
           :as => :signup, :merge_params => true)
end
