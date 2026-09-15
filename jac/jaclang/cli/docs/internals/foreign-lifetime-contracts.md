# Lifetime contracts for the native evaluator

This document records the accepted design for the evaluator migration in PR
9188. Implementation and validation are in progress; this is not a claim that
the C evaluator has been retired. The implementation must satisfy the rules
below before its corresponding migration gate is complete.

## Ownership and dependency are separate

`own` transfers a release obligation. `lin` additionally requires consumption
on every path. `&` and `&mut` describe access. A postfix `from` clause describes
the owners whose lifetimes a value requires:

```jac
def peek(stack: &PyStackRef) -> &PyObjectRef from stack;
def pop(frame: &FrameRef) -> own StackRef from frame;
def promote(frame: &FrameRef, value: own StackRef from frame) -> own PyObjectRef;
def choose(a: &Item, b: &Item, first: bool) -> &Item from (a, b);
def open_cursor(connection: &Connection) -> own Cursor from connection;
```

A dependency is not an extra retain. Moving a dependent value preserves its
dependencies. An owned dependent value keeps its sources alive until consumption
or destruction, including its destructor; its last ordinary read is insufficient.
A borrowed result can use last-use liveness. A `from (a, b)` result conservatively
requires both sources, regardless of which branch produced it.

A resource's declared destructor may consume a dependent owner: the source
owners remain live for the entire cleanup call. This exception belongs to the
resolved destructor declaration, not another function with the same name. Other
consuming calls must preserve the dependency in their parameter contracts.

Bodies are checked against their declared sources. Unknown, duplicate,
self-referential, and cyclic sources are errors. A function cannot return a
value depending on an owned parameter it destroys on return. Single-source
borrow elision remains available where the source is unambiguous.

Dependencies must survive assignment, returns, field and container storage,
type aliases, generic substitution, interfaces, and serialization. Moving an
aggregate moves its release obligations and dependencies together. Independent
ownership requires an explicit operation whose contract produces an independent
result, such as `promote` above.

## Callable contracts

Callable parameter names provide a scope for `from` clauses:

```jac
type Peek = Callable[[stack: &PyStackRef], &PyObjectRef from stack];
type Handler = Callable[
    [frame: lin FrameRef, value: own StackRef from frame],
    own PyObjectRef
];
```

Existing unnamed Callable syntax remains valid. The compiler resolves source
names to parameter positions. Renaming parameters leaves the contract unchanged.
Parameter ownership, linearity, result ownership, and dependency constraints
participate in compatibility checks and survive interface caches. A gradual
Callable cannot erase a resource contract.

An owning frame and its dependent stack value may transfer in the same call
when the callee accepts that dependency. Moving only the frame while the stack
value remains live is rejected. The caller relinquishes both release obligations
and the callee must discharge them in dependency order.

## Foreign resources

```jac
@foreign_resource(abi="pointer", empty=0, drop=py_decref,
                  aliasing="shared", reentrant_drop=True)
obj PyObjectRef;

@foreign_resource(abi="word", empty=1, drop=py_stack_close,
                  aliasing="shared", reentrant_drop=True)
obj StackRef;
```

These declarations describe opaque resources with foreign cleanup. They do not
allocate Jac objects or acquire Jac RC headers. The compiler validates the ABI,
empty sentinel, and deallocator contract. Moving out of a slot publishes its
specified empty value. Assignment and clearing publish the replacement or empty
value before invoking a reentrant destructor.

The CPython binding uses these declarations in
`jaclang.runtime.python.references`. `PyObjectRef` and `PyStackRef` must be
imported; the compiler does not assign resource semantics to those spellings or
infer error and loan contracts from a C function's name.

For `aliasing="shared"`, owning a release obligation does not establish exclusive
access to the referent, deep immutability, or thread safety. It does not justify
LLVM `noalias` or `readonly` attributes. Raw integer handles do not substitute for
these checked resource types.

## Foreign calls and reentry

```jac
import from c {
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def py_call(function: &PyObjectRef) -> own PyObjectRef;
}
```

These are trusted declarations at the C boundary. Calls with available Jac bodies
are checked. Requirements and effects propagate through native and indirect
calls. Python error-state operations must preserve unrelated Jac error state.
An empty inferred `raises` set cannot suppress implicit checked arithmetic or
cleanup errors.

A synchronous native function can declare the same protocol:

```jac
@foreign_call(requires=["gil"], errors="python", reentrant=True)
def call_once(function: &PyObjectRef) -> own PyObjectRef {
    return py_call(function);
}
```

This is a checked body contract under native `nogc`. Each emitted non-intrinsic
call must have a resolved external error contract, including implicit cleanup
and arithmetic error paths. An `errors="none"` body cannot invoke an
`errors="python"` operation. Declared GIL and reentry requirements must cover
the body and its cleanup. Runtime decorators, generators, async functions,
comptime functions, and generic bodies are rejected for this form.

An accepted body uses its declared external error protocol at native call sites;
it does not read or overwrite Jac's exception slot. Unannotated Jac functions
retain their ordinary error handling even when source inference finds no
explicit `raise`. The annotation does not change argument layouts into C
layouts: a borrowed opaque C string and a Jac `str` descriptor are different
types, and target-specific C ABI conversions still need their normal adapters.

A live owner does not by itself prove that a borrowed container element remains
valid across mutation or reentry. Supporting that use requires a stability proof
or independent ownership; until then the compiler must reject it. The CPython migration must preserve
its frame-local overwrite retention rules rather than introduce unconditional
retains for all borrowed stack references.

## Source implementation status

The current source implements declared foreign resources, callable ownership
and dependency metadata, dependent local cleanup, and checked native tail
transfers. Callable compatibility rebases dependency positions when omitting
implicit receivers; a dependency on `self` cannot become a dependency on the
first explicit argument. Lists of required sources denote sets, so their order
does not change callable compatibility.

C calls, function values, and resource destructors resolve their declarations
before selecting an ABI symbol. Aliases and unrelated native functions with
the same spelling do not grant or remove a foreign contract. Borrowed C records
also do not justify LLVM immutability or exclusivity attributes.

The evaluator sources include raise logic, active-frame cleanup, monitoring and
tracing control, coroutine-origin and async-generator setters, error formatting,
name lookup, and import handling using these contracts. A linear frame owns a cleanup obligation tied to the current thread;
a dependent executable reference is closed before its thread frame is popped.
The source changes in this review batch have not been built or tested.

`evaluator_lookup.PyLookupRef` owns the result of a CPython optional lookup.
Its three states distinguish an error, absence, and an owned object without
allocating temporary storage or inspecting Python's pending error to infer
absence. A private marker never becomes a `PyObjectRef`; consuming the lookup
returns its owned value or a null owner. This adapts output parameters at the
trusted boundary and does not implement arbitrary foreign-resource fields.

Generic foreign-resource storage, arbitrary closure capture, suspension,
container-element stability across reentry, and complete effect propagation
through every storage/interface shape remain migration prerequisites. These
design requirements must not be treated as implemented guarantees. The C opcode
evaluator and tier-two executor remain in the candidate build.

## Validation before completing the migration

The proof cases include direct and indirect transfers, interface round trips,
dependent frame clearing and suspension, reentrant replacement/finalizers,
cleanup on every error path, and bounded native stack use. Compiler acceptance
alone is insufficient: tests must observe reference counts, finalizer ordering,
Python exceptions, and actual native calls.

The interpreter acceptance gates remain those of PR 9188: all enabled opcode
handlers and required support APIs, source and object retirement with clean and
cached builds, independent evaluator provenance, upstream compatibility coverage,
matched tail-call-baseline performance, and supported-platform CI. Passing the
lifetime tests does not complete those gates.
