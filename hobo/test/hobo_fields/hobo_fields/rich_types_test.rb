require "test_helper"

# Ported from test/rich_types.rdoctest.
class RichTypesTest < Minitest::Test

  Types = HoboFields::Types

  # --- Defining your own rich type -----------------------------------------

  class LoudText < String
    COLUMN_TYPE = :string

    def validate
      "is too long (you shouldn't shout that much)" if length > 100
    end

    # Must be idempotent: format.format has to equal format.
    def format
      self =~ /!!!$/ ? self + "!!!" : self
    end

    def to_html(xmldoctype = true)
      upcase
    end
  end

  def test_a_custom_type_only_has_to_define_column_type_and_register_itself
    assert_equal :string, LoudText::COLUMN_TYPE
  end

  def test_a_custom_type_controls_its_own_rendering
    assert_equal "FOO<BAA", LoudText.new("foO<BAa").to_html
  end

  def test_a_custom_to_html_is_not_html_safe_unless_it_says_so
    refute LoudText.new("foO<BAa").to_html.html_safe?
  end

  def test_a_custom_validate_returns_the_message_or_nil
    assert_nil LoudText.new("quiet").validate
    assert_equal "is too long (you shouldn't shout that much)",
                 LoudText.new("x" * 101).validate
  end

  def test_format_has_to_be_idempotent
    shout = LoudText.new("hey")
    assert_equal shout.format, LoudText.new(shout.format).format
  end

  # --- EmailAddress ---------------------------------------------------------

  def test_email_address_accepts_a_well_formed_address
    good = Types::EmailAddress.new("foo@baa.com")

    assert good.valid?
    assert_nil good.validate
  end

  def test_email_address_rejects_a_malformed_address
    bad = Types::EmailAddress.new("foo.baa.com")

    refute bad.valid?
    assert_equal "is invalid", bad.validate
  end

  def test_email_address_obfuscates_and_escapes_when_rendered
    nasty = Types::EmailAddress.new("foo<nasty>&lt;nasty&gt;@baa.com")

    assert_equal "foo&lt;nasty&gt;&amp;lt;nasty&amp;gt; at baa dot com", nasty.to_html
    assert nasty.to_html.html_safe?
  end

  # --- HtmlString -----------------------------------------------------------

  def test_html_string_is_rendered_as_is_and_marked_safe
    nasty = Types::HtmlString.new("p1<p>p2</p>p3<nasty>p4</nasty>p5&lt;script&gt;p6")

    assert_equal "p1<p>p2</p>p3<nasty>p4</nasty>p5&lt;script&gt;p6", nasty.to_html
    assert nasty.to_html.html_safe?
  end

  # --- Text -----------------------------------------------------------------

  def test_text_escapes_and_turns_newlines_into_breaks
    text = Types::Text.new("Tom & Jerry\nCat & Mouse")

    assert_equal "Tom &amp; Jerry<br />\nCat &amp; Mouse", text.to_html
    assert text.to_html.html_safe?
  end

  def test_text_escapes_markup
    assert_equal "&lt;/div&gt;&gt;&gt;p1&lt;script&gt;p2",
                 Types::Text.new("</div>>>p1<script>p2").to_html
  end

  def test_text_column_type_is_text
    assert_equal :text, Types::Text::COLUMN_TYPE
  end

  # --- PasswordString -------------------------------------------------------

  def test_password_string_never_renders_its_value
    password = Types::PasswordString.new("pass<word>")

    assert_equal "[password hidden]", password.to_html
    assert password.to_html.html_safe?
  end

  # --- MarkdownString and TextileString -------------------------------------

  def test_markdown_string_renders_and_sanitises
    skip "kramdown is not installed" unless gem_available?("kramdown")
    require "hobo_fields/types/markdown_string"

    markdown = Types::MarkdownString.new("# This is a heading\n\nAnd text can be *emphasised*")

    assert_equal "<h1>This is a heading</h1>\n\n<p>And text can be <em>emphasised</em></p>",
                 markdown.to_html.strip
    assert markdown.to_html.html_safe?
  end

  def test_markdown_string_strips_scripts
    skip "kramdown is not installed" unless gem_available?("kramdown")
    require "hobo_fields/types/markdown_string"

    assert_equal "<p>&lt;/div&gt;p1p2</p>\n",
                 Types::MarkdownString.new("</div>p1<script>p2").to_html
  end

  def test_textile_string_renders_and_sanitises
    skip "RedCloth is not installed" unless gem_available?("redcloth")

    textile = Types::TextileString.new("Text can be _emphasised_")

    assert_equal "<p>Text can be <em>emphasised</em></p>", textile.to_html
    assert textile.to_html.html_safe?
  end

  # --- EnumString -----------------------------------------------------------

  ArticleStatus = Types::EnumString.for('', :draft, :approved, :published)

  def test_enum_string_defines_a_constant_per_value
    assert_equal "draft", ArticleStatus::DRAFT
    assert_equal ArticleStatus, ArticleStatus::DRAFT.class
  end

  def test_enum_string_answers_is_value_p
    approved = ArticleStatus::APPROVED

    refute approved.is_draft?
    assert approved.is_approved?
  end

  def test_enum_string_can_be_built_from_a_string
    assert ArticleStatus.new("approved").is_approved?
  end

  def test_enum_string_compares_equal_to_both_string_and_symbol
    approved = ArticleStatus.new("approved")

    assert_equal approved, "approved"
    assert approved == :approved
  end

  def test_enum_string_is_an_enum_string
    assert ArticleStatus.new("approved").is_a?(Types::EnumString)
  end

  def test_enum_string_validates_against_its_values
    assert_nil ArticleStatus.new("approved").validate
    assert_equal "must be one of '', draft, approved, published",
                 ArticleStatus.new("junked").validate
  end

  private

  def gem_available?(name)
    require name
    true
  rescue LoadError
    false
  end

end
