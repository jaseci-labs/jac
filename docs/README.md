# Contributing to Documentation @ docs.jaseci.org

This directory holds the documentation site for Jac and the Jaseci stack, built with MkDocs (Material theme) and served at <https://docs.jaseci.org>. It also contains the `jac-highlighter` package: a Pygments lexer that gives ```` ```jac ```` fences real syntax highlighting.

## Layout

- `mkdocs.yml` -- site config and the single nav tree (Start Here · Learn · Reference · Community · Internals)
- `docs/` -- all page sources (markdown), plus the static landing page (`docs/index.html`), `llms.txt`, and assets
- `overrides/` -- Material theme partials (header, footer)
- `scripts/` -- the build hook (`handle_jac_compile_data.py`), the code-block validator (`validate_docs_code.jac`), and the container server (`mkdocs_serve.py`)
- `tests/` -- docs tests, including the Playwright e2e test for interactive code blocks

To add a page: create the markdown file under `docs/` and add it to the `nav:` section of `mkdocs.yml`. `mkdocs build --strict` fails on broken links and anchors, so run a build before pushing.

## Local preview

The docs tooling installs into the `jac` binary's environment via the manifest in `jac.toml`:

```bash
cd docs
jac install
jac -m mkdocs serve
```

Then open <http://127.0.0.1:8000>.

## Validation

Run these from the repo root before pushing (CI runs them too):

```bash
jac run docs/scripts/validate_docs_code.jac   # every ```jac fence must parse
cd docs && jac -m mkdocs build --strict       # links and anchors must resolve
cd docs && jac test tests/test_docs.jac       # docs invariants
```

Code blocks in pages are validated for syntax; add `<!-- jac-skip -->` immediately above a fence only when a fragment genuinely cannot parse standalone.

## Conventions

- The conceptual framework and vocabulary follow the canonical concept pages under `docs/quick-guide/` (Why Jac, The Two Ideas, Core Concepts, Vocabulary). Coined terms are defined once on their canonical page and repeated verbatim elsewhere; link rather than redefine.
- Release notes are managed via fragment files in `docs/community/release_notes/unreleased/` (see the README there); never edit `release_notes/jaclang.md` directly.
