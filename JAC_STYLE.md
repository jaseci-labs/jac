## Jac code style (repo-wide)

This repo treats the output of the Jac formatter + auto-lint as the canonical style.
The `jac-byllm` Jac sources are a good reference for the intended organization and
readability.

### What “canonical” means

- Run the formatter (`jac format`) and keep files in formatted form.
- Prefer `glob` declarations for module-level constants and type aliases.
- Prefer `static`/`can init`/`can postinit` Jac idioms over Pythonisms.
- Keep related fields together by combining consecutive `has` and `glob` blocks.
- Keep module-level side effects limited and explicit (use `with entry` only when
  code must run at import time).
- Use module/class docstrings to explain intent when the module isn’t self-evident.

### How to format in this repo

If you have the `jac` CLI installed:

- `jac format --fix <paths...>`

From a fresh checkout (no install), use the helper script:

- `python3 scripts/format_jac.py --fix`
- `python3 scripts/format_jac.py --check`

The script formats the main Jac “source” trees (excluding `tests/` and `fixtures/`)
so we don’t rewrite parser/fixture inputs unintentionally.
