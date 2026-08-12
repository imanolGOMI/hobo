class Array

  def drop_while!
    drop = 0
    drop += 1 while yield(self[drop])
    self[0..drop-1] = []
    self
  end

end
