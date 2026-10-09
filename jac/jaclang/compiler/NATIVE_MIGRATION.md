# Native compiler migration checkpoint

This migration is in progress. The production native scope has not been
expanded to include the full type checker. Verified LLVM IR for individual
methods is not evidence that the complete checker links or executes natively.

## Checkpoint: the native generator in the kernel (#9852)

The native code generator (`backends/native/na_ir_gen_pass`), the primitive
emitters and the LLVM IR builder (`backends/native/llvm/ir`) are kernel
units. A module placed in the native codespace is lowered inside the kernel
session that analysed it. The session returns the module's LLVM IR text,
native interface, layout and dependencies in its unit record; the host turns
that record into machine code, cache sections and an engine
(`NativeUnitRegistry.adopt_lowered`) and holds no tree for the module. LLVM
itself, the link and the caches stay on the host.

What the generator needs from the host it asks for through one question,
`native_fact`: the target's data layout and triple, struct offsets, the host
OS, codec tables and the primitive emitters' method tables. A project
dependency the host holds no native unit for is lowered in the same session
and emitted as its own unit. Demotion to the server codespace happens inside
the session, and the verdict, notes and coverage records come back in the
session's report.

A program module is never lowered by the generator running as Python
bytecode, and there is no switch for it. The bytecode generator still builds
the compiler's own native units: the kernel, and the runtime library's
native modules (`runtime/na_stdlib`, the formatting kernel), which a release
ships precompiled and a source checkout builds on first use. A session is
served those modules as interfaces and cannot lower them.

Running the generator natively was the first time this much ordinary Jac ran
on the native tier, and it found places where the tier disagreed with
Python. The backend fixes are covered by fixtures under
`tests/compiler/backends/native` (`test_native_generator_shapes.jac`,
`test_native_null_safe_access.jac`, `test_native_nested_unpack_targets.jac`).
One family is known and open: a container whose element type differs from
its destination only by `any`, or by tuple shape, is reinterpreted or rebuilt
with the wrong element kind instead of converted. Kernel sources must not
rely on it: give list, dict and tuple parameters their real element types.

Other habits the kernel's sources must keep, each learned from a failure:
integers are 64-bit and trap on overflow, so hashes and masks are computed in
halves; an f-string must not contain a NUL; a helper table that mixes kinds
of value (`dict[str, any]`) is read into a typed local before it is compared
or indexed; recursion has no interpreter limit to stop it.

## Checkpoint: code generators in the kernel (#9615)

The ES and JCIR generators, the per-module compile driver
(`driver/module_compile.jac`) and the compile products
(`driver/unit_products.jac`) are kernel units. The kernel's `jc_compile`
entry returns each unit's products as a record the host adopts, and the
parse-and-materialize crossing (`jc_materialize`), the native early-pass
path and the materializer's class schema are deleted. Class layouts carry
only their ABI.

Getting the generators to lower took shape changes rather than kernel
special cases: static dispatch replaced reflective dispatch in the ES
unparser and the primitive emitters (`PrimitiveEmitter` in
`backends/common/primitives.jac`), framework backends place view nodes
through a typed `ViewLocator`, and operator tables are keyed by token name.
Package classes outside the toolchain runtime units now take module-scoped
struct names like application classes, and three places that assumed bare
names were fixed at the source: module-qualified class references,
classes read through a precompiled interface (`is_extern_struct` travels
in the stub catalog), and class patterns, which the type checker now types.

Known limits: helpers on less common paths (C-library bindings, sv-to-sv
stubs, some React/Solid entry scripts) still demote, and a call to a
method a subclass inherits from a generic base does not lower natively
yet. Kernel compiles are not optional: when a kernel is present, a module
compile, `jac check` and the preparation of an application, with or without
client code, go through it, and a compile the kernel cannot finish is an
error. A compile is one kernel run: the kernel asks the host for what it
lacks (an import's resolution, a path's project, the interface of a Python or
`jaclang` module) while it runs, and the host neither parses the program
first nor runs the kernel again. The kernel hands a module back, rather than
failing on it, in these cases: it
imports another copy of the compiler package; it reaches a third-party Python
module the host cannot describe as an interface; or its analysis overflows a
64-bit integer (interval arithmetic over two 64-bit ranges), because the
kernel's `int` is a native 64-bit integer that traps on overflow. An integer
literal past 64 bits is not such a case: it is carried to the compiled
constant as sign and magnitude bytes.

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
tests, including native memory retention. (The materialization schema this
paragraph measured was removed with the materializer in #9615.) Classmethod
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
were marked opaque and materialized as `None`. `FieldLayout.semantic_type`
provided the typed declaration contract used by materialization, including
inherited fields; both were removed with the materializer in #9615. A focused native layout regression confirms string fields
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
