# Procedencia

Este directorio es una copia de un repositorio externo, traída aquí para poder
trabajarla dentro del monorepo. **No es un submódulo.**

| | |
|---|---|
| Origen | `https://github.com/Hobo/hobo_bootstrap` |
| Commit | `a1c2d44af8b6aea4c6c1909767921b5021730729` |
| Fecha del commit | 2016-09-01 |
| Copiado el | 2026-08-07 |

No tenemos permiso de escritura sobre el repositorio de origen: los cambios se
quedan aquí.

## Qué contiene

Bootstrap **2**, no 3 ni 5. Se ve en el markup: rejilla `span9`/`span12`,
`.navbar-inner`, `.btn-navbar`, `.icon-bar`, `.nav-collapse`, `.well`.

Hace tres cosas a la vez, y conviene no confundirlas:

- **11 `<extend>`** de tags de `hobo_rapid`: `page`, `form`, `index-page`,
  `show-page`, `edit-page`, `table-plus`, `page-nav`, `input-many`,
  `select-many`, `live-search`, `delete-button`.
- **26 `<def>` propios** que RAPID no tiene: `login-page`, `login-form`,
  `navigation`, `nav-item`, `account-nav`, `sub-nav`, `alert-box`,
  `flash-message`, `error-messages`, `transition-buttons`, `card`,
  `field-list`, `bootstrap-fields`, `with-fields-grouped`, `submit`,
  `dev-user-changer`… Esto **no es diseño, es funcionalidad**.
- **Assets**: `hobo_bootstrap.scss` (+ main y responsive) y `hobo_bootstrap.js`.

## El detalle importante

`taglibs/page.dryml` define `<page>` con **`<def>`, no con `<extend>`**. El
propio fichero lo dice: *"This file is necessary, it was mostly cloned from the
default Hobo theme"*.

Es decir: el tema **reimplementa** `<page>` entero y vuelve a declarar sus ~30
`param` copiados a mano. Nada comprueba que sigan en sincronía con los de RAPID.
Ese es el origen estructural de la pérdida silenciosa de parámetros descrita en
`HALLAZGOS.md`.
