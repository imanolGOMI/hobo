module Enumerable

  # Returns the first true value returned by the block, short-circuiting as
  # soon as it finds one, or +not_found+ if the block never returns a value.
  def map_and_find(not_found=nil)
    each do |x|
      val = yield(x)
      return val if val
    end
    not_found
  end

end


class Object

  # Unlike ActiveSupport's, these treat nil as an empty enumeration instead of
  # raising ArgumentError. And ActiveSupport has no not_in? at all.
  def in?(enum)
    !enum.nil? && enum.include?(self)
  end

  def not_in?(enum)
    enum.nil? || !enum.include?(self)
  end

end
