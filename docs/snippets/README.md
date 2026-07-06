# Shared doc snippets

Files here are included into pages via `--8<-- "snippets/<file>"` (pymdownx.snippets,
base path is the `docs/` directory where `mkdocs.yml` lives).

- `model-config.md` -- the canonical "recommended model" `jac.toml` block. Update the
  model id HERE (keep it in sync with the repo root `jac.toml`) instead of editing each
  page that shows a recommended model. Note: snippet includes are literal, so they only
  work at un-indented positions -- inside indented admonitions/tabs, inline the value
  instead and keep it matching this file.
