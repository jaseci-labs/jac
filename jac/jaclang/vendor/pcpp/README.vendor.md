# Vendored: pcpp 1.30

The pure-Python C preprocessor for the c2jac / cbindgen front-end, vendored so
that `pip install jaclang` carries **no** third-party runtime dependency (it was
previously a declared `pcpp>=1.30` dep in `jac.toml` and a pip-install in
`launcher/payload.zig` — both removed once this copy landed).

- Upstream: https://github.com/ned14/pcpp (BSD-2-Clause, see `LICENSE.txt`)
- Version: 1.30
- Imported in-tree as `jaclang.vendor.pcpp` (NOT bare `pcpp`) so it never
  double-loads against a stray site-packages copy — c2jac catches pcpp's
  `OutputDirective` exception, which only works under a single module identity.

## Local modifications
Upstream uses **absolute** intra-package imports (`from pcpp.parser import ...`),
which only resolve when the package lives at the top level of `sys.path`. Under
`jaclang.vendor.pcpp` there is no top-level `pcpp`, so those were rewritten to
**relative** imports:

- `preprocessor.py`: `from pcpp.parser` / `from pcpp.evaluator` -> `from .parser` / `from .evaluator`
- `evaluator.py`: `from pcpp.parser` -> `from .parser`
- `pcmd.py`: `from pcpp.preprocessor` -> `from .preprocessor`

The bundled PLY (`pcpp/ply/ply/`) and its location-relative `sys.path` shim in
`parser.py` (`from ply import lex, yacc`) are unchanged — that shim keys off
`__file__`, so it keeps working wherever the package is vendored.

## Re-vendoring a newer release
```
pip download --no-deps --no-binary :all: 'pcpp==<ver>'   # or copy from a venv
cp -r <pcpp>/pcpp/* jac/jaclang/vendor/pcpp/
cp <pcpp>/LICENSE.txt jac/jaclang/vendor/pcpp/LICENSE.txt
```
Then re-apply the absolute->relative import rewrites above and bump the version.
