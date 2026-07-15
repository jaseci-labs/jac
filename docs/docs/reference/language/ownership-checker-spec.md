# Ownership Fact Schema: what each E13xx guarantees

This is the authoritative statement of what `OwnershipCheckPass` computes, at
what granularity, and what its facts promise. It is the contract document for
the compiler's single-source ownership analysis: the per-code guarantees below
are the *soundness contracts* that diagnostics report on and that backends may
rely on when they consume the stamped facts (#7418). The historical
"diagnostics-only" framing -- backends must never read the checker's results --
is superseded: on the native pathway the required-analysis schedule always runs,
error-severity findings gate codegen, and a clean check is precisely what makes
the facts trustworthy inputs for lowering.

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
Unannotated code keeps the managed RC/GC floor exactly as before: gradual
adoption is unchanged.

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
  `in_consumed` / live-borrow sets), solved on the compiler's shared worklist
  framework (`passes/main/dataflow.jac`). Branches merge conservatively:
  consumed on *some* path means consumed at the join.

**3. Facts once, consumed everywhere.** The analysis is computed exactly once
per module by the core pass; diagnostics emission and backend policy are both
thin consumers of the same facts. Whether diagnostics are *displayed* is a
property of the compile request (`CompileOptions.emit_diagnostics` /
`type_check`), and can never change what is generated -- display-neutrality is
enforced by construction, not by prohibition.

## Per-code guarantees (the fact schema's soundness contracts)

For each code: if the checker ran over a function and did not emit it, this is
what diagnostics have verified and what a consumer of the facts may rely on --
always within the symbol-level, intraprocedural bounds above.

| Code | Guarantee when clean |
|------|----------------------|
| `E1301` | No tagged `own`/`linear` binding is read on any CFG path after the move that consumed it, unless it was reassigned (revived) in between. |
| `E1302` | No point in the function has two live borrows of one owner where at least one is `&mut`. Shared borrows may coexist; a mutable borrow is exclusive. |
| `E1303` | An owner is never written (assigned, field/subscript-written through, or `&mut`-reborrowed) while a shared `&` borrow of it is live. |
| `E1304` | No borrow outlives its owner's scope: if a borrow binding declared in an outer scope points at an owner declared in an inner one, the owner's scope end is flagged. |
| `E1305` | Every `linear` binding is consumed (moved to a final owner, passed on, or sealed into managed storage) at least once before its scope ends. Consuming it *twice* is `E1301`, so a clean function uses each `linear` binding exactly once. Plain `own` is affine -- never consuming it is *not* an error, and E1305 is only ever emitted for `linear`. |
| `E1306` | No `&`/`&mut` value escapes the scope that created it: not returned (except the single-passthrough-parameter case), not stored into a field or subscript slot. Borrows are second-class; there are no lifetimes to solve because escape is banned outright. |
| `E1307` | No reference rooted in a `region` block survives the block -- not returned (including indirectly through a call's return value), not stored outside, not handed to a concurrency boundary. The arena free at `}` therefore cannot create a dangling reference *to a region-local binding*. (Granularity caveat: the roots are region-local symbols; a reference laundered through managed storage is beyond symbol-level tracking.) |
| `E1308` | Every value crossing a `flow`/`thread_run` send boundary is statically race-free at the binding level: a deep-immutable scalar (`int`/`float`/`bool`/`str`/`bytes`, sendable by value), a deep-immutable `val`, or an `own`/`linear` moved into the boundary. Live borrows and unconsumed `linear` bindings do not cross. `wait` is a receive, not a send: the payload crossed at `flow` time, so reading a handle in `wait` is not a boundary crossing. |
| `E1309` | A `val` binding is never mutated *through that binding*: no reassignment, no field/subscript write through it, no `&mut` of it. (It is the binding that is deep-immutable; the checker cannot see writes through a separately-obtained managed alias.) |

What none of the codes guarantee: memory safety of unannotated code, absence
of aliasing through the managed graph, cross-function or cross-module
lifetimes, or anything about runtime behaviour. The managed RC/GC floor is
what keeps unchecked code safe; the checker only adds move/borrow discipline
on top for the bindings that asked for it.

## The facts contract (supersedes the diagnostics-only contract)

The analysis stamps documented facts; consumers read them:

- **`Symbol.ownership`** (`OwnershipKind`): written once by `_stamp_ownership`
  from the programmer's annotations; the checker's dataflow annexes consume it,
  as does the sendability rule. Parser-stamped syntax facts
  (`SubTag.ownership` / `UnaryExpr.ownership`) remain available and are what
  survives the JIR cache.
- **`Assignment.na_move_lowerable`**: stamped by the core `RcFactsPass`
  (scheduled in the native codegen slot) from a backward-liveness proof on the
  shared dataflow framework -- a `b = a` alias whose LOCAL source is dead-out
  may lower as a move. The native backend's reference-count elision consumes
  this fact; the former backend-private `RcElisionProofPass` solver is deleted.
- **`Symbol.param_rebound`**: stamped by `RcFactsPass`; drives the backend's
  param-promotion retain decision (formerly an emit-time def-use rescan).

Requirements on the native pathway:

- **The required-analysis schedule always runs** (inference, CFG, static
  analysis, access, ownership, native capability) for native modules,
  independent of whether diagnostics display was requested.
- **Error-severity findings block native codegen.** Type errors, ownership
  E13xx, static-analysis and access errors, and capability E5090s all gate the
  artifact; warnings (portability W6xxx, lint) stay advisory. A program that
  compiles natively has passed the full check -- which is exactly why its
  annotations are trustworthy facts.
- **Display never changes codegen.** Builds with and without diagnostics
  display produce bit-identical binaries, because the analyses run either way
  and only `emit_diagnostics` differs.

The corollary for contributors: a backend must consume stamped facts, never
re-derive them. If a lowering decision needs a semantic fact that is not yet
stamped, add it to the core analysis (or a core pass on the shared dataflow
framework) and consume it -- do not build a private shadow analysis in the
backend.

## Scheduling

The pass runs in the required check schedule (it needs symbols resolved),
after symbol resolution, inference, and CFG construction, on every
`type_check` compile *and* on every native-module compile. `RcFactsPass` runs
in the native codegen schedule immediately before IR generation, so its
stamps are always freshly computed in-process for the module being lowered.
The checker's cost is proportional to the number of *annotated* symbols;
unannotated modules exit the E13xx analyses early (the move-elision liveness
proof runs regardless, as it serves unannotated code too).
