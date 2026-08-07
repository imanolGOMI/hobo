require "test_helper"
require_relative "../prepare_testapp"

# What ActionView still has to be once Hobo is loaded.
#
# Hobo reopens a few of Rails' own classes (`hobo/extensions/`), and a patch
# that is right for Hobo and wrong for Rails does not break Hobo's pages -- it
# breaks *Rails'* pages, the ones the application renders itself: the session
# form, the password mails, anything a plain generator writes. Those are the
# pages no test of a Hobo tag will ever visit.
#
#   cd hobo && rake test:app
class ActionViewIntegrationTest < Minitest::Test

  def setup
    skip TestApp.why_not unless TestApp.built?
    TestApp.sweep
  end

  # `tag` with no arguments is the tag builder, and it is how every helper
  # written since Rails 5.1 emits markup -- importmap's `javascript_importmap_tags`
  # among them.
  #
  # Hobo used to reopen `tag` with the 2008 signature, `tag(name, options, open,
  # escape)` with the name required, so that DRYML could close elements the XHTML
  # way. The old compiler is gone and the patch stayed, and any page that used
  # the builder died with "wrong number of arguments (given 0, expected 1..4)".
  # A generated application showed it on `/session/new`, which is Rails' page,
  # not Hobo's.
  def test_the_tag_builder_still_builds_tags
    output = run_in_app(<<~RUBY)
      view = ActionController::Base.new.view_context
      puts view.tag.script("import 'app'", :type => "module")
      puts view.tag.br
    RUBY

    assert_includes output, %(<script type="module">import &#39;app&#39;</script>)
    assert_includes output, "<br>"
  end

  # And the positional form keeps working, because Rails' own helpers use it.
  # It is the legacy one, and it still closes the XHTML way -- which is the
  # whole reason Hobo's patch went unnoticed for so long: what it forced was
  # what this form already did.
  def test_the_positional_form_still_works
    output = run_in_app(%(puts ActionController::Base.new.view_context.tag("hr")))

    assert_includes output, "<hr />"
  end

  def run_in_app(script)
    file = File.join(TestApp::PATH, "tmp", "probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    `cd #{TestApp::PATH} && bin/rails runner #{file} 2>&1`
  ensure
    FileUtils.rm_f(file)
  end

end
