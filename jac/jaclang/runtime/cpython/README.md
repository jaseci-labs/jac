# Shared CPython runtime interface

This package supplies retained-object operations to native Jac and JacPython.
It ships in the binary payload independently of the JacPython implementation
sources in `runtime/python`. Both runtime variants export the C operations in
`bootstrap/python/object_api.c`.

## Ownership and errors

Calls require the interpreter lock and an attached Python thread state. Handles
borrow their inputs unless the operation explicitly consumes an owned reference.
Object-producing operations return a new reference, released with `jacpy_release`
or transferred to the caller. Zero represents a null handle. For optional lookup
and iteration operations, zero can mean absence or exhaustion; check the Python
error indicator before treating those outcomes as failures.

`ObjectRef` owns one Python reference. `clear` empties the handle before releasing
it, so aliases and reentrant destruction cannot release it twice. `take`
transfers that reference and empties the owner. `borrowed_result` retains its
borrowed input rather than taking ownership from the caller.

`ObjectResult` owns either a successful value or the original Python exception.
Intermediate native frames return it normally and release their references.
Its consuming `take` operation returns the successful handle, or restores the
exception and returns zero at the outer Python entry. Consuming a result twice
raises `SystemError` at that boundary. Use `object_result` only where a null
handle is an error, not for normal iterator exhaustion or optional lookup.

`NativeState` and `ReferenceState` provide the reference visitation and clearing
protocol used by JacPython module bindings. Clearing a reference group
empties each slot before releasing it, without allocating a replacement list;
reentrant clearing observes consumed slots as empty. `owned_tuple` consumes every
supplied owned reference, including on allocation failure. The `pair` and `object_tuple`
helpers borrow their inputs; their results own the element references.
`read_buffer` copies bytes into Jac storage. `serialization_note` preserves the
original Python exception while formatting diagnostic context.

This ownership API does not repair native `longjmp` unwinding. The older
`boundary_failure` helpers used by JacPython implementations still depend on
native exception handling. Ordinary native `try`/`except` support needs the
compiler cleanup changes described in the
[migration document](../../../../docs/architecture/native-stdlib-consolidation.md).

The hosted entry policy lives in `runtime/interop_bridge.jac`. Executable hosts
must explicitly link and initialize their interpreter through C FFI. Declarations
in the default `c` namespace do not supply that interpreter dependency.
Targeted behavior is covered by the
[native reference tests](../../../tests/compiler/backends/native/test_native_python_references.jac).
