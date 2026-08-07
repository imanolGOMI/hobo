# The helpers live in app/, which in a Rails application Zeitwerk manages -- but
# these are named from lib/ while a controller class is being defined, before
# any of that has happened. Naming them out loud is what the classic autoloader
# used to do behind our backs.
helpers = File.expand_path('../../../app/helpers', __FILE__)
require File.join(helpers, 'hobo_route_helper')
require File.join(helpers, 'hobo_translations_helper')
require File.join(helpers, 'hobo_translations_normalizer_helper')
require File.join(helpers, 'hobo_permissions_helper')
require 'hobo/model/guest'
require 'hobo/controller/authentication_support'
require 'hobo/controller/cache'

module Hobo

  module Controller

    include AuthenticationSupport
    include Cache

    class << self

      def included(base)
        if base.is_a?(Class)
          included_in_class(base)
        end
      end

      def included_in_class(klass)
        klass.extend(ClassMethods)
        klass.extend(HiddenActions)
        klass.class_eval do
          before_action :login_from_cookie
          prepend ObjectUrlRedirect
          private
          def set_mailer_default_url_options
            unless Rails.application.config.action_mailer.default_url_options
              Rails.application.config.action_mailer.default_url_options = { :host => request.host }
              Rails.application.config.action_mailer.default_url_options[:port] = request.port unless request.port == 80
            end
          end
          before_action :set_mailer_default_url_options
          @included_taglibs = []
          rescue_from ActionController::RoutingError, :with => :not_found unless Rails.env.development?
        end
        HoboRouteHelper.add_to_controller(klass)
        HoboTranslationsHelper.add_to_controller(klass)
        HoboTranslationsNormalizerHelper.add_to_controller(klass)
        HoboPermissionsHelper.add_to_controller(klass)
      end

    end

    # What `hide_action` used to do: keep the helper methods a controller mixes
    # in from becoming actions anybody can request.
    module HiddenActions

      def hobo_hidden_action_methods
        @hobo_hidden_action_methods ||=
          if superclass.respond_to?(:hobo_hidden_action_methods)
            superclass.hobo_hidden_action_methods.dup
          else
            Set.new
          end
      end

      def action_methods
        super - hobo_hidden_action_methods
      end

    end


    module ClassMethods

      attr_reader :included_taglibs

      def include_taglib(src, options={})
        @included_taglibs << options.merge(:src => src)
      end

    end


    protected

    # `redirect_to record` works out the record's url. It was an
    # alias_method_chain; a prepended module composes instead of renaming.
    module ObjectUrlRedirect
      def redirect_to(destination, *args)
        if destination.is_one_of?(String, Hash, Symbol)
          super
        else
          super(object_url(destination, *args))
        end
      end
    end


    # The "parts" protocol used to live here.
    #
    # It worked like this, and it dated from about 2008: the browser sent
    # `render[i][part_context]`, a serialised marker of which fragment of a
    # template had painted each node; `ajax_update_response` called
    # `refresh_part`, which **re-ran that fragment** with its saved context; and
    # the answer came back as **JavaScript** -- `hjq.ajax.update("id", "<html>")`
    # -- that put the result in place.
    #
    # That is what Turbo Frames do in Rails 8, without a marker to serialise,
    # without a session round trip and without answering in JavaScript. So the
    # protocol is gone (decision 15) and with it part_context.rb, the global
    # `hobo_parts` page data and most of hjq.js.
    #
    # `refresh_part` lived in the old DRYML compiler, which layer 3 replaced, so
    # there was no keeping this as it was in any case.

    def site_search(query)
      results_hash = Hobo.find_by_search(query)
      all_results = results_hash.values.flatten.select { |r| r.viewable_by?(current_user) }
      if all_results.empty?
        render :plain => "<p>"+ t("hobo.live_search.no_results", :default=>["Your search returned no matches."]) + "</p>"
      else
        # TODO: call one tag that renders all the search results with headings for each model
        render_tags(all_results, :search_card, :for_type => true)
      end
    end


    # Store the given user in the session.
    def current_user=(new_user)
      session[:user] = (new_user.nil? || new_user.guest?) ? nil : new_user.typed_id
      @current_user = new_user
    end


    def request_no_cache?
      request.env['HTTP_CACHE_CONTROL'] =~ /max-age=\s*0/
    end

    def not_found(error)
      if self.class.superclass.method_defined?("not_found_response")
        super
      elsif render :not_found, :status => 404
        # cool
      else
        render(:text => t("hobo.messages.not_found", :default=>["The page you requested cannot be found."]) , :status => 404)
      end
    end

  end
end


