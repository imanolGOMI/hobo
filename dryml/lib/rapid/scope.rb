module Rapid

  # A scope is a stack of variables that inner tags can read -- DRYML's
  # <set-scoped>. Read as `scope.field_name`.
  class Scope
    def initialize(vars = {}) = @vars = vars
    def merge(more) = Scope.new(@vars.merge(more))
    def [](name) = @vars[name]
    def respond_to_missing?(name, priv = false) = @vars.key?(name) || super
    def method_missing(name, *args)
      @vars.key?(name) ? @vars[name] : super
    end
  end

end
