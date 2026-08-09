# hobo_timeago

Las fechas se pintan como «3 days ago», y se mantienen al día en el navegador.

```ruby
# Gemfile
gem "hobo_timeago"
```

Y ya está. Eso es todo lo que hay que hacer, y es lo que este plugin
**demuestra**: es el ejemplo con el que se escribió el contrato de plugin de
Hobo 3 (pieza 17 de `PLAN.md`).

## Qué es un plugin de Hobo 3

Una gema con tres cosas, ninguna de ellas una API de Hobo:

1. **Un engine de Rails** (`lib/hobo_timeago/engine.rb`), que mete los assets de
   la gema en el pipeline y su `config/importmap.rb` en el import map de la
   aplicación. Son los dos mismos initializers que lleva el engine de Hobo.
2. **Un fichero que define tags** (`lib/hobo_timeago/tags.rb`), requerido desde
   el fichero principal de la gema.
3. **Sus assets** en `app/assets` y `app/javascript`, donde Rails los busca.

Instalarlo es `bundle add hobo_timeago`. No hay generador, ni `<include
gem="..."/>` en un taglib, ni `//= require` en el JavaScript, ni `*= require` en
la hoja de estilos.

En Hobo 2 hacían falta esas cuatro cosas —y una vez por cada subsitio— porque un
tag de DRYML vivía en un fichero que alguien tenía que nombrar. **Un tag en Ruby
se registra al definirse**, y los ficheros de la gema se ejecutan cuando Bundler
la requiere, así que tres de las cuatro se quedaron sin nada que hacer.

## Redefinir un tag del catálogo

El catálogo ya define cómo se pinta una fecha. Este plugin lo reemplaza:

```ruby
Rapid.define_for(:view_content, Date) { ... }
```

El registro es una tabla global y gana la última definición, así que a partir de
ahí **todas** las fechas de la aplicación se pintan con esta, sin que ninguna
página nombre la gema. Eso es la razón de ser de los plugins y también su
peligro: nadie avisa. Por eso:

```
$ bin/rails hobo:tags
view_content                                hobo/lib/hobo_rapid/tags/views.rb
  for Date                        shadowed  hobo/lib/hobo_rapid/tags/views.rb
  for Date                                  hobo_timeago/lib/hobo_timeago/tags.rb

33 tags, 47 definitions, 2 shadowed -- hobo, hobo_timeago
```

`shadowed` es una definición que sigue en el registro y ya no pinta nada. Cuando
se fundieron las gemas de este repositorio, cinco tags de un banco de pruebas
llevaban semanas tapando a cinco del catálogo de verdad, y quien lo vio fue una
persona mirando una captura de pantalla. Esa lista existe para que la próxima vez
lo vea la lista.

Si lo que quieres es **añadir** algo a un tag en vez de sustituirlo, extiéndelo:
`Rapid.extend_tag(:page) { ... old ... }`. Dos gemas pueden extender el mismo tag
y las dos se ejecutan; dos que lo definan, no.

## Las pruebas

```
cd hobo_timeago && rake test
```

No hay `Gemfile` ni `bundle install`: la suite carga `hobo` de `../hobo/lib` y
nada más. Un plugin que solo se puede probar dentro de una aplicación de Rails es
un plugin que nadie prueba.

La otra mitad de la prueba está en la gema: `hobo/test/integration/plugin_contract_test.rb`
arranca **la misma** aplicación con la gema y sin ella. «Y nada más» no se
comprueba mirando lo que pasa, sino lo que deja de pasar.
