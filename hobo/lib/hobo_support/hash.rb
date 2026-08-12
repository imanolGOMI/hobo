class Hash

  # Splits the hash in two: the pairs whose key is in +keys+ (or for which the
  # block returns true) and the rest. Ruby's own Hash#partition returns arrays
  # of pairs rather than hashes, so there is no core equivalent.
  def partition_hash(keys=nil)
    yes = {}
    no = {}
    each do |k,v|
      if block_given? ? yield(k,v) : keys.include?(k)
        yes[k] = v
      else
        no[k] = v
      end
    end
    [yes, no]
  end

end


# HashWithIndifferentAccess needs its keys normalised before they are compared.
if defined? HashWithIndifferentAccess

  class HashWithIndifferentAccess

    def partition_hash(keys=nil)
      keys = keys&.map {|k| k.is_a?(Symbol) ? k.to_s : k }
      yes = HashWithIndifferentAccess.new
      no = HashWithIndifferentAccess.new
      each do |k,v|
        if block_given? ? yield(k,v) : keys.include?(k)
          yes[k] = v
        else
          no[k] = v
        end
      end
      [yes, no]
    end

  end

end
