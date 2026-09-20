# Native standard library consolidation

Native Jac uses the standard library of its bundled Python interpreter through
one shared object provider. Python modules and extension modules use the same
import, attribute, call, iterator, and object protocols. The compiler does not
select a handwritten implementation by a standard-library module name.

The compiler migration is in progress. The boundaries and remaining work below
are part of the implementation contract, not a claim of complete conformance.

## Runtime ownership

`runtime/cpython/capi.jac` declares the shared object API built into both stock
CPython and JacPython. `references.jac` owns references and original Python
exceptions. `provider.jac` supplies the retained values used by native lowering.
Native language primitives and explicit C FFI retain their own ABIs.

A Python object stays an owned Python object while native code uses it. Native
control flow invokes generic object operations; importing `math`, `json`, or
`sqlite3` requires no module-specific lowering. Scalar conversions must be
checked, and arbitrary extension objects must never be cast to native layouts.
Mutable containers and callbacks require identity-preserving boundaries.

Native exception ABI 2 propagates owned failures through normal returns. Local
values and temporary arguments are released before an outer Python entry
restores the original exception. It does not unwind native frames with longjmp.

Import plans retain resolved symbols, lexical bindings, and each statement
occurrence. Local imports execute at their statement and skipped imports remain
unbound. Module bindings live in interpreter-owned namespaces initialized under
CPython's reentrant module locks. Failed initialization clears partial bindings
and remains retryable.

JIT and shared-library entry use the existing runtime requirement to retain the
GIL when Python is needed. Initialization follows dependency order. Error polling
is safe without an attached thread state, including native-only initialization
before CPython starts and polling after finalization; actual object operations
still require an attached interpreter thread.

## Bootstrap

The launcher must materialize the bundled interpreter before it can use Python.
Its private `launcher/platform.zig` archive uses Zig's standard library for
filesystem operations, SHA256, streaming zstd decoding, and PAX tar parsing.
`dist/fused` retains the Jac embedding, materialization, and cache policy.

The materializer validates the payload hash, rejects traversal and links,
extracts both compressed tar layers, preserves executable permissions, and
publishes a completed staging directory atomically. The archive is staged through
the existing floor-library infrastructure, including desktop hosts. There is no
public Python-shaped bootstrap library.

Linux retains libdl and libpthread for the glibc 2.17 baseline. ELF data
relocations precede adjacent PLT relocations so eager binding works on that
loader. Platform-specific native sources use one target-variant resolver.

## Removed duplication and retained components

The public `runtime/na_stdlib` replacements, their resolver routing and allowlists,
and compiler interceptions for `sys`, `math`, `time`, `os`, `random`, and `struct`
are removed. The runtime's ordinary import machinery supplies these modules.

`runtime/python/modules` and `runtime/python/bindings` are retained. They replace
upstream extension implementations in a JacPython build, which removes those
upstream sources. Native Jac reaches these modules through the same public Python
object API as it uses in a stock CPython build.

Python-dependent artifacts record their runtime requirement. Standalone native
applications embed a shared native entry in the existing sealed JAB format, then
attach it to the fused runtime. Project bundles use the same native product. The
JAB loader retains the GIL, passes application arguments, and propagates original
Python exceptions. Native entries perform their own dependency initialization.
Artifact publication is atomic, and replacing an app overlay retains only the
base runtime. Cross-target hosted builds require a matching target runtime.

## Validation and remaining work

Focused tests cover owned references, original exceptions, import ordering and
retry, contextual literals, slices, mutation, and module identity. Bootstrap
validation covers truncated and unsafe archives, runtime cache behavior, desktop
embedding, Linux startup on glibc 2.17, and macOS ARM64 cross-linking.

The migration still needs complete representation facts, Python-backed global
initialization and rebinding, container/callback identity, remaining object
protocols and checked scalar boundaries, thread/finalization guarantees, and
fresh sealed-runtime application validation. Independent-GIL concurrency and complete
stdlib conformance are not established by the current tests.

The explicit bridge probe remains available:

```sh
jac run scripts/probe_native_stdlib.jac --report /tmp/native-stdlib.json
```

An optional `--runtime PATH` repeats the probe against another bundled runtime
using the same compiled artifact. Its direct-object-handle checks establish the
shared API; ordinary-import tests must additionally require native compilation.
