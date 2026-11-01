# JacPython Migration

The migration this page tracked is complete. JacPython, the Python runtime
written in Jac and lowered to native code, is the only Python the `jac` binary
bundles and the only one its build uses. Nothing is translated from another
implementation's C at build time any more: the C that remains is HACL*'s
hashing code, the interpreter's `main`, and the third-party libraries the
runtime links (OpenSSL, zlib, sqlite, libffi and the rest).

Where the parts live now:

| Part | Where |
| --- | --- |
| The runtime: object model, evaluator, extension modules | `jaclang/runtime/python/` (see its `README.md`) |
| The build, without autoconf or make | `bootstrap/build_python.zig`, `bootstrap/build_jacpython.zig`, `bootstrap/pyconfig.zig` |
| The bootstrap seed a build runs on when it has no earlier runtime | `bootstrap/python/seed.json`, published by `.github/workflows/build-seeds.yml` |
| The vendored standard library and other Python sources | `bootstrap/python/src` (PSF license, `jaclang/runtime/python/LICENSE.cpython`) |
| The C API headers, generated from the Jac layouts | `bootstrap/python/generated/Include` (`scripts/jacpython/gen_include.jac`) |
| The instruction definitions, clinic signatures and AST description | `scripts/jacpython/` |
| The conformance suites the runtime is held to | `jac/tests/python_conformance`, run by `scripts/run_python_conformance.jac` |
