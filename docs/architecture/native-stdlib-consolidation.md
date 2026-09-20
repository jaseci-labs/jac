# Native standard library consolidation

Status: shared runtime object API, ownership and initial hosted import lowering
implemented; the full stdlib migration and cleanup remain in progress. Initial
audit: checkout `36c2d1d03` on Linux x86-64.

## Finding

Native Jac machine code can reuse the standard library exposed by the bundled
CPython runtime through its public object API. It does not need a separate Jac
implementation or C adapter for each standard-library module. This works for
Python modules, extension modules, and the replacement modules provided by a
JacPython build.

The same native shared library passed nine probe groups in both the installed
stock-CPython Jac binary and a freshly source-built JacPython runtime. Both were
Python 3.14.6; JacPython reports compiler bridge version 4. Both runtime variants
were also built from source and passed their required runtime smoke checks.
These results establish the shared bridge mechanism, not full standard-library
conformance or completion of the compiler migration.

The retained object API is now linked into both runtime variants. Shared object
operations have moved out of the JacPython compiler adapter, and generic
reference ownership and GC visitation no longer depend on extension bindings.
`runtime/cpython/references.jac` owns native Python references, transfers results,
and carries original Python exceptions in explicit `ObjectResult` values. The
outer Python entry consumes a result and restores its exception only after
intermediate native frames have returned normally. Existing module bindings reuse
the same ownership protocol. Both build cache identities include the shared API.
The shared interface lives in `runtime/cpython`, which is included in the binary
payload; `runtime/python` contains JacPython implementations excluded from that
payload. The existing shared-runtime module registry keeps these interfaces in
the native target when imported by an external application.

Targeted native tests exercise reference transfer, repeated alias clearing,
mutable object identity, Unicode and large integers, errors through nested calls,
exception identity, import failures, and null-handle rejection. The harness holds
the GIL through the existing native JIT and the hosted shared-library loader.
Linked Python ABI symbols determine a `requires_python` runtime requirement.
Source artifact format 2 records that requirement; the loader and generated
Python-to-native stubs share the same calling-convention decision with native
test and CLI entries, including LLVM static constructors and destructors.
Python-free entries continue to release the GIL.
Module resolution and bootstrap payload extraction still need the migrations
described below.

Native exception ABI 2 propagates pending errors through ordinary returns and
uses the same dispatch path for managed code, `nogc`, generators and iterator
adapters. It no longer uses `setjmp`/`longjmp`. Each function releases its local
values before propagating to its caller. Expression cleanup slots protect
already evaluated arguments, partial construction and return values while
`finally` executes. Generator frames distinguish owned bindings from scratch
slots, and preserve caught and pending errors across suspension.

An owned error record carries the native payload and a copy of its message.
Managed code uses the existing reference-counting runtime. `nogc` code uses
explicit ownership transfer and static drops, without introducing reference
counting into the program. Native tests copy a failure diagnostic before clearing
the owned pending error. Exception TLS symbols include the native ABI version so
an older host cannot interpret the new context layout accidentally.

The ownership regressions live in
[native_unwind_cleanup.jac](../../jac/tests/compiler/backends/native/fixtures/native_unwind_cleanup.jac)
and
[test_native_python_references.jac](../../jac/tests/compiler/backends/native/test_native_python_references.jac).
Hosted import lowering now uses `runtime/cpython/provider.jac`. Its internal
Python value inherits the shared reference owner; generic imports, attributes,
calls, indexing and scalar conversion use the retained CPython API. Python errors
remain owned exception values while native locals and `finally` blocks clean up.
The outer hosted entry restores the original interpreter exception. Native
handlers match Python exception classes through CPython's exception matcher.

Generic arithmetic, rich comparison, identity, membership and truth testing
also use the shared object API. Chained comparisons and boolean expressions
short-circuit while retaining the selected Python value. A shared expression
provenance check distinguishes hosted values from untyped native containers in
membership diagnostics. These paths have targeted large-integer, aliasing,
short-circuit and exception tests.

Hosted iterators reuse the native user-iterator adapter. Its state owns the
latest returned reference until replacement or destruction, so exhaustion and
early exit release yielded Python values. Builtins receiving Python-backed
arguments use the interpreter as well, including `next` with a default, `len`,
`str`, `int` and `list`.

Function-local imports execute at their statement and keep an owned local
binding. Import recognition uses resolved symbol identity, preserving aliases
with the same spelling in different scopes. From-imports reuse the pinned
interpreter's import machinery, including its circular-import fallback and
`ImportError` construction.

The import plan separates statement occurrences, resolved symbols, and lexical
scopes. Repeated imports execute in source order even when they overwrite the
same binding. Local bindings start uninitialized and raise `UnboundLocalError`
if their statement has not run. Shared runtime functions use the existing module
symbol naming mechanism, so helper names do not collide with user functions.

Explicit native text and bytes boundaries use checked conversions through the
shared object API and buffer helpers. Unicode and embedded NUL bytes survive a
round trip; wrong Python object types raise `TypeError` instead of being cast to
an incompatible native layout. Native bytes arguments are boxed as Python bytes.

Module import bindings initialize eagerly and live in a namespace owned by the
current interpreter. The namespace is keyed by a private, address-significant
native module identity; the existing JIT engine pinning keeps escaped code and
its identity alive. No process-global variable retains a Python object. A shared
provider runs the generated import initializer under CPython's reentrant module
lock and clears partial bindings after failure. Native `try`/`finally` handles
lock release and preserves the original exception. Targeted tests cover distinct
from-import aliases, failure/retry, concurrent and recursive entry, and sequential
subinterpreters using the shared GIL. Independent-GIL concurrency is not yet
established.

JIT initializer queues retain failed and pending work for retry. Shared-library
initializers run dependencies before their importer and stop immediately when an
initializer restores a Python exception.

The initial ordinary-import probe opens SQLite, executes a query, reads the row,
and returns a checked native scalar. A repeated-error probe verifies native
`except sqlite3.OperationalError` handling and propagation to the Python caller.
This is not full stdlib conformance: existing `na_stdlib` routes still take
precedence. General module-global initialization, remaining object protocols,
containers, callbacks, exception bindings, hosted application packaging and
bootstrap migration remain required before deleting the duplicate modules.

## Reproduce

From the repository root:

```sh
jac run scripts/probe_native_stdlib.jac --report /tmp/native-stdlib.json
```

An optional `--runtime PATH` repeats verification in another Python or Jac
runtime, using the same compiled artifact. For example, append:

```sh
--runtime jac/.python-build/jacpython/linux-x86_64/python/install/bin/python3.14
```

The driver builds [native_stdlib_bridge.jac](../../scripts/fixtures/native_stdlib_bridge.jac)
with the checkout compiler into a temporary shared library, rejects build
failures and reported demotions, and verifies it in fresh subprocesses. It
records runtime versions and module origins in the optional JSON report. The Jac
driver serializes its verification function into a temporary code artifact so
the same checks run in each pinned Python 3.14 runtime without installing the
Jac compiler there.

| Probe | Verified behavior |
| --- | --- |
| JSON | Unicode including embedded NUL and emoji, large integers, keywords, parse callbacks, exact JSON error type and fields |
| SQLite | Connection/cursor objects, parameter binding, rows, binary data, callbacks, database exceptions, explicit close |
| Compression | zlib, gzip, bz2, lzma and zstd round trips; incremental lzma; concatenated bz2 streams |
| Decimal | Exact decimal addition and identity of the current runtime context |
| Expat | Parser objects, Unicode, callbacks and parser errors |
| Other stdlib | Large factorial, runtime struct formats/native alignment, default hyphen wrapping, StringIO, ContextVar tokens/reset/None, regex objects |
| Ownership/errors | Identity and stable reference count over 10,000 returned references; original callback exception identity; import/attribute errors |
| Threads | Calls from four Python-managed worker threads, each entering through PyDLL |
| Native caller | A Jac function creates its own argument tuples and SQLite connection, runs SQL, converts the result to an i64, and closes the connection |

The native exports borrow CPython object handles and return a new reference, or
zero while preserving the Python exception. The driver explicitly consumes each
returned reference. It uses `ctypes.PyDLL`, which retains the GIL and checks the
Python error indicator after the native call. See CPython's
[call API](https://docs.python.org/3.14/c-api/call.html),
[reference ownership](https://docs.python.org/3.14/c-api/intro.html#reference-counts),
and [PyDLL contract](https://docs.python.org/3.14/library/ctypes.html#ctypes.PyDLL).

The probe does not establish automatic conversion of arbitrary native Jac
objects, native `except` handling of Python exceptions, foreign-thread entry,
subinterpreter support, Windows/macOS linking, WASM support, or performance.
Most test arguments remain live Python objects throughout. The SQLite scalar
entry additionally proves construction and consumption from native Jac itself.

## What prevents a resolver-only change

The initial audit found that an ordinary `import sqlite3` failed with E5090 even
though the equivalent generic C API call succeeded. The hosted import path now
lowers that probe. The remaining migration must address all of these boundaries:

1. **Placement and imports.** The capability checker and placement solver reject
   Python modules outside their native allowlist. The shared resolver selects
   `na_stdlib` replacements by filename. Both need a hosted-Python provider
   recorded as a compilation fact, rather than another per-module allowlist.
2. **Representation.** Native Jac values and `PyObject*` are different ABIs.
   A native `str` argument is not a `char*`, and a native container is not a
   Python container. The probe uses explicit object handles. Production code
   needs a compiler-recognized representation with ownership, not exposed
   integer addresses or unchecked casts.
3. **Exceptions.** The scalar callback bridge uses `CFUNCTYPE`. The Python-base
   helpers can print errors and return zero. Neither supplies the required
   exception contract for general stdlib calls. Native cleanup and `try`/`except`
   must preserve the original Python exception and its traceback.
4. **Runtime entry.** Python-dependent `NativeLibrary` artifacts use `PyDLL`,
   which retains the GIL and propagates pending Python errors. Generated stubs,
   JIT initializers, native tests and CLI entries use the shared `native_callable`
   helper to select the equivalent `PYFUNCTYPE` convention. Foreign-thread entry, callbacks,
   and finalization still need the complete interpreter/thread-state contract;
   loading the same symbols does not establish it.
5. **Artifact requirements.** Shared artifacts record Python dependencies.
   Standalone native builds reject Python ABI dependencies without an explicit
   interpreter library. Existing C FFI embedders can link and initialize Python
   themselves, as the desktop and CEF hosts do. A Python-backed native application
   must package and initialize the interpreter before entering code that uses it.
   Compiler availability at build time does not provide an interpreter to the
   emitted executable.

Relevant implementation points:

- [Resolver](../../jac/jaclang/compiler/frontend/codeinfo.jac)
- [Capability checks](../../jac/jaclang/compiler/passes/impl/capability_check_pass.impl.jac)
- [Placement](../../jac/jaclang/compiler/placement/placement.jac)
- [Existing runtime bridge](../../jac/jaclang/runtime/interop_bridge.jac)
- [Python-base helpers](../../jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/pyb_interop.impl.jac)
- [Native artifact validation](../../jac/jaclang/compiler/backends/native/entry_points.jac)

## Recommended implementation boundary

Use one hosted Python-object provider for all ordinary Python imports. Compile
native Jac control flow to machine code, and emit generic import, attribute,
call, iterator and protocol operations when a value belongs to that provider.
Resolve imports with the normal runtime import machinery and preserve project
module shadowing. Reuse the existing retained-object ABI operations where
applicable; do not generate one handwritten shim per module.

Retain Python objects across calls. Copying containers on every crossing loses
mutation and aliasing semantics. Large Python integers and arbitrary extension
objects must remain representable even when they do not fit native Jac layouts.
Conversions into explicitly native scalars require defined, checked behavior.
Cache imports and owned objects per interpreter, with proper teardown.

Record interpreter requirements in artifacts and their cache identities. For
Python-backed applications, reuse the existing application packaging and runtime
initialization path. Python-free libraries, bootstrap code and WASM cannot
silently acquire the same dependency. Their supported scope is an explicit
product decision; preserving them does not require a second full stdlib.

## Duplication that can be removed

`runtime/na_stdlib` currently contains 29 public modules and their private
helpers: 51 Jac files, 6,387 source lines. Most public compatibility modules can
be deleted once their consumers use the hosted provider. Compiler interceptions
for stdlib calls can then be removed or reduced to demonstrated optimizations
that preserve the hosted semantics. Keep behavioral/parity fixtures as migration
tests; replace expectations that merely pin known limitations.

`runtime/python/modules` and `runtime/python/bindings` have a different role:
they replace 17 upstream CPython extension modules in a JacPython build. That
build removes the corresponding upstream sources. Routing through the public
runtime modules reuses these replacements too; it does not require retaining
both versions of each extension in one runtime. This investigation does not
propose undoing the JacPython replacement project. See the
[runtime description](../../jac/jaclang/runtime/python/README.md) and
[source manifest](../../jac/bootstrap/python/cpython-sources.txt).

Native language primitives, ownership machinery and C FFI still serve native
Jac code. Their existence is not another stdlib implementation.

## Remove the bootstrap dependency before deleting its modules

The precompiled launcher currently materializes the runtime before loading
CPython. [materialize.jac](../../jac/jaclang/dist/fused/materialize.jac) uses
`hashlib`, `os`, `shutil`, `tarfile`, `time`, `compression.zstd` and `io.BytesIO`.
[bringup.jac](../../jac/jaclang/dist/fused/bringup.jac) orders extraction before
interpreter initialization. Deleting those modules now breaks startup and the
launcher build.

The payload writer emits only regular files and directories, using PAX for long
paths. A clean final bootstrap does not need a public `TarFile`, `ZstdFile`, or
`BytesIO` API. Replace this with an internal image materializer whose contract is
only the format the packer produces. Two viable designs to evaluate are a small
indexed image decoded with libzstd, or an immediately loadable interpreter subset
that performs the remaining extraction through Python. Neither design has been
implemented or benchmarked by this probe.

An indexed image can retain the existing C decompression and hashing engines
without their Python-shaped object wrappers. Its shared format definition must
cover path validation, permissions, bounds, versioning and atomic cache
publication. Preserve current cold-start, cache, failure cleanup and concurrent
startup behavior. Moving the entire existing stdlib under an internal name would
not remove the duplicate implementations.

## Migration acceptance order

1. Implement the owned Python-object representation, generic operations and
   exception propagation. Exercise native callers and callbacks, mutable aliases,
   Unicode, buffers, large integers and cleanup on failure.
2. Route ordinary imports through that provider and require generated native IR
   in tests, so whole-function demotion cannot masquerade as success.
3. Package Python-dependent native applications through the hosted runtime;
   specify the remaining Python-free target contract.
4. Replace bootstrap's public stdlib dependencies with the image materializer.
5. Delete redundant public modules, allowlists and interceptions, keeping the
   behavioral tests. Update stale stdlib documentation and artifact cache keys.

Relevant regression suites include native stdlib equivalence tests, native
library/ABI tests, `tests/payload`, `test_fused_runtime_boot.jac`, and
`test_fused_runtime_cache.jac`. Cross-platform and current JacPython rebuild
validation remain required before the production migration is complete.
