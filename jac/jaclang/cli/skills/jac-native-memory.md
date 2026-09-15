---
name: jac-native-memory
description: Apply ownership, borrowing, regions, cleanup, and memory profiles to native Jac. Use for lifetime design or E13xx/E14xx diagnostics.
---

# Native memory

Choose the memory profile separately from the amount of ownership annotation. The profiles are `managed`, `rc`, and native `nogc`; annotation adoption does not itself select a build profile.

```bash
jac build main.jac --native --memory nogc
jac explain memory main.jac
```

## Contracts to preserve

- `own` is affine: transfer consumes the binding; unused values may be dropped. `lin` requires consumption on every accepted path. `imm` is deeply immutable.
- `&value` borrows shared access; `&mut value` borrows exclusive access. Do not move or destroy an owner while dependent borrows remain live.
- Track dependency separately from ownership. The evaluator migration adds `T from owner` and `T from (a, b)` contracts, including named Callable parameters. Preserve dependency metadata across moves and interface caches; an owned dependent value pins its sources through destruction. Consult the implementation-status note in `internals/foreign-lifetime-contracts` before assuming a backend or storage shape is supported.
- Local and returned views retain dependencies on their source parameters or receiver. A view is not an unrestricted owner or sendable value.
- Foreign ownership represents a release obligation. Shared foreign referents do not gain exclusivity, deep immutability, or thread safety. Preserve nonzero empty sentinels, publish replacement state before reentrant cleanup, and check GIL and error-state contracts transitively.
- `take` and owned-container operations transfer values out of places. Overwriting a place must account for the old value's cleanup.
- Managed stores can seal owners. Reboxing supports specified scalar/string copies; it is not a general deep-copy operation.
- `in handle { ... }` opens a region dynamically, including helper allocations. Escapes retain handle-borrow obligations. Moving a sendable region handle transfers its contents within the supported process/task setting; it does not serialize a network message.
- Cleanup and concurrency behavior depend on backend and profile. A successful `nogc` build checks absence of counting/collector machinery, not execution-time bounds or universal target support.
- Raising calls require the applicable handling contract. Do not replace error propagation with a blanket abort-at-frame-boundary rule.

## Retrieve before using an advanced form

Use `from` at the value whose lifetime depends on another binding, including
owned results:

```jac
def open_cursor(connection: &Connection) -> own Cursor from connection;
type Choose = Callable[[a: &Item, b: &Item], &Item from (a, b)];
```

Keep the source alive through an owned dependent's destructor. Moving a
dependent does not promote it to independent ownership. At a C boundary,
declare `foreign_resource` cleanup and `foreign_call` effects explicitly;
import CPython reference types and primitives from
`jaclang.runtime.python.references` instead of assuming ambient type names;
do not infer safety from a function name or a zero-valued integer handle.
For a native helper that uses an external error protocol, annotate the body
with `foreign_call` as well. Native `nogc` body checks include implicit cleanup
and arithmetic calls; every callee needs a compatible external protocol, and
the declared GIL/reentry effects must cover the body. The annotation does not
convert Jac layouts to a C ABI. Do not use an empty `raises` set to omit Jac
exception checks or replace ordinary Jac error handling with this contract.
Returning a borrow of an owned dependent still requires that owner to survive:
the parent's lifetime cannot replace the lifetime of a cursor destroyed on
return. Transfer the owned cursor when its release obligation must escape.
Only the resource's resolved destructor may discharge a dependent owner without
repeating its `from` contract; its source owners remain live during cleanup.
Do not treat every `own PyStackRef` as heap-safe: a `from frame` dependency still
requires promotion before suspension or frame destruction. A linear `PyFrameRef`
owns an active-frame cleanup obligation, not the generator's storage allocation.

Treat the evaluator migration's implementation-status section as authoritative
about remaining storage, reentry, and suspension work. Source availability or an
emitter provenance manifest does not establish runtime validation or C retirement.

Optional CPython lookups use `evaluator_lookup.PyLookupRef` to distinguish error,
absence, and an owned object without allocating a wrapper. Consume the lookup
to obtain its object; never reinterpret its private missing marker as a Python
reference or infer absence from pending exception state.

```bash
jac guide reference/agent-patterns/jac-native-memory --sections
```

The reference retains the full examples, error-code mappings, receiver rules, view constraints, container layouts, region transfers, cleanup, and concurrency restrictions. Retrieve the section matching the construct or diagnostic rather than loading all of it. `jac-concurrency` covers the choice between async work, expression tasks, and lent loops.

Verify with `jac check`, build the actual target/profile, and test observable ownership transfer and cleanup where the change depends on them. A passing managed build does not establish native `nogc` behavior.

For staged foreign transfers, describe the release obligation separately from
the caller's storage. `evaluator_binding.PyBindingRef` tracks the unconsumed
argument suffix and preserves stackref bits when moving values into locals.
`evaluator_calls.PyCallArgsRef` frees its temporary array only after frame
binding consumes the entries. A returned frame must retain dependencies on
borrowed caller arguments; freeing an array alone does not make borrowed
references heap-safe. Conditional C transfer slots must state when ownership
moves and what happens before that point; do not silently turn a conditional
steal into an unconditional `own` parameter.

A multi-place foreign transfer may require an interval with no errors or
reentry. The starred-unpack tail in `evaluator_unpack` uses a native
`foreign_call(errors="none", reentrant=False)` helper to keep list entry
transfers and the final size update together. Borrowed results from locals or
builtins APIs must name their frame/interpreter source, not a temporary new
reference that is closed before return.

Borrowed aliases preserve their source dependencies. A declared source may name
the original owner through such an alias, but an owned intermediate resource
cannot be replaced by its parent: a cursor still needs the cursor itself alive.
A call may consume an owner alongside a view declared `from owner` when that
view has no subsequent use. Both the declared source and last-use condition are
checked. Return contracts follow transitive parameter dependencies; naming a
borrowed intermediary cannot hide a consumed parameter.
