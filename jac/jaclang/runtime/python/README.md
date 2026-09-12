# Python compiler replacement

The retained JacPython code targets Python source compilation. CPython remains
the execution engine, object runtime and standard library.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python tokens, tokenizer, PEG parser, AST, validation and symbol tables |
| `jac/jaclang/compiler/backends/py/jacpython/` | Python bytecode generation, control flow and assembly |
| `jac/jaclang/runtime/python/` | Compiler values and code objects, opcode metadata and the symbol-table adapter |

Imports use the `jaclang` package paths; no `JACPATH` setting is required.
These are development implementations. They ship as source and are excluded
from the compiler bootstrap and sealed release runtime. Releases still build
CPython's C sources through `jac/bootstrap/python/`.

`product_compile.jac` connects the frontend and backend and produces the
`PyCode` representation in `objects.jac`. `code_object.jac` converts that result,
including nested code, constants, locations and exception tables, into CPython
3.14 code objects. Its `compile_python` development API accepts source or an AST
in `exec`, `eval` and `single` modes, and can return an AST with `PyCF_ONLY_AST`.
`codegen_shim.compile_ir(..., python_compiler=compile_python)` routes Jac's generated
AST and inline Python source splices through the replacement during development.
The default release path still uses CPython's compiler.

For a warm development loop, use the checkout's Jac binary:

```sh
jac -c 'from jaclang.compiler.backends.py.jacpython.code_object import compile_python; exec(compile_python("print(6 * 7)", "example.py", "exec"))'
```

These source-only modules have ordinary source/interface cache dependencies.
Editing one no longer changes the global producing-compiler generation. Active
compiler edits still invalidate that generation; source-only exclusions must be
removed when the replacement becomes part of the running compiler.

The compiler directly depends on
`objects.jac` and `opcode_meta.jac`; their shared support is retained while
compiler-specific values and helpers are separated from interpreter behavior.
`symtable.jac` is a starting point for the public symbol-table interface and
still needs adaptation to CPython's result objects.

The Jac interpreter, standard-library replacements, guest import machinery and
host-compiler subprocess bridge have been removed. The source-built CPython now
includes an opt-in C adapter in `bootstrap/python/compiler-bridge.patch`.
After loading the Jac compiler, setting `sys._jacpython_compile = compile_python`
routes built-in source/AST compilation, `eval`, `exec`, source imports and the
C string/file compilation APIs through it. Adapter errors propagate to callers;
covered entry points do not retry with the C compiler. Removing the callback
restores the default compiler. This development switch requires the source
checkout; replacement sources are still excluded from the sealed runtime.

Interactive C entry points, internal AST compilation and cold bootstrap loading
still need integration. The adapter preserves CPython's execution engine and
does not remove its C compiler from the build.
The development API does not yet implement the complete compile-flag, future,
diagnostic and syntax contracts. No CPython source allowlist entries have been
retired by this bridge.

The AST, token model, PEG parser and opcode metadata were originally generated
from CPython 3.14.6 and are now maintained directly in Jac. Their generators and
reference-checkout helper have been removed. When updating Python compatibility,
review these files against the corresponding upstream definitions, especially
opcode values, inline-cache widths and stack effects.

Release builds continue to download checksum-pinned CPython sources through
`jac/bootstrap/python/`; they do not use the optional local `reference/cpython`
checkout.

Bundled JacPython test suites and fixtures have been removed. The `jacpython` CI
job fetches the checksum-pinned upstream CPython tests and runs a focused subset
through both the explicit compile API and the patched C runtime (`--runtime`).
`jac run scripts/run_cpython_compiler_tests.jac` runs the
whole `TestSpecifics` class when invoked without `--tests`; compatibility gaps
remain in that broader suite. Tests with no replacement calls are reported as
skipped. Test definitions load before runtime dispatch is enabled. The direct
path also retains CPython for reference ASTs; the runtime path routes those AST
requests through JacPython. Neither lane proves cold bootstrap or full language
compatibility. Jac's own compiler and runtime regression suites remain.

[`LICENSE.cpython`](LICENSE.cpython) applies to CPython-derived code and generated
sources across these packages. File headers identify their upstream origins.
