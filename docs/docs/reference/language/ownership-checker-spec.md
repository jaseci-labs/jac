# Ownership Checker Specification: what each E13xx guarantees

This is the authoritative statement of what `OwnershipCheckPass` checks, at what
granularity, and -- just as important -- what it does *not* promise. If you are
about to make a backend read the checker's results, read
[The diagnostics-only contract](#the-diagnostics-only-contract) first: that is
forbidden by design, and this document exists to keep it that way.

Reference-doc companion pieces: the user-facing feature guide is
[Ownership & Borrowing](ownership-borrowing.md); the
code table is in
[Errors and Warnings](../diagnostics.md#ownership-borrow-errors).

## The three ground rules

**1. Opt-in.** The checker only reasons about bindings the programmer
explicitly tagged -- `own`, `val`, `linear`, `borrow` / `&` / `&mut` -- plus
allocations lexically inside a `region { ... }` block. An unannotated binding
is invisible to every rule below; annotating one binding never changes what is
reported about another module, function, or unannotated binding. A module with
no annotations and no `region` blocks produces no E13xx diagnostics, ever.

**2. Symbol-level granularity.** The unit of tracking is the *binding* -- a
declared local or parameter, identified by its symbol id. Moves, borrows, and
consumption are facts about names, not about heap objects:

- Field- and index-projections are tracked only back to their base symbol
  (`a.b.c` and `a[i]` are accesses *of `a`*). There is no field-sensitive or
  path-sensitive state: you cannot move `a.b` while keeping `a.c` live.
- There is no interprocedural analysis. A call is handled by its signature
  only: passing an `own`/`linear` value to a call is a consuming move; what the
  callee does internally is checked separately, in the callee.
- There is no alias analysis through managed storage. Once a value is moved
  into a field, container, or graph object (sealed across the membrane), the
  checker's knowledge of it ends; reading it back yields an ordinary managed
  value with no ownership state.
- Flow-sensitivity is per-function CFG dataflow over those symbol ids (the
  `in_consumed` / live-borrow sets). Branches merge conservatively: consumed on
  *some* path means consumed at the join.

**3. Diagnostics-only.** Running the checker can change what is reported,
never what is generated. See below.

## Per-code guarantees

For each code: if the checker ran over a function and did not emit it, this is
what you may rely on -- always within the symbol-level, intraprocedural bounds
above.

| Code | Guarantee when clean |
|------|----------------------|
| `E1301` | No tagged `own`/`linear` binding is read on any CFG path after the move that consumed it, unless it was reassigned (revived) in between. |
| `E1302` | No point in the function has two live borrows of one owner where at least one is `&mut`. Shared borrows may coexist; a mutable borrow is exclusive. |
| `E1303` | An owner is never written (assigned, field/subscript-written through, or `&mut`-reborrowed) while a shared `&` borrow of it is live. |
| `E1304` | No borrow outlives its owner's scope: if a borrow binding declared in an outer scope points at an owner declared in an inner one, the owner's scope end is flagged. |
| `E1305` | Every `linear` binding is consumed (moved to a final owner, passed on, or sealed into managed storage) at least once before its scope ends. Consuming it *twice* is `E1301`, so a clean function uses each `linear` binding exactly once. Plain `own` is affine -- never consuming it is *not* an error, and E1305 is only ever emitted for `linear`. |
| `E1306` | No `&`/`&mut` value escapes the scope that created it: not returned (except the single-passthrough-parameter case), not stored into a field or subscript slot. Borrows are second-class; there are no lifetimes to solve because escape is banned outright. |
| `E1307` | No reference rooted in a `region` block survives the block -- not returned (including indirectly through a call's return value), not stored outside, not handed to a concurrency boundary. The arena free at `}` therefore cannot create a dangling reference *to a region-local binding*. (Granularity caveat: the roots are region-local symbols; a reference laundered through managed storage is beyond symbol-level tracking.) |
| `E1308` | Every value crossing a `flow`/`wait`/`thread_run` boundary is statically race-free at the binding level: a deep-immutable `val`, or an `own`/`linear` moved into the boundary. Live borrows and unconsumed `linear` bindings do not cross. |
| `E1309` | A `val` binding is never mutated *through that binding*: no reassignment, no field/subscript write through it, no `&mut` of it. (It is the binding that is deep-immutable; the checker cannot see writes through a separately-obtained managed alias.) |

What none of the codes guarantee: memory safety of unannotated code, absence
of aliasing through the managed graph, cross-function or cross-module
lifetimes, or anything about runtime behaviour. The managed RC/GC floor is
what keeps unchecked code safe; the checker only adds move/borrow discipline
on top for the bindings that asked for it.

## The diagnostics-only contract

The checker is a lint. Formally:

- **No backend reads the checker's output.** The only analysis fact the pass
  writes is `Symbol.ownership` (sole writer: `_stamp_ownership`), and the only
  readers of that field are the checker's own annexes. The Python, native, and
  ecmascript backends read *parser-stamped* syntax facts
  (`SubTag.ownership` / `UnaryExpr.ownership` -- i.e. what the programmer
  wrote), never anything the checker computed.
- **Codegen is identical whether or not the checker ran.** `nacompile` and the
  JIT compile with `type_check=False` and skip the checker entirely; the
  binaries they produce are the same ones you get with diagnostics on.
- **The native payoff is proven independently.** Reference-count elision for
  move assignments is established by `RcElisionProofPass` -- an unconditional
  native pass that does its own liveness proof and stamps
  `Assignment.na_move_lowerable`. It never consults `OwnershipCheckPass`, so
  it stays sound for unannotated and un-typechecked code.
- **Ownership annotations are erased at codegen.** On the Python backend
  `&x`/`&mut x` compile to exactly `x`; `own`/`val`/`linear` tags don't change
  lowering at all.

The corollary for contributors: if a change makes any codegen decision depend
on whether the ownership diagnostics ran (or on what they found), it breaks
the contract that lets `nacompile` skip type-checking, and it reintroduces the
class of bug where enabling/disabling a *lint* changes program behaviour. Add
a dedicated proving pass on the codegen side instead, the way
`RcElisionProofPass` does.

## Scheduling

The pass runs in the type-check schedule (it needs symbols resolved), after
symbol resolution and CFG construction. It is skipped whenever type-checking
is skipped -- notably the whole native pathway. Its cost is proportional to the
number of *annotated* symbols; unannotated modules exit early.
