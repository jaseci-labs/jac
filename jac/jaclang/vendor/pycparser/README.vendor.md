# Vendored: pycparser 3.00

Vendored into jaclang so that `pip install jaclang` carries **no** third-party
runtime dependency for the c2jac C front-end. pycparser 3.0 is pure-Python with
no transitive deps (it dropped PLY — the lexer/parser are hand-written), which
makes it cleanly vendorable.

- Upstream: https://github.com/eli-bendersky/pycparser (BSD-3-Clause, see `LICENSE`)
- Version: 3.00
- Imported in-tree as `jaclang.vendor.pycparser` (NOT bare `pycparser`) so it
  never double-loads against a stray site-packages copy — c2jac relies on
  `isinstance` against `c_ast` node types, which breaks across duplicate module
  identities.

## Do not edit these files
Keep this copy byte-for-byte upstream. All c2jac-specific behavior lives outside
this directory. To re-vendor a newer release:

```
pip download --no-deps --no-binary :all: 'pycparser==<ver>'   # or copy from a venv
cp <pycparser>/*.py <pycparser>/_c_ast.cfg jac/jaclang/vendor/pycparser/
cp <pycparser>/LICENSE jac/jaclang/vendor/pycparser/LICENSE
```

Then bump the version above. `_ast_gen.py` / `_c_ast.cfg` / `c_generator.py` are
not used at runtime (codegen/regeneration tooling) but are kept so re-vendoring
is a clean directory copy.

Note: the C preprocessor (`pcpp`) remains a declared dependency in `jac.toml`.
