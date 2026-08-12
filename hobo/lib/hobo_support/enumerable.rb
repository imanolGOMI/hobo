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

  # `contactos.*.nif` -- pedirle lo mismo a todos.
  #
  # Es de Hobo 2, y una aplicacion de aquella epoca lo escribe en cualquier
  # sitio: `expediente.contactos.*.nif.include?(nif)` es una validacion de
  # amenti. Sin esto, `Array#*` sin argumento es un ArgumentError de Ruby y el
  # fallo sale con la firma de la multiplicacion -- «given 0, expected 1» --,
  # que no se parece en nada a lo que se estaba haciendo.
  #
  # Se restaura **solo el caso sin argumento**. `[1,2] * 3` y `%w[a b] * ","`
  # son Ruby y siguen siendo Ruby: lo que se llena es un hueco que hoy no vale
  # para nada, asi que ningun codigo que funcione hoy cambia de significado.
  # Redefinir un operador de Array a la ligera es de las cosas que mas caro se
  # pagan, y por eso se dice aqui de que tamano es el cambio.
  class MultiSender

    def initialize(enumerable, method)
      @enumerable = enumerable
      @method = method
    end

    def method_missing(name, *args, &block)
      @enumerable.send(@method) { |item| item.send(name, *args, &block) }
    end

    def respond_to_missing?(*) = true

  end

  # `.*.` mapea, `.where.` selecciona y `.where_not.` descarta.
  def *(other = nil)
    return MultiSender.new(self, :map) if other.nil?
    super
  end

  def where = MultiSender.new(self, :select)
  def where_not = MultiSender.new(self, :reject)

end

class Array

  # `Array` trae su propio `*` --el de Ruby-- y gana al del modulo, asi que hay
  # que decirlo tambien aqui. Con argumento, el de siempre.
  alias_method :hobo_multiply, :*

  def *(other = nil)
    return Enumerable::MultiSender.new(self, :map) if other.nil?
    hobo_multiply(other)
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
