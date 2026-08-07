require "test_helper"

# Ported from test/hobosupport/xss.rdoctest.
class XssTest < Minitest::Test

  def test_safe_join_escapes_unsafe_elements
    assert_equal "&lt;a&gt;&lt;b&gt;", ["<a>", "<b>"].safe_join
    assert ["<a>", "<b>"].safe_join.html_safe?
  end

  def test_safe_join_keeps_safe_elements_as_they_are
    assert_equal "<a>&lt;b&gt;", ["<a>".html_safe, "<b>"].safe_join
    assert ["<a>".html_safe, "<b>"].safe_join.html_safe?
  end

  def test_safe_join_of_only_safe_elements
    assert_equal "<a><b>", ["<a>".html_safe, "<b>".html_safe].safe_join
    assert ["<a>".html_safe, "<b>".html_safe].safe_join.html_safe?
  end

  def test_safe_join_escapes_an_unsafe_separator
    assert_equal "&lt;a&gt;&lt;br&gt;&lt;b&gt;", ["<a>", "<b>"].safe_join("<br>")
    assert ["<a>", "<b>"].safe_join("<br>").html_safe?
  end

  def test_safe_join_escapes_the_separator_even_between_safe_elements
    assert_equal "<a>&lt;br&gt;<b>", ["<a>".html_safe, "<b>".html_safe].safe_join("<br>")
  end

  def test_safe_join_keeps_a_safe_separator
    assert_equal "<a><br><b>", ["<a>".html_safe, "<b>".html_safe].safe_join("<br>".html_safe)
  end

end
