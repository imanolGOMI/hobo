# Bundler only requires the gems an application lists itself, not the ones its
# gems depend on -- so a gem has to require what it uses. `respond_to` and
# `respond_with` at class level came out of Rails core in 5.0.
require 'responders'
require 'hobo/controller'

module Hobo
  module Controller
    module Model

    include Hobo::Controller

    # `Mime::CSV` and friends went away in Rails 5; formats are symbols now.
    DONT_PAGINATE_FORMATS = %i[csv yaml json xml atom rss].freeze

    WILL_PAGINATE_OPTIONS = [ :page, :per_page, :total_entries, :count, :finder ]

    READ_ONLY_ACTIONS  = [:index, :show]
    WRITE_ONLY_ACTIONS = [:create, :update, :destroy]
    FORM_ACTIONS       = [:new, :edit]

    class << self

      def included(base)
        base.class_eval do
          @auto_actions ||= {}

          inheriting_cattr_reader :web_methods => [], :show_actions => [], :index_actions => [],
                                  :owner_actions => {}

          extend ClassMethods


          helper_method :model, :current_user
          before_action :set_no_cache_headers

          rescue_from ActiveRecord::RecordNotFound, :with => :not_found unless Rails.env.development?

          rescue_from Hobo::PermissionDeniedError,         :with => :permission_denied
          rescue_from Hobo::Model::Lifecycles::LifecycleKeyError, :with => :permission_denied

          # The catalogue raises **its own** permission error -- `<view>` asks
          # `viewable_by?` before painting a field, and the tag runtime has to be
          # loadable without the whole of Hobo, so it cannot name
          # `Hobo::PermissionDeniedError`.
          #
          # Nothing rescued it, and the two never met until an application had a
          # model that says no: a page a visitor may not see came out as a **500**
          # instead of sending them to the login. Hobo's own generated
          # applications let everybody view everything, so it took porting one
          # with real permissions to see it.
          rescue_from HoboRapid::PermissionDenied, :with => :permission_denied if defined?(HoboRapid::PermissionDenied)

          respond_to :html

          # Rails 8's authentication generator puts `require_authentication` on
          # every controller, and that fights Hobo: with it, **no request ever
          # reaches the permission check**, so `view_permitted?` never gets to
          # say anything and a public index becomes a login wall.
          #
          # In Hobo the model decides who sees what, so a Hobo controller lets
          # the request through and asks the record. An application that wants a
          # login wall as well says so in its own controller -- that is one line
          # and it is theirs to write.
          allow_unauthenticated_access if respond_to?(:allow_unauthenticated_access)

          # And the other half of that decision, which was missing: Rails 8
          # resumes the session **inside** `require_authentication`, the very
          # filter that was just skipped. So nobody ever read the cookie,
          # `Current.session` stayed nil, and a signed-in person was painted as
          # a guest -- read-only forms, no actions column, and not one test
          # failed because every piece was asked what it does for a guest.
          #
          # Reading the cookie is not requiring a login: it is finding out who
          # is asking before asking the record.
          before_action :resume_session_if_any if respond_to?(:allow_unauthenticated_access)

          prepend HoboModelRender

        end
        register_controller(base)
        subsite = base.name.include?("::") ? base.name.split("::").first.underscore : nil
        base.model.hobo_controller[subsite] = base

        Hobo::Controller.included_in_class(base)
      end

    end


    def self.register_controller(controller)
      @controller_names ||= Set.new
      @controller_names << controller.name
    end


    def self.all_controllers(subsite=nil, force=false)
      controller_dirs = ["#{Rails.root}/app/controllers"] + Hobo.engines.map { |e| "#{e}/app/controllers" }

      # Load every controller in app/controllers/<subsite>...
      @controllers_loaded ||= {}
      if force || !@controllers_loaded[subsite]
        controller_dirs.each do |controller_dir|
          dir = "#{controller_dir}#{'/' + subsite if subsite}"
          if File.directory?(dir)
            Dir.entries(dir).each do |f|
              if f =~ /^[a-zA-Z_][a-zA-Z0-9_]*_controller\.rb$/
                name = f.remove(/.rb$/).camelize
                name = "#{subsite.camelize}::#{name}" if subsite
                name.constantize
              end
            end
          end
        end
        @controllers_loaded[subsite] = true
      end

      # ...but only return the ones that registered themselves
      names = (@controller_names || []).select { |n| subsite ? n =~ /^#{subsite.camelize}::/ : n !~ /::/ }

      names.map do |name|
        name.safe_constantize || (@controller_names.delete name; nil)
      end.compact
    end


    module ClassMethods

      attr_writer :model

      def model_name
        model.name.underscore
      end

      def model
        @model ||= controller_name.camelcase.singularize.constantize
      end


      def autocomplete(*args, &block)
        options = args.extract_options!
        name = args.first || model.name_attribute
        field = options.delete(:field) || name
        if block
          index_action "complete_#{name}", &block
        else
          index_action "complete_#{name}" do
            hobo_completions field, model, options
          end
        end
      end


      def web_method(web_name, options={}, &block)
        web_methods << web_name.to_sym
        method = options.delete(:method) || web_name
        got_block = block_given?
        define_method web_name do
          # Make sure we have a copy of the options - it is being mutated somewhere
          opts = options.dup
          self.this = find_instance(opts)
          raise Hobo::PermissionDeniedError unless @this.method_callable_by?(current_user, method)
          if got_block
            this.with_acting_user(current_user) { instance_eval(&block) }
          else
            @this.send(method)
          end

          head(:ok) unless performed?
        end
      end


      def auto_actions(*args)
        options = args.extract_options!

        @auto_actions = args.map do |arg|
                          case arg
                          when :all        then available_auto_actions
                          when :write_only then available_auto_write_actions
                          when :read_only  then available_auto_read_actions
                          when :lifecycle  then available_auto_lifecycle_actions
                          else arg
                          end
                        end.flatten.uniq

        except = Array(options[:except])
        except_actions = except.map do |arg|
          case arg
            when :lifecycle   then available_auto_lifecycle_actions
            else arg
          end
        end.flatten.uniq

        @auto_actions -= except_actions

        def_auto_actions
      end


      def def_auto_actions
        self.class_eval do
          def index;   hobo_index   end if include_action?(:index)
          def show;    hobo_show    end if include_action?(:show)
          def new;     hobo_new     end if include_action?(:new)
          def create;  hobo_create  end if include_action?(:create)
          def edit;    hobo_show    end if include_action?(:edit)
          def update;  hobo_update  end if include_action?(:update)
          def destroy; hobo_destroy end if include_action?(:destroy)

          def completions; hobo_completions end if include_action?(:completions)

          def reorder; hobo_reorder end if include_action?(:reorder)
        end

        def_lifecycle_actions
      end


      def def_auto_action(name, &block)
        define_method name, &block if !method_defined?(name) && include_action?(name)
      end


      def def_lifecycle_actions
        if model.has_lifecycle?
          model::Lifecycle.publishable_creators.each do |creator|
            name = creator.name
            def_auto_action name do
              creator_page_action name
            end
            def_auto_action "do_#{name}" do
              do_creator_action name
            end
          end

          model::Lifecycle.publishable_transitions.each do |transition|
            name = transition.name
            def_auto_action name do
              transition_page_action name
            end
            def_auto_action "do_#{name}" do
              do_transition_action name
            end
          end
        end
      end


      def show_action(*names, &block)
        options = names.extract_options!
        show_actions.concat(names)
        for name in names
          if block
            define_method(name, &block)
          else
            define_method(name) { hobo_show options.dup }
          end
        end
      end


      def index_action(*names, &block)
        options = names.extract_options!
        index_actions.concat(names)
        for name in names
          if block
            define_method(name, &block)
          else
            if scope = options.delete(:scope)
              if scope.is_a?(Symbol)
                define_method(name) { hobo_index model.send(scope), options.dup }
              else
                define_method(name) { hobo_index scope, options.dup }
              end
            else
              define_method(name) { hobo_index options.dup }
            end
          end
        end
      end


      def creator_page_action(name, options={}, &block)
        define_method(name) do
          creator_page_action name, options, &block
        end
      end


      def do_creator_action(name, options={}, &block)
        define_method("do_#{name}") do
          do_creator_action name, options, &block
        end
      end


      def transtion_page_action(name, options={}, &block)
        define_method(name) do
          transtion_page_action name, options, &block
        end
      end


      def do_transition_action(name, options={}, &block)
        define_method("do_#{name}") do
          do_transition_action name, options, &block
        end
      end


      def auto_actions_for(owner, actions)
        name = model.reflections[owner.to_s].macro == :has_many ? owner.to_s.singularize : owner

        owner_actions[owner] ||= []
        Array(actions).each do |action|
          case action
          when :new
            define_method("new_for_#{name}")    { hobo_new_for owner }
          when :index
            define_method("index_for_#{name}")  { hobo_index_for owner }
          when :create
            define_method("create_for_#{name}") { hobo_create_for owner }
          else
            raise ArgumentError, "Invalid owner action: #{action}"
          end
          owner_actions[owner] << action
        end
      end


      def include_action?(name)
        name.to_sym.in?(@auto_actions)
      end


      def available_auto_actions
        (available_auto_read_actions +
         available_auto_write_actions +
         FORM_ACTIONS +
         available_auto_lifecycle_actions).uniq
      end


      def available_auto_read_actions
        READ_ONLY_ACTIONS
      end


      def available_auto_write_actions
        if model.method_defined?("position_column")
          WRITE_ONLY_ACTIONS + [:reorder]
        else
          WRITE_ONLY_ACTIONS
        end
      end


      def available_auto_lifecycle_actions
        # For each creator/transition there are two possible
        # actions. e.g. for signup, 'signup' would be routed to
        # GET users/signup, and would show the form, while 'do_signup'
        # would be routed to POST /users/signup)
        if model.has_lifecycle?
          (model::Lifecycle.publishable_creators.map { |c| [c.name, "do_#{c.name}"] } +
           model::Lifecycle.publishable_transitions.map { |t| [t.name, "do_#{t.name}"] }).flatten.map(&:to_sym)
        else
          []
        end
      end

    end # of ClassMethods


    protected


    def parse_sort_param(*args)
      _, desc, field = *params[:sort]&.match(/^(-)?([a-z0-9_]+(?:\.[a-z0-9_]+)?)$/)

      if field
        hash = args.extract_options!
        db_sort_field = (hash[field] || hash[field.to_sym] || (field if field.in?(args) || field.to_sym.in?(args))).to_s

        unless db_sort_field.blank?
          if db_sort_field == field && field.match(/\./)
            fields = field.split(".", 2)
            db_sort_field = "#{fields[0].pluralize}.#{fields[1]}"
          end
          @sort_field = field
          @sort_direction = desc ? "desc" : "asc"

          # Marked safe here because this is the one place that holds the
          # whitelist: a sort field that is not among the ones the caller listed
          # never gets this far. Rails 6 and 7 required the mark, Rails 8 allows
          # a raw string again -- saying it explicitly means not depending on
          # which way Rails leans this year.
          Arel.sql("#{db_sort_field} #{@sort_direction}")
        end
      end
    end

    # --- Action implementation helpers --- #


    def find_instance(options={})
      model.user_find(current_user, params[:id]) do |record|
        yield record if block_given?
      end
    end


    def invalid?; !valid?; end


    def valid?; this.errors.empty?; end


    def re_render_form(default_action=nil)
      if params[:page_path]
        @invalid_record = this
        controller, action = controller_action_from_page_path

        # Hack fix for Bug 477.  See also bug 489.
        if self.class.name == "#{controller.camelize}Controller" && action == "index"
          params['action'] = 'index'
          self.action_name = 'index'
	  self.this = find_or_paginate(model, {})
          index
        else
          render :template => "#{controller}/#{action}"
        end
      else
        render :action => default_action
      end
    end


    def destination_after_submit(*args)
      options = args.extract_options!
      destroyed = args[1]
      after_submit = params[:after_submit]

      # The after_submit post parameter takes priority
      (after_submit == "stay-here" ? url_for_page_path : after_submit) ||

        # Then try options[:redirect]
        ((o=options[:redirect]) && begin
                                     if o.is_a?(Symbol)
                                       object_url(@this, o)
                                     elsif o.is_a?(String) || o.is_a?(Hash)
                                       o
                                     else
                                       object_url(*Array(o))
                                     end
                                   end) ||

        # Then try the record's show page
        (!destroyed && !@this.new_record? && object_url(@this)) ||

        # Then the show page of the 'owning' object if there is one
        object_url(owning_object) ||

        # Last try - the index page for this model
        object_url(@this.class) ||

        # Give up
        home_page
    end

    def owning_object
      method = @this.class.view_hints.parent
      method ? @this.send(method) : nil
    end


    def response_block(&b)
      if b
        if b.arity == 1
          respond_to do |format|
            yield format
          end
        else
          yield
        end
        performed?
      end
    end


    def request_requires_pagination?
      request.format.symbol.not_in?(DONT_PAGINATE_FORMATS) && model.view_hints.paginate?
    end


    # `:order_by` is what the pages pass, straight from parse_sort_param, and it
    # used to go nowhere: it stayed in the options hash and was handed to
    # will_paginate, which does not know it. The ordering came from the
    # automatic `order_by` scope instead, and that scope is gone (piece 6). It
    # is applied here now, with the relation's own `order`.
    def find_or_paginate(finder, options)
      # Only ask the request when the caller has not already decided: this is
      # otherwise the one line that makes the method need a live request.
      options[:paginate] = request_requires_pagination? unless options.key?(:paginate)
      do_pagination = options.delete(:paginate) && finder.respond_to?(:paginate)
      finder = Array.wrap(options.delete(:scope)).inject(finder) { |a, v| a.send(*Array.wrap(v).flatten) }

      finder = apply_search(finder)

      order = options.delete(:order_by) || options.delete(:order)
      order = finder.default_order if order.blank? && finder.try(:order_values).blank?
      finder = finder.order(order) if order.present?

      if do_pagination
        finder.paginate(:page => options[:page] || params[:page] || 1,
                        :per_page => options[:per_page])
      else
        # Equivalent to the old finder.scoped (http://stackoverflow.com/a/18199294)
        finder.where(nil)
      end
    end


    # The filters of a list, which are Ransack's (piece 6). The application
    # writes `<search-filter>` or `<filter-menu>` in its page, the browser sends
    # `q[title_cont]=blade`, and this is where it lands. Nothing to configure:
    # the model already said which of its attributes may be searched.
    #
    # Only when `q` is a hash. `hobo_completions` reads `params[:q]` too, as a
    # plain string, because that is what jQuery Tokeninput sent -- the two never
    # meet in one action, but reading a string as a search would be a puzzling
    # way to find that out.
    #
    # It goes *before* the ordering and the pagination, so a filtered list is
    # paginated by what it has left rather than by what it started with.
    def apply_search(finder)
      query = params[:q]
      return finder unless query.is_a?(Hash) || query.respond_to?(:to_unsafe_h)
      return finder unless finder.respond_to?(:ransack)

      query = query.to_unsafe_h if query.respond_to?(:to_unsafe_h)
      finder.ransack(query).result
    end


    def find_owner_and_association(owner_association)
      owner_name = name_of_auto_action_for(owner_association)
      refl = model.reflections[owner_association.to_s]
      id = params["#{owner_name}_id"]
      owner = refl.klass.find(id)
      instance_variable_set("@#{owner_association}", owner)
      [owner, owner.send(model.reverse_reflection(owner_association).name)]
    end

    def name_of_auto_action_for(owner_association)
      model.reflections[owner_association.to_s].macro == :has_many ? owner_association.to_s.singularize : owner_association
    end

    # --- Action implementations --- #

    def hobo_index(*args, &b)
      options = args.extract_options!
      finder = args.first || model
      self.this ||= find_or_paginate(finder, options)
      response_block(&b) || index_response
    end


    def hobo_index_for(owner, *args, &b)
      options = args.extract_options!
      owner, association = find_owner_and_association(owner)
      finder = args.first || association
      self.this ||= find_or_paginate(finder, options)
      response_block(&b) || index_response
    end


    def hobo_show(*args, &b)
      options = args.extract_options!
      self.this ||= args.first
      if this.nil?
        self.this = find_instance(options)
        unless (parms=attribute_parameters).blank?
          this.with_acting_user(current_user) { this.attributes = parms }
        end
      end
      response_block(&b) || show_response
    end

    def hobo_edit(*args, &b)
      hobo_show(*args, &b)
    end

    def hobo_new(record=nil, &b)
      self.this ||= record || model.user_new(current_user, attribute_parameters)
      response_block(&b) || show_response
    end

    # An ajax request used to take a different road here, into the parts
    # protocol. With Turbo it does not: the page is rendered as always and Turbo
    # takes the frame it asked for out of it.
    def show_response
      # `new` and `edit` want a form, not a read-only page. Which one it is is
      # something the action already knows.
      if action_name.in?(%w[new edit])
        # And a form nobody may send is not a form: it used to come out as a
        # page of labels with no inputs, because <input> falls back to showing
        # the value when the field cannot be edited. Refusing says what is
        # actually going on.
        allowed = action_name == "new" ? this.try(:creatable_by?, current_user) : this.try(:editable_by?, current_user)
        raise Hobo::PermissionDeniedError, "#{this.class.name}##{action_name}" if allowed == false

        return render_derived_or(:form_page) { respond_with(self.this) }
      end

      render_derived_or(:show_page) { respond_with(self.this) }
    end

    def index_response
      render_derived_or(:index_page) { respond_with(self.this) }
    end

    def hobo_new_for(owner, record=nil, &b)
      owner, association = find_owner_and_association(owner)
      self.this ||= record || association.user_new(current_user, attribute_parameters)
      response_block(&b) || show_response
    end


    def hobo_create(*args, &b)
      options = args.extract_options!
      attributes = options[:attributes] || attribute_parameters || {}
      if self.this ||= args.first
        this.user_update_attributes(current_user, attributes)
      else
        self.this = new_for_create(attributes)
        this.user_save(current_user)
      end
      flash_notice (ht( :"#{@this.class.to_s.underscore}.messages.create.success", :default=>["The #{@this.class.model_name.human} was created successfully"])) if valid?
      response_block(&b) || create_response(:new, options)
    end


    def hobo_create_for(owner_association, *args, &b)
      options = args.extract_options!
      owner, association = find_owner_and_association(owner_association)
      attributes = options[:attributes] || attribute_parameters || {}
      if self.this ||= args.first
        this.user_update_attributes(current_user, attributes)
      else
        self.this = association.new(attributes)
        this.save
      end
      flash_notice (ht( :"#{@this.class.to_s.underscore}.messages.create.success", :default=>["The #{@this.class.model_name.human} was created successfully"])) if valid?
      response_block(&b) || create_response(:"new_for_#{name_of_auto_action_for(owner_association)}", options)
    end


    # Strong parameters and Hobo's permissions answer different questions, and
    # Rails' answer is not the one Hobo needs.
    #
    # Rails asks "which keys may be assigned", once, in the controller. Hobo asks
    # the *model*, at save time: `update_permitted?` looks at what actually
    # changed -- that is what `only_changed?`, `none_changed?` and `any_changed?`
    # are for -- and `attr_protected` names the fields nobody may ever assign,
    # the lifecycle state among them.
    #
    # So the allowlist is built from what Hobo already knows: everything except
    # the protected fields, and then the model decides. Handing the parameters
    # over raw is not an option either -- Rails has refused that since 4.
    def attribute_parameters
      klass = this ? this.class : model
      parms = params[klass.name.underscore]
      return parms unless parms.respond_to?(:permit)

      protected_names = klass.try(:protected_attributes).to_a.map(&:to_s)
      parms.except(*protected_names).permit!
    end


    def new_for_create(attributes = {})
      type_param = subtype_for_create
      create_model = type_param ? type_param.constantize : model
      create_model.user_new(current_user, attributes)
    end


    def subtype_for_create
      model.has_inheritance_column? && (t = params['type']) && t.in?(model.send(:descendants).map(&:name)) and
        t
    end

    def flash_notice(message)
      flash[:notice] = message unless request.xhr?
    end


    def create_response(new_action=:new, options={})
      valid = valid?  # valid? can be expensive
      if params[:render]
        if (params[:render_options] && params[:render_options][:errors_ok]) || valid
          head(:ok) unless performed?
        else
          errors = @this.errors.full_messages.join('\n')
          message = ht( :"#{this.class.to_s.underscore}.messages.create.error", :errors=>errors,:default=>["Couldn't create the #{this.class.name.titleize.downcase}.\n #{errors}"])
          render :js => "alert(#{message.to_json});\n"
        end
      else
        location = destination_after_submit(options)
        respond_with(self.this, :location => location) do |format|
          format.html do
            if valid
              redirect_to location
            else
              re_render_form(new_action)
            end
          end
        end
      end
    end


    def hobo_update(*args, &b)
      options = args.extract_options!

      self.this ||= args.first || find_instance
      changes = options[:attributes] || attribute_parameters or raise RuntimeError, t("hobo.messages.update.no_attribute_error", :default=>["No update specified in params"])

      if this.user_update_attributes(current_user, changes)
        # Ensure current_user isn't out of date
        @current_user = @this if @this == current_user
      end

      response_block(&b) ||  update_response(nil, options)
    end


    # typically used like this:
    # def update
    #   hobo_update do
    #     if params[:foo]==17
    #       render_my_way
    #     else
    #       update_response   # let Hobo handle it all
    #     end
    #   end
    # end
    #
    # parameters:
    #   valid is a cache of valid?
    #   options is passed through to destination_after_submit
    def update_response(valid=nil, options={})
      # valid? can be expensive, cache it
      valid = valid? if valid.nil?
      if params[:render]
        if (params[:render_options] && params[:render_options][:errors_ok]) || valid
          head(:ok) unless performed?
        else
          errors = @this.errors.full_messages.join('\n')
          message = ht(:"#{@this.class.to_s.underscore}.messages.update.error", :default=>["There was a problem with that change\\n#{errors}"], :errors=>errors)

          render :js => "alert(#{message.to_json});\n"
        end
      else
        location = destination_after_submit(options)
        respond_with(self.this, :location => location) do |format|
          format.html do
            if valid
              flash_notice (ht(:"#{@this.class.to_s.underscore}.messages.update.success", :default=>["Changes to the #{@this.class.model_name.human} were saved"]))
              redirect_to location
            else
              re_render_form(:edit)
            end
          end
        end
      end
    end

    def hobo_destroy(*args, &b)
      options = args.extract_options!
      self.this ||= args.first || find_instance
      this.user_destroy(current_user)
      flash_notice ht( :"#{model.to_s.underscore}.messages.destroy.success", :default=>["The #{model.name.titleize.downcase} was deleted"])
      response_block(&b) || destroy_response(options, &b)
    end


    def destroy_response(options={})
      if params[:render]
        head(:ok)
      else
        redirect_to destination_after_submit(this, true, options)
      end
    end


    # --- Lifecycle Actions --- #

    def creator_page_action(name, options={}, &b)
      self.this ||= model.new
      this.exempt_from_edit_checks = true
      @creator = model::Lifecycle.creator(name)
      raise Hobo::PermissionDeniedError unless @creator.allowed?(current_user)
      response_block &b
    end


    def do_creator_action(name, options={}, &b)
      @creator = model::Lifecycle.creator(name)
      self.this = @creator.run!(current_user, attribute_parameters)
      response_block(&b) || do_creator_response(name, options)
    end

    def do_creator_response(name, options)
      if valid?
        if params[:render]
          head(:ok)
        else
          location = destination_after_submit(options)
          respond_with(self.this) do |wants|
            wants.html { redirect_to location }
          end
        end
      else
        this.exempt_from_edit_checks = true
        if params[:render] && params[:render_options] && params[:render_options][:errors_ok]
          head(:ok) unless performed?
        else
          # errors is used by the translation helper, ht, below.
          errors = this.errors.full_messages.join("\n")
          respond_with(self.this) do |wants|
            wants.html { re_render_form(name) }
          end
        end
      end
    end

    def prepare_transition(name, options)
      key = options.delete(:key) || params[:key]

      # we don't use find_instance here, as it fails for key_holder transitions on objects that Guest can't view
      record = model.find(params[:id])
      record.exempt_from_edit_checks = true
      record.lifecycle.provided_key = key
      self.this = record

      this.lifecycle.find_transition(name, current_user) or raise Hobo::PermissionDeniedError
    end


    def transition_page_action(name, options={}, &b)
      @transition = prepare_transition(name, options)
      response_block &b
    end


    def do_transition_action(name, *args, &b)
      options = args.extract_options!
      @transition = prepare_transition(name, options)
      @transition.run!(this, current_user, attribute_parameters)
      response_block(&b) || update_response(nil, options)
    end

    # --- Miscelaneous Actions --- #

    # Hobo 1.3's name one uses params[:query], jQuery-UI's autocomplete
    # uses params[:term] and jQuery Tokeninput uses params[:q]
    def hobo_completions(attribute, finder, options={})
      options = options.reverse_merge(:limit => 10)
      options[:param] ||= [:term, :q, :query].find { |k| !params[k].nil? }

      # Ransack, in place of the automatic `<attribute>_contains` scope that
      # piece 6 removed. Several attributes at once are `a_or_b_cont`, which is
      # Ransack's own spelling of the same idea -- so the list of scope names
      # the option used to take becomes a list of attribute names.
      attributes = Array.wrap(options[:query_attributes] || attribute)
      finder = finder.ransack("#{attributes.join('_or_')}_cont" => params[options[:param]]).result
      finder = finder.limit(options[:limit]) unless finder.try(:limit_value)
      items = finder.select { |r| r.viewable_by?(current_user) }

      if request.xhr?
        if options[:param] == :q
          render :json => items.map {|i| {:id => "@#{i.send(i.class.primary_key)}", :name => i.send(attribute)}}
        else
          render :json => items.map {|i| i.send(attribute)}
        end
      else
        render :plain => "<ul>\n" + items.map {|i| "<li>#{i.send(attribute)}</li>\n"}.join + "</ul>"
      end
    end


    def hobo_reorder
      ordering = params["#{model.name.underscore}_ordering"]
      if ordering
        ordering.each_with_index do |id, position|
          object = model.find(id)
          object.user_update_attributes!(current_user, object.position_column => position+1)
        end
        head(:ok)
      else
        head :ok
      end
    end



    # --- Response helpers --- #

    def permission_denied(error)
      self.this = true # Otherwise this gets sent user_view
      logger.info "Hobo: Permission Denied! (#{error.inspect})"
      @permission_error = error
      if self.class.superclass.method_defined?("permission_denied")
        super
      else
        respond_to do |wants|
          wants.html do
            # `render` raises when the template is missing, it does not return
            # something falsy, so the fallback below was unreachable: an
            # application without a permission_denied template got a 500 where
            # it should have got a 403.
            begin
              render :permission_denied, :status => 403
            rescue ActionView::MissingTemplate
              render :plain => t("hobo.messages.permission_denied", :default=>["Permission Denied"]), :status => 403
            end
          end
          wants.js do
            render :plain => t("hobo.messages.permission_denied", :default=>["Permission Denied"]), :status => 403
          end
        end
      end
    end


    def this
      @this ||= (instance_variable_get("@#{model.name.demodulize.underscore}") ||
                 instance_variable_get("@#{model.name.demodulize.underscore.pluralize}"))
    end


    def this=(object)
      ivar = if object.is_a?(Array) || object.respond_to?(:member_class)
               (object.try(:member_class) || model).name.demodulize.underscore.pluralize
             else
               object.class.name.demodulize.underscore
             end
      @this = instance_variable_set("@#{ivar}", object)
    end


    def dryml_context
      this
    end


    # An application that has written a template gets its template. One that has
    # not gets the page the derivation engine builds from its model -- which is
    # the whole promise of Hobo: declare the model, and the pages are there.
    #
    # Falling back rather than taking over on purpose: the moment a page needs
    # to be different, you write it, and nothing argues with you.
    def render_derived_or(tag_name)
      return yield if template_exists_for_this_action? || !derived_tag?(tag_name)

      # Through the bridge, not straight to the runtime: `rapid_tag` is what
      # hands the acting user, the forgery token and the flash to the tags.
      # Calling Rapid.render directly skipped all three, so every derived page
      # was painted as if nobody were logged in -- a form with no inputs, and
      # no actions anywhere.
      painted = rapid_tag(tag_name, this)

      # A theme paints the whole document -- `<html>`, `<head>`, the lot -- so
      # wrapping it in the application layout as well gives a page with two of
      # everything. Without a theme what comes back is a fragment, and then the
      # layout is exactly what it needs.
      whole_document = painted.lstrip.start_with?("<!DOCTYPE", "<html")

      render :html => painted.html_safe, :layout => !whole_document
    end

    def template_exists_for_this_action?
      lookup_context.exists?(action_name, lookup_context.prefixes, false)
    end

    def derived_tag?(tag_name)
      defined?(Rapid) && Rapid.polymorphic?(tag_name, this)
    end


    # `render :object => record` sets the context the templates render against.
    # It was an alias_method_chain; a prepended module composes with the rest of
    # Rails' own render chain instead of renaming it.
    module HoboModelRender
      def render(*args, &block)
        options = args.extract_options!
        self.this = options[:object] if options[:object]
        super(*args, options, &block)
      end
    end

    # --- filters --- #

    def set_no_cache_headers
      headers["Pragma"] = "no-cache"
      #headers["Cache-Control"] = ["must-revalidate", "no-cache", "no-store"]
      #headers["Cache-Control"] = "no-cache"
      headers["Cache-Control"] = "no-store"
      headers["Expires"] ='0'
    end

    # Rails 8's `resume_session` is private and idempotent (`Current.session
    # ||=`), so calling it costs one query per request at most and never
    # redirects: that is `require_authentication`'s job, and Hobo does not want
    # it. An application without the generator's concern simply has no such
    # method, and this does nothing.
    def resume_session_if_any
      send(:resume_session) if respond_to?(:resume_session, true)
    rescue StandardError
      nil
    end

    # --- end filters --- #

    public

    def model
      self.class.model
    end

  end
  end
end
