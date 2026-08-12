ActiveRecord::Base.class_eval do
  def self.hobo_model
    include Hobo::Model
    fields(false) # force hobo_fields to load
  end
  def self.hobo_user_model
    include Hobo::Model
    include Hobo::Model::UserBase
  end
  alias_method :has_hobo_method?, :respond_to_without_attributes?

  # `attr_accessible` y `attr_protected`, que **no hacen nada**.
  #
  # Son de Rails, no de Hobo, y murieron en Rails 4: decían qué columnas se
  # podían asignar en masa, y hoy eso se dice con strong parameters -- o, en una
  # aplicación de Hobo, con los permisos del modelo, que es donde estaba la
  # respuesta desde el principio.
  #
  # Están aquí porque **una aplicación de Hobo 2 no arranca sin ellos**: al
  # portar Amenti -- 30 modelos escritos en 2012 -- lo único que Hobo 3 no
  # entendía eran estas siete líneas. Aceptarlas convierte la migración de los
  # modelos en cero trabajo.
  #
  # Y avisando, no en silencio, porque **la superficie cambia**: un modelo con
  # `attr_accessible :name` solo dejaba asignar `name` en masa, y ahora deja
  # asignar lo que el permiso permita. Es más de lo que había, y quien migra
  # tiene que mirarlo. El aviso sale una vez por modelo, con el fichero.
  def self.attr_accessible(*names)
    Hobo.warn_about_mass_assignment(self, "attr_accessible", names)
  end

  def self.attr_protected(*names)
    Hobo.warn_about_mass_assignment(self, "attr_protected", names)
  end

  # `has_attached_file`: Paperclip, que se dejó de mantener en 2018 y cuyo
  # relevo es ActiveStorage, dentro de Rails.
  #
  # Aquí **no** es una línea muerta como `attr_accessible`: es una función que
  # la gente usa. Se acepta para que la aplicación arranque y se pueda ver el
  # resto, y el aviso dice lo que hay que decir: **los adjuntos no funcionan**
  # hasta convertirlos. Convertirlos es trabajo de `hobo update`, que pregunta
  # antes de tocar nada.
  def self.has_attached_file(name, *_options)
    Hobo.warn_about_paperclip(self, name)
  end

  # Y su validación, que viaja siempre con él.
  def self.validates_attachment_content_type(*_args) = nil
  def self.validates_attachment_size(*_args) = nil
  def self.validates_attachment_presence(*_args) = nil
end
