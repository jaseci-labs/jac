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

## What is kept
This copy is upstream byte-for-byte **except** that the offline codegen tooling
(`_ast_gen.py`, `_c_ast.cfg`, `c_generator.py`) is dropped — it regenerates
`c_ast.py` / emits C from an AST and is never used at runtime (c2jac only
*parses*). The `utils/fake_libc_include/` stub headers **are** vendored (they are
omitted from the pip wheel, the [#6973] gap that broke the default system-include
path); `cfront/preprocess.jac` adds this dir to the include path unless
`-nostdinc`.

## Re-vendoring a newer release
```
pip download --no-deps --no-binary :all: 'pycparser==<ver>'   # sdist, NOT the wheel
# from the extracted sdist:
cp <pycparser>/pycparser/*.py jac/jaclang/vendor/pycparser/
cp -r <pycparser>/utils/fake_libc_include jac/jaclang/vendor/pycparser/utils/
cp <pycparser>/LICENSE jac/jaclang/vendor/pycparser/LICENSE
rm jac/jaclang/vendor/pycparser/{_ast_gen.py,_c_ast.cfg,c_generator.py}   # codegen-only
```

Then bump the version above. Use the **sdist**, not the wheel — the wheel omits
`utils/fake_libc_include/`.

Note: the C preprocessor (`pcpp`) is likewise vendored, at
`jaclang/vendor/pcpp` — the c2jac front-end now has zero third-party deps.
