# Procedencia

Este directorio es una copia de un repositorio externo, traída aquí para poder
trabajarla dentro del monorepo. **No es un submódulo.**

| | |
|---|---|
| Origen | `https://github.com/Hobo/hobo_bootstrap_ui` |
| Commit | `2245ef444549fb2a0f0f8e7cd136d18cf1e2bcc3` |
| Fecha del commit | 2016-05-07 |
| Copiado el | 2026-08-07 |

No tenemos permiso de escritura sobre el repositorio de origen: los cambios se
quedan aquí.

## Qué contiene

350 líneas de DRYML en 7 taglibs. Es **la capa de widgets de jQuery** del tema:

| Taglib | Líneas | Sustituto en 2026 |
|---|---:|---|
| `modal.dryml` | 89 | `<dialog>` nativo |
| `name_one_bootstrap.dryml` | 71 | Stimulus |
| `select_one_or_new.dryml` | 60 | `<datalist>` o Stimulus |
| `bootstrap_datepicker.dryml` | 58 | `<input type="date">` |
| `typeahead.dryml` | 50 | `<datalist>` |
| `overrides.dryml` | 21 | — |

Es el paquete acotado que hay que traducir a HTML nativo y Stimulus.
