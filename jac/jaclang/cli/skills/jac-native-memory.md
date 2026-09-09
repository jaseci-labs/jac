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
- Local and returned views retain dependencies on their source parameters or receiver. A view is not an unrestricted owner or sendable value.
- `take` and owned-container operations transfer values out of places. Overwriting a place must account for the old value's cleanup.
- Managed stores can seal owners. Reboxing supports specified scalar/string copies; it is not a general deep-copy operation.
- `in handle { ... }` opens a region dynamically, including helper allocations. Escapes retain handle-borrow obligations. Moving a sendable region handle transfers its contents within the supported process/task setting; it does not serialize a network message.
- Cleanup and concurrency behavior depend on backend and profile. A successful `nogc` build checks absence of counting/collector machinery, not execution-time bounds or universal target support.
- Raising calls require the applicable handling contract. Do not replace error propagation with a blanket abort-at-frame-boundary rule.

## Retrieve before using an advanced form

```bash
jac guide reference/agent-patterns/jac-native-memory --sections
```

The reference retains the full examples, error-code mappings, receiver rules, view constraints, container layouts, region transfers, cleanup, and concurrency restrictions. Retrieve the section matching the construct or diagnostic rather than loading all of it. `jac-concurrency` covers the choice between async work, expression tasks, and lent loops.

Verify with `jac check`, build the actual target/profile, and test observable ownership transfer and cleanup where the change depends on them. A passing managed build does not establish native `nogc` behavior.
