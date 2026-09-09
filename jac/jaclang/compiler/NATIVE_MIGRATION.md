# Native compiler migration checkpoint

This migration is in progress. The production native scope has not been
expanded to include the full type checker. Verified LLVM IR for individual
methods is not evidence that the complete checker links or executes natively.

## Implemented foundations

- Jac object fields, constructor generation, reflection, and representation
  use `runtime/object_model.jac`. External Python dataclasses are adapted at
  the boundary by `runtime/object_interop.jac`. Python parser records in the
  bootstrap implementation remain separate from Jac object semantics.
- Field declarations share `compiler/field_semantics.jac` across checking and
  code generation. Native factories use ordinary call classification and
  emission; constructor argument order is separate from storage layout.
- Bundled native library functions use stable module-qualified symbols, and
  layout metadata records their emitted names. Application module, class,
  and global symbol identity still need further work.
- Native function emission shares scoped state restoration across functions,
  methods, lambdas, generators, and initialization.
- Native lowering failures persist in LLVM metadata, including erased fields
  and aborted methods, so executable builds can reject incomplete lowering.
- Compiler graph, symbol provider, catalog, callable, and LLVM contracts have
  more precise types. Native container storage, tuple iteration and unpacking,
  imported function aliases, computed properties, and inherited destruction
  have additional implementation and regression coverage.

## Current evidence and limits

Focused local runs have passed 35 object-model integration tests, 98 broader
serialization/schema/permission tests, 37 narrowing tests, and 35 dictionary
and tuple regression tests. These are separate development runs, not a full
suite result for the final branch or a CI success claim.

A subsequent focused run passed 16 native factory, pipe, module-alias, and
object-field checking tests. The expanded installed/checkout scope regression
and host/native edge-peer regressions also passed. The bootstrap manifest now
validates 81 seed modules, including shared field semantics.

The rebuilt compiler kernel also passed all six parser and early-pass parity
tests, including native memory retention. Its materialization schema keeps
erased fields opaque and identifies strings from semantic types. Classmethod
detection and symbol-table self-assignment handling now lower successfully.
The kernel still records 17 other demoted methods; this is not a strict,
fully native compiler build.

An expanded evaluator/helper scope produced verified IR with 26 recorded
lowering issues and five ordinary diagnostics. The core expression evaluator
and narrowed-union helper no longer had recorded lowering failures in that
probe. The probe skipped engine construction: full linking and execution
remain unproven. A separate native generator source audit reported 212 errors
and 890 warnings. Counts depend on the selected scope and source revision.

The next generator/LLVM contract batch passed 57 generator, closure,
comparison, and optional-payload tests. Its source audit reduced the native
generator diagnostics to 114 errors and 765 warnings. This is progress on
compiling the backend itself, not a successful full native checker build.

The subsequent object, call, statement, and driver-layout contract batch
reduced that source audit to zero errors and 704 warnings. Native primitive
source checking also passed with zero errors. The focused behavioral run
passed 41 tests; four class-constant structural assertions needed to inspect
emitted IR before LLVM optimization, and all five selected tests passed
after that adjustment. Optimized-binary class-constant parity passed in the
original run. The remaining warnings include substantial erased typing;
zero source errors does not prove successful native lowering or execution
of the entire compiler.

Prelude export lists and ambient import groups now come from `ModuleFacts`
over the already loaded Unitree. This removes two direct Python AST parsing
paths from the evaluator and shares literal-string extraction with other
type operations. Five metadata tests, a source-prelude integration probe,
and all 81 bootstrap seed modules passed. Python stub loading remains separate migration work.

The ELF linker now preserves optional weak imports and requires strong imports
regardless of object merge order. It emits dynamic imports only for referenced
symbols and eagerly binds images with weak function imports so address guards
observe null for absent hooks. Direct executable/shared-library probes and a
round trip using the bundled PBS zstd archive pass. This addresses the packaged
binary's missing zstd tracing-hook failure; full CI still needs to pass.

The subsequent packaged smoke failure exposed a field-schema regression:
checking for expression nodes excluded `HasVar` declarations, so string fields
were marked opaque and materialized as `None`. `FieldInfo.semantic_type` now
provides the typed declaration contract used by materialization, including
inherited fields. A focused native layout regression confirms string fields
remain strings while foreign fields remain opaque.

Quoted type expressions now use the Jac expression parser and annotation
evaluator. Temporary syntax releases its graph edges after lookup, and
speculative diagnostics use a scoped suppression counter. Jac builtin
extensions install typed symbols without editing Python stub text. Generic
base specialization compares canonical class identity across source and
catalog graphs. All 19 focused quoted-expression, builtin-extension, generic
identity, and distinct-type tests passed. These checks do not establish that
the full checker links or executes natively.

Canonical identity also governs class assignment, enum ancestry, and enum
underlying-value recognition across independently loaded graphs. Field markers
retain import provenance before full type analysis. Jac object validation uses
an optional Pydantic core-schema adapter over the same Jac field metadata;
constructor defaults and recursive schemas have executable coverage.

Native object and container destruction share element release and tracing,
including tagged reference fields and cycle collection. Loop lowering consumes
inferred types, tuple pop preserves its producer's storage layout, and nested
calls preserve lexical binding. Focused tests pass for these contracts,
heterogeneous containers across memory modes, walker reclamation, region
partitioning, and LLVM ownership attributes. Structural tests request emitted
IR before optimization; runtime tests continue to exercise executable output.

## Remaining work

| Area | Required work in Jac |
| --- | --- |
| Object semantics | Complete factory and constructor parity for inherited and imported/cached classes, dynamic factory values, and remaining field options through shared field and call contracts. |
| Graph access | Provide typed edge endpoint/peer operations with consistent persistent, transient, and native behavior; audit compiler graph lifetimes. |
| Compiler session | Reuse the existing program, module hub, dependency graph, diagnostics, and caches; remove erased session contracts and interpreter-specific resource discovery. |
| Type checker | Resolve remaining evaluator imports, external declarations, optional narrowing, reflection, and Python AST dependencies; link and execute the complete checking scope. |
| Compile-time evaluation | Complete dynamic value operations, calls, defaults, reflection, exceptions, and cycle handling using shared runtime semantics. |
| Dynamic containers | Introduce shared runtime layout/type descriptors where erased values currently lose container representation. |
| Module identity | Extend canonical declaration identity and qualified emission beyond bundled library functions to application modules and class/global registries. |
| I/O and catalogs | Complete file and encoding behavior and typed byte-buffer/catalog decoding through shared standard-library services. |
| Ownership | Complete remaining nogc tuple/container transfer, nested aggregate, string-copy, and exceptional temporary lifetime cases. |
| Native backend | Remove remaining source typing failures and invalid signature fallbacks; complete comprehension and callable semantics. |
| Migration policy | Enforce strict lowering consistently on fresh and cached artifacts once the required closure can pass; do not silently demote unsupported methods. |
| Production rollout | Validate linked checker parity, clean bootstrap and packaging, expand native scope, benchmark chess compiles, and bring required CI checks to green. |

The implementation should extend these shared services rather than introduce
a second type checker, compiler session, catalog parser, or field-specific
call interpreter.
