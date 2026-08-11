# Hobo 2's `application.dryml`: where an application says, for all of itself at
# once, how it wants its things painted.
#
#   <%# app/views/taglibs/application.html.erb %>
#
#   <% define :card, :for => Book do %>
#     <div class="card">
#       <h4><%= link_to this.title, book_path(this) %></h4>
#       <p><%= this.author&.name %></p>
#     </div>
#   <% end %>
#
#   <% extend_tag :index_page do %>
#     <% append_heading " · #{this.count} in total" %>
#     <%= old %>
#   <% end %>
#
# A template, not a file of code: what goes inside is markup with ERB (or Slim,
# or whatever the application uses), like any other view. `define` says how
# something is painted, `extend_tag` retouches what is painted already, `old` is
# what was painted before -- DRYML's `<old-index-page/>` -- and `this` is the
# record being painted right now.
#
# ## How a block of ERB can be painted later
#
# A block of ERB writes into the buffer of **its own** view, the one that
# compiled the template. Keeping it and calling it from another request sends
# the markup to the wrong buffer, and loose text comes out in the middle of
# another page -- which is what happens, not a guess.
#
# So the taglib keeps its own view and captures on that. The record does not
# travel with the block: it travels through `Rapid::Context`, which is where the
# tag runtime puts it, and that is why the same block paints a different book
# every time it is called.
#
# ## When it is loaded
#
# After deriving, and it cannot be before: deriving defines `index_page` for
# every model, so an `extend_tag :index_page` loaded earlier would extend a tag
# that is replaced an instant later. Both go in the same `to_prepare`
# (hobo/engine.rb) so the order does not depend on the order Rails happens to
# run two blocks in.

require "rapid"

module HoboRapid

  module Taglib

    # What may be written in a taglib. It goes into the whole view context and
    # not only the taglib's: a plain view that wants to define a tag for its own
    # page can, and there is no second kind of template to learn.
    module DSL

      # `<def tag="card" for="Book">`. Without `:for`, the tag for everybody.
      def define(name, options = {}, &block)
        body = HoboRapid::Taglib.body_of(self, &block)
        target = options[:for]

        if target
          Rapid.define_for(name, HoboRapid::Taglib.type_for(target), &body)
        else
          Rapid.define(name, :attrs => Array(options[:attrs]), &body)
        end
        nil
      end

      # `<extend tag="index-page">`. Inside, `old` is what was painted before,
      # and the param verbs (`append_heading`, `param`, `without`...) go to that
      # tag's params.
      def extend_tag(name, options = {}, &block)
        view = self
        target = options[:for]

        extension = Module.new do
          define_method(:content) do
            previous = -> { super() }
            raw HoboRapid::Taglib.painting(self, previous) { view.capture(&block) }
          end
        end

        Rapid.extend_tag(name, target && HoboRapid::Taglib.type_for(target), :with => extension)
        nil
      end

      # `<old-index-page/>`: what the tag painted before it was extended.
      # Outside an `extend_tag` there is nothing before, and this answers empty
      # rather than raising -- a half-written taglib should not take the
      # application down.
      def old
        HoboRapid::Taglib.old_content
      end

      # The record being painted. This is DRYML's `this`, and it is what makes
      # one block paint a different book every time.
      def this = Rapid::Context.this

    end


    class << self

      # What a tag is for. A class is itself; a symbol is a field type
      # (`:email_address`, `:markdown`), which is how `for="email-address"` was
      # written.
      def type_for(target)
        return target if target.is_a?(Module)
        klass = HoboFields.to_class(target) if defined?(HoboFields)
        return klass if klass
        raise ArgumentError, "`for: #{target.inspect}` names neither a class nor a field type"
      end

      # The body of a `define`: a block that runs as a tag's `content`, and that
      # captures the markup on the taglib's view from the inside.
      def body_of(view, &block)
        proc { raw view.capture(&block) }
      end

      # --- what a taglib block can see while it paints -----------------------
      #
      # Two things travel through here instead of through arguments: what the
      # tag painted before (`old`), and where the params the block declares
      # should go. Neither can be passed to the block, because the application
      # wrote the block and should not have to take anything.

      def painting(tag, previous)
        outer = Thread.current[:hobo_taglib_frame]
        Thread.current[:hobo_taglib_frame] = { :tag => tag, :old => previous }
        yield
      ensure
        Thread.current[:hobo_taglib_frame] = outer
      end

      def frame = Thread.current[:hobo_taglib_frame]

      # Where the params a taglib block declares go: to the params of the tag
      # being extended. Outside a taglib there is no frame, and the verbs keep
      # going to the controller, which is what a plain view does.
      def declared_params = frame && frame[:tag].params

      def old_content
        return "".html_safe unless frame
        Rapid::Context.capture { frame[:old].call }.to_s.html_safe
      end

      # --- loading -----------------------------------------------------------

      # `app/views/taglibs/application.*`, in whatever format the application
      # uses. Painted once, and its view stays alive because the blocks it kept
      # capture on it.
      def load_all(root = nil)
        return [] unless defined?(::ApplicationController)
        return [] if names(root).empty?

        controller = ::ApplicationController.new
        controller.request = ActionDispatch::TestRequest.create
        controller.response = ActionDispatch::TestResponse.new

        names(root).each { |name| controller.render_to_string("taglibs/#{name}", :layout => false) }
      end

      # Which taglibs there are. `application` first by convention, and the rest
      # alphabetically so that two which overlap always overlap the same way.
      #
      # Only what ActionView can render. An application coming from Hobo 2 has
      # its old `application.dryml` sitting in this very directory, and asking
      # Rails for a template it has no handler for does not answer "no such
      # taglib" -- it raises `MissingTemplate` and the application does not
      # boot. The old files are left alone: converting them is the updater's
      # job, and until then they are only files.
      def names(root = nil)
        directory = Pathname.new(root || Rails.root).join("app", "views", "taglibs")
        return [] unless directory.directory?

        handlers = ActionView::Template::Handlers.extensions.map(&:to_s)
        found = Dir[directory.join("*.*")].filter_map do |file|
          name, *rest = File.basename(file).split(".")
          name if rest.any? { |extension| handlers.include?(extension) }
        end

        found.uniq.sort.partition { |name| name == "application" }.flatten
      end

    end

  end

end

if defined?(ActiveSupport)
  ActiveSupport.on_load(:action_view) { include HoboRapid::Taglib::DSL }
end
