module Hobo

  module Controller

    # Whether Rails' layout wraps what this action paints.
    #
    # A Hobo page **is the whole document**: `<page>` writes the `<!DOCTYPE>`,
    # the `<html>`, the head and the body. Wrapping that in
    # `layouts/application.html.erb` gives two documents nested inside each
    # other -- two `<head>`, and therefore two import maps, Stimulus registered
    # twice and a form's `+` adding two rows.
    #
    # `Hobo::Controller::Model` has said `layout false` for a while, which
    # covers the controllers Hobo generates. It does not cover the ones an
    # application writes itself -- amenti's `FrontController` is a plain
    # `ApplicationController` -- and those are exactly the ones that paint the
    # front page. Bringing that application across put its templates back
    # **and** Rails' layout back, and the front page came out as a document
    # inside a document.
    #
    # So the question is asked of the template rather than of the controller:
    # a `.dryml` page brings its own document, an `.html.erb` view does not and
    # still wants the layout. That is what keeps Rails' own session and password
    # pages looking like the rest of the application in an updated app.
    module Layout

      def self.included(base)
        base.class_eval { layout :hobo_layout }
      end

      private

      def hobo_layout
        return nil unless Hobo.pages_are_whole_documents?

        template = lookup_context.find_all(action_name, lookup_context.prefixes).first
        template && template.identifier.to_s.end_with?(".dryml") ? false : nil
      rescue StandardError
        nil
      end

    end

  end

end
