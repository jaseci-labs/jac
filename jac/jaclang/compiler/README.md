# The Jac compiler

This directory is the compiler: parsing, analysis, placement, and three code
generators. The pipeline, pass by pass, is documented in
[`cli/docs/internals/compiler_architecture.md`](../cli/docs/internals/compiler_architecture.md);
this file is the map of the tree and the rules that keep it organized.

## Layout

| Directory | Holds | Depends on |
|---|---|---|
| `frontend/` | Lexer, parser, the unified tree (`unitree`), roles and relations, source locations, diagnostics, per-node code info, and the module facts every later layer reads (`module_facts`, `const_fold`, `constant`) | nothing above it |
| `passes/` | Pass infrastructure (`transform`, `uni_pass`, `annex_weave`, `dataflow`) and the analysis passes: symbol tables, declaration matching, semantics, CFG, types, ownership, regions, capabilities, layout | `frontend`, `types` |
| `types/` | The type system and evaluator, compile-time values, the stub catalog, and the ambient `.pyi` surfaces | `frontend` |
| `placement/` | The placement solver: which module runs where, pins, workspaces | `frontend`, `passes` |
| `driver/` | `JacProgram`, `JacCompiler`, the schedules, module resolution, the caches (bytecode, interface, JIR), compile options | everything |
| `backends/common/` | What the generators share: the AST-gen base, the primitive emitter interfaces, the kernel unit lists, the format kernel | `frontend`, `passes` |
| `backends/py/` | Jac to JCIR to CPython bytecode | `backends/common` |
| `backends/es/` | Jac to ESTree to JavaScript, the client framework backends, view IR | `backends/common` |
| `backends/native/` | Jac to LLVM IR, the linkers (ELF, Mach-O, PE, wasm), the wasm runtime, and the in-tree LLVM binding (`llvm/`, a translation of llvmlite, see `llvm/LICENSE.llvmlite`) | `backends/common` |
| `tools/` | Formatter, linter, unparser, normalizer, doc IR, grammar extraction, code intelligence | `frontend`, `passes` |
| `tests/` | Cross-backend equivalence fixtures that ship with the package | |

The loose modules at this level are the native frontend kernel
(`jc_unit`, `jc_materialize`, `native_compiler`, `native_scope`: the parser
and its early analysis passes compiled natively and loaded as a shared library)
and registries shared by analysis and codegen (`symbol_utils`, `expr_keys`, `type_registry`,
`intrinsic_registry`).

## Native early analysis

When the driver knows a module's codespace before parsing, `jc_unit` runs the
existing `ASTValidationPass` and `SymTabBuildPass` after annex weaving, inside
the parse region. The tree and symbol graph cross into the host together.
Modules with wildcard imports defer symbol construction until the driver's
dependency resolver has made the imported names available. Parsing without a
compiler program, or without a known codespace, keeps the ordinary host schedule.

`PassResult` carries completed diagnostics and timing through the ordinary pass
driver, which applies diagnostic policy and records each pass once. Native field
and reference-container layouts come from the backend's ABI metadata;
`jc_materialize` preserves object identity when copying symbol indexes and edges.
Keep pass algorithms in `passes/`, and extend this shared boundary when another
pass moves into the kernel.

`scripts/native_compile_bench.jac` at the repository root measures uncached AOT
application builds with a warm compiler. Set `JAC_COMPILER_LIB` to each built
kernel when comparing revisions.

Measured on 2026-09-06 with `examples/chess/chess.jac`, Linux x86-64 on a
Threadripper 9980X: ten builds per kernel in two fresh-process batches, two
excluded warmups per batch, ordered baseline/new/new/baseline. Both kernels used
the same host compiler source; the baseline kernel predates native early passes.
Startup was excluded; application IR caching was disabled and linking included.

| Median | Parser-only kernel | Early-analysis kernel |
| --- | ---: | ---: |
| Full AOT build | 3.646 s | 3.537 s |
| AST validation (pass ledger) | 34.25 ms | 11.22 ms |
| Symbol construction (pass ledger) | 38.19 ms | 14.00 ms |
| Both passes combined (pass ledger) | 72.45 ms | 25.04 ms |

The observed total median improvement is 3.0%; the migrated passes are 2.9x
faster together. Total build ranges overlap (3.423–4.193 s baseline,
3.340–4.145 s new), so the end-to-end figure is a local measurement rather than a
guaranteed speedup. Both generated executables completed an automatic game.

## Rules

**Backends consume facts, they do not compute them.** Types are read from
`Expr.type`, symbols from `.sym`, layouts from the layout registry, and
module structure from `ModuleFacts`. `tests/compiler/test_backend_purity.jac`
scans the backends for analysis APIs and fails on any read that is not
sanctioned there with a reason. If a backend needs a fact, a pass stamps it.

**Shared code lives with the lowest layer that needs it, never in a sibling.**
A helper the passes and two backends all import belongs in `frontend/` or
`backends/common/`, not in the backend that happened to write it first.

**Every generator has the same shape.** One walker declaration
(`jcir_gen_pass.jac`, `esast_gen_pass.jac`, `na_ir_gen_pass.jac`) holds the
state fields and every method signature; the bodies live in
`<name>.impl/<concern>.impl.jac`, one file per concern (expressions,
statements, calls, declarations, module, and so on). There are no mixins and
no redeclared signatures.

**Where bodies go.** A declaration with one body file keeps it in
`impl/<module>.impl.jac`. A declaration with several keeps them in
`<module>.impl/<part>.impl.jac`. Nothing else.

**The bootstrap tier constrains imports.** `jaclang/bootstrap_manifest.py`
lists the modules the seed transpiler (`jac0`) compiles: the frontend, the
driver, placement, the Python backend and the pass bases. A seed module may
import a non-seed module only inside a function body, because a hoisted
import deadlocks bootstrap. That is why many imports in this tree are local
to the function that uses them; `scripts/check_seed_manifest.py` enforces it.

**Type checking.** `jac check .` runs in CI over the whole repository with
the exclusions in the root `.jacignore`. Every entry there is a debt with a
stated reason; the target is an empty file.
