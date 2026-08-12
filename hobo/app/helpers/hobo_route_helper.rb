require_relative 'hobo_helper_base'

module HoboRouteHelper
  # `include Rails.application.routes.url_helpers` used to be here, which meant
  # this file could not even be *loaded* without a booted application. It is not
  # needed: the module is mixed into controllers, and a controller already has
  # the application's url helpers.
  extend HoboHelperBase
    def object_url(obj, *args)
      new_ = object_url_new(obj, *args)
      new_
    end

  protected
    def base_url
      ENV['RAILS_RELATIVE_URL_ROOT'] || ''
    end

    def controller_for(obj)
      if obj.is_a? Class
        obj.name.underscore.pluralize
      else
        obj.class.name.underscore.pluralize
      end
    end


    # Which subsite we are in. The controller class knows -- Admin::StoriesController
    # is the admin subsite -- and it knows outside a request too, which is where
    # `params[:controller]` has nothing to say: a mailer, a job, a console.
    def subsite
      from_class = self.class.name.to_s[/\A(.+?)::/, 1]&.underscore
      return from_class if from_class

      params[:controller]&.match(/([^\/]+)\//)&.[](1) if respond_to?(:params)
    end

    IMPLICIT_ACTIONS = [:index, :show, :create, :update, :destroy]

    def object_url_new(obj, *args)
      options = args.extract_options!
      action = args.first&.to_sym
      options, params = options.partition_hash([:subsite, :method, :format])
      options[:subsite] ||= self.subsite

      action ||= case options[:method].to_s
                 when 'put';    :update
                 when 'post';   :create
                 when 'delete'; :destroy
                 else if obj.is_a?(Class) || obj.respond_to?(:length)
                        :index
                      else
                        if obj.try(:new_record?)
                          return nil
                        else
                          :show
                        end
                      end
                 end

      params[:action] = action unless action.in?(IMPLICIT_ACTIONS)

      if obj.respond_to?(:member_class)
        if obj.respond_to?(:origin) && obj.origin
          # Asking for URL of a collection, e.g. category/1/adverts or category/1/adverts/new
          refl = obj.origin.class.reverse_reflection(obj.origin_attribute)
          owner_name = refl.name.to_s
          owner_name = owner_name.singularize if refl.macro == :has_many
          poly = [owner_name, obj.member_class]
          params[:"#{owner_name}_id"] = obj.origin.id
          params = params.symbolize_keys
          action = "#{action}_for_#{owner_name}"
        else
          poly = [obj.member_class]
        end
      else
        poly = [obj]
      end

      # A symbol, not a string: Rails refuses a string namespace in a polymorphic
      # route ("Please use symbols for polymorphic route arguments"). It raised
      # ArgumentError, which the rescue below turned into nil -- so every link
      # into a subsite came out empty, and nothing said why.
      poly = [options[:subsite].to_sym] + poly if !options[:subsite].blank?

      begin
        base_url = url = polymorphic_path(poly, params)
        # validate URL, since polymorphic URL may return a URL for a
        # different method
        if Rails.application.config.action_controller.relative_url_root
          base_url = url.gsub(/^#{Rails.application.config.action_controller.relative_url_root}/, "")
        end
        recognized_params = Rails.application.routes.recognize_path(base_url, {:method => options[:method]})
        url
      rescue NoMethodError => e  # raised if polymorphic_url fails
        logger.info("polymorphic_url has failed with NoMethodError: #{e.message}")
        nil
      rescue ArgumentError => e  # raised from polymorphic_url
        logger.info("polymorphic_url has failed with ArgumentError: #{e.message}")
        nil
      rescue ActionController::RoutingError => e  # raised if recognize_path fails
        logger.info("recognize_path has failed: #{e.message}")
        nil
      rescue ActionController::UrlGenerationError => e # error that inherits from ActionController::RoutingError
        logger.info("UrlGenerationError: #{e.message}")
        nil
      end

    end

    def linkable?(*args)
      options = args.extract_options!
      target = args.empty? || args.first.is_a?(Symbol) ? this : args.shift
      action = args.first
      object_url_new(target, action, options)
    end

    def base_url_for(object, subsite, action)
      path = object.to_url_path or Hobo::Error.new("cannot create url for #{object.inspect} (#{object.class})")
      "#{base_url}#{'/' + subsite unless subsite.blank?}/#{path}"
    end

    def recognize_page_path
      if params[:page_path]
        url = params[:page_path]
        method = "GET"
        Rails.application.routes.recognize_path(url, :method => method)
      else
        # We used to use "url_for(params)", but with Rails 4 stopped working
        # It seems that we can send back the params directly
        params
      end
    end

    def url_for_page_path(options={})
      url_for recognize_page_path.merge(options).merge({:only_path => true})
    end

    def controller_action_from_page_path
      recognize_page_path.values_at(:controller,:action)
    end

    def defined_route?(r)
      @view.respond_to?("#{r}_url")
    end

    def _as_params(name, obj)
      if obj.is_a? Array
        obj.map {|x| _as_params("#{name}[]", x)}.join("&")
      elsif obj.is_a? Hash
        obj.map {|k,v| _as_params("#{name}[#{k}]", v)}.join("&")
      elsif obj.is_a? Hobo::RawJs
        "#{name}=' + #{obj} + '"
      else
        v = if obj.is_one_of?(ActiveRecord::Base, Array)
              "@" + typed_id(obj)
            else
              obj.to_s.gsub("'"){"\\'"}
            end
        "#{name}=#{v}"
      end
    end

    def make_params(*hashes)
      hash = {}
      hashes.each {|h| hash.update(h) if h}
      hash.map {|k,v| _as_params(k, v)}.join("&")
    end

    def current_page_url
      request.fullpath.match(/^([^?]*)/)&.[](1)
    end

    # Login url for a given user record or user class
    def forgot_password_url(user_class=Hobo::Model::UserBase.default_user_model)
      send("#{user_class.name.underscore}_forgot_password_path") rescue nil
    end


    # Login url for a given user record or user class
    def login_url(user_class=Hobo::Model::UserBase.default_user_model)
      send("#{user_class.name.underscore}_login_path") rescue nil
    end


    # Sign-up url for a given user record or user class
    def signup_url(user_class=Hobo::Model::UserBase.default_user_model)
      send("signup_#{user_class.name.underscore.pluralize}_path") rescue nil
    end


    # Login url for a given user record or user class
    def logout_url(user_or_class=nil)
      c = if user_or_class.nil?
            current_user.class
          elsif user_or_class.is_a?(Class)
            user_or_class
          else
            user_or_class.class
          end
      send("#{c.name.underscore}_logout_path") rescue nil
    end

    def new_for_current_user(model_or_assoc=nil)
      model_or_assoc ||= this
      if model_or_assoc.respond_to?(:new_candidate)
        model_or_assoc.user_new_candidate(current_user)
      else
        model_or_assoc.user_new(current_user)
      end
    end

end
