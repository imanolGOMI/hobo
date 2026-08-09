require "test_helper"

# What Hobo must **not** do to String.
#
# `hobo_support/string.rb` used to reopen String with five methods, and two of
# them had names ActiveSupport had taken in the years since:
#
#   safe_constantize  ActiveSupport's answers nil for any constant that is not
#                     there. Hobo's raised unless the missing name was exactly
#                     the whole string -- and ActiveRecord asks it about
#                     candidates it *expects* to be missing (`compute_type`
#                     tries "Dj::ActiveStorage::Attachment" before
#                     "ActiveStorage::Attachment"). So adding the gem to an
#                     application broke every page that touched an attachment,
#                     a polymorphic association or an STI class.
#
#   remove            ActiveSupport's removes every occurrence; Hobo's removed
#                     the first. Same name, same arguments, different answer,
#                     no error anywhere: the kind of thing that shows up as a
#                     wrong string three layers away.
#
# The file is gone. This is here so that nothing brings it back, and because a
# monkeypatch on a core class is exactly the shape of thing that gets re-added
# by somebody who needs one method and does not know what else is in the file.
class StringExtensionsTest < Minitest::Test

  # The one that broke real applications. It has to answer nil, not raise.
  def test_safe_constantize_is_activesupports
    assert_nil "NoSuchConstantAnywhere".safe_constantize
    assert_nil "String::NoSuchThing".safe_constantize
    assert_equal String, "String".safe_constantize
  end

  # This is the shape ActiveRecord asks about: the nested candidate first, and
  # it has to come back nil so the plain one gets its turn.
  def test_a_nested_candidate_that_does_not_exist_is_simply_nil
    assert_nil "Integer::Comparable".safe_constantize
    assert_equal Comparable, "Comparable".safe_constantize
  end

  def test_remove_removes_every_occurrence
    assert_equal "bc", "abca".remove("a")
  end

  def test_hobo_does_not_add_methods_of_its_own_to_string
    refute_respond_to "x", :remove_all
    refute_respond_to "x", :remove_all!
  end

end
