module Hobo
  module Controller
  module UserBase

    class << self
      def included(base)
        base.class_eval do
          singleton_class.prepend(UserActions)

          skip_before_action :login_required, :only => [:login, :signup, :do_signup, :forgot_password, :reset_password, :do_reset_password,
                                                        :accept_invitation, :do_accept_invitation]

          prepend AccountFlash
        end

      end


    end

    # The actions a user controller adds on top of the seven usual ones. It was
    # alias_method_chain on the singleton class; a prepended module composes.
    module UserActions

      def available_auto_actions
        super + [:login, :logout, :forgot_password, :reset_password, :account]
      end

      def def_auto_actions
        super

        class_eval do
          def login; hobo_login;                         end if include_action?(:login)
          def logout; hobo_logout;                       end if include_action?(:logout)
          def signup; hobo_signup;                       end if include_action?(:signup)
          def do_signup; hobo_do_signup                  end if include_action?(:do_signup)
          def forgot_password; hobo_forgot_password;     end if include_action?(:forgot_password)
          def do_reset_password; hobo_do_reset_password; end if include_action?(:do_reset_password)
          show_action :account                               if include_action?(:account)
        end
      end

    end


    private

    def hobo_login(options={}, &block)
      if logged_in?
        respond_to do |wants|
          wants.html { redirect_to home_page }
        end
        return
      end

      login_attr = model.human_attribute_name(model.login_attribute)
      options.reverse_merge!(:failure_notice => ht(:"#{model.to_s.underscore}.messages.login.error", :login=>login_attr, :default=>["You did not provide a valid #{login_attr} and password."]))

      if request.post?
        user = model.authenticate(params[:login], params[:password])
        if user.nil?
          flash[:error] = options[:failure_notice]
        else
          self.sign_user_in(user, options, &block)
        end
      end
    end

    def hobo_signup(&b)
      if logged_in?
        redirect_back_or_default(home_page)
      else
        creator_page_action(:signup, &b)
      end
    end

    def hobo_do_signup(&b)
      do_creator_action(:signup) do
        if valid?
          flash[:notice] = ht(:"#{model.to_s.underscore}.messages.signup.success", :default=>["Thanks for signing up!"])
        end
        response_block(&b) or if valid?
                                self.current_user = this if this.account_active?
                                respond_to do |wants|
                                  wants.html { redirect_back_or_default(home_page) }
                                end
                              end
      end
    end


    def hobo_logout(options={})
      options = options.reverse_merge(:notice => ht(:"#{model.to_s.underscore}.messages.logout", :default=>["You have logged out."]),
                                      :redirect_to => base_url)

      logout_current_user
      yield if block_given?
      flash[:notice] ||= options[:notice]
      redirect_back_or_default(options[:redirect_to]) unless performed?
    end


    def hobo_forgot_password
      if request.post?
        user = model.find_by_email_address(params[:email_address].to_s)
        if user && (!block_given? || yield(user))
          user.lifecycle.request_password_reset!(:nobody)
        end
        respond_to do |wants|
          wants.html { render :forgot_password_email_sent }
        end
      end
    end


    def hobo_do_reset_password(&b)
      do_transition_action :reset_password do
        response_block(&b) or if valid?
                                self.current_user = this
                                flash[:notice] = ht(:"#{model.to_s.underscore}.messages.reset_password", :default=>["Your password has been reset"])
                                respond_to do |wants|
                                  wants.html { redirect_to(home_page) }
                                end
                              end
      end
    end


    module AccountFlash
      def hobo_update(*args)
        super(*args) do
          if valid? && @this == current_user
            flash[:notice] = ht(:"#{model.to_s.underscore}.messages.update.success",
                                :default => ["Changes to your account were saved"])
          end
          yield if block_given?
        end
      end
    end

    private

    def logout_current_user
      if logged_in?
        current_user.forget_me
        cookies.delete :auth_token
        reset_session
        self.current_user = nil
      end
    end

    protected
    # If you are authenticating user on your own call this method -
    # hobo will remember signed-in user this way. Arguments:
    # user - user that you want to sign in
    # options - hash with messages (:success_notice, :redirect_to)
    # block - (optional) will be called after assigning current_user
    def sign_user_in(user, options={}, &block)
      options.reverse_merge!(:success_notice => ht(:"#{model.to_s.underscore}.messages.login.success", :default=>["You have logged in."]))

      old_user = current_user
      self.current_user = user

      if block_given?
        unless yield
          self.current_user = nil
          return
        end
      end

      if !user.account_active?
        # account not activate - cancel this login
        self.current_user = old_user
        unless performed?
          respond_to do |wants|
            wants.html {render :action => :account_disabled}
          end
        end
      else
        if params[:remember_me].present?
          current_user.remember_me
          create_auth_cookie
        end
        flash[:notice] ||= options[:success_notice]
        unless performed?
          respond_to do |wants|
            wants.html {redirect_back_or_default(options[:redirect_to] || home_page) }
          end
        end
      end
    end

  end
  end
end
