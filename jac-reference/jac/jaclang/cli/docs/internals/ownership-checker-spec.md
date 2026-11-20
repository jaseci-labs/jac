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
[Ownership & Borrowing](../reference/language/ownership-borrowing.md); the
code table is in
[Errors and Warnings](../reference/diagnostics.md#ownership-borrow-errors).

## The three ground rules

**1. Gradual contracts.** Explicit `own`, `lin`, `imm`, `&`, and `&mut` states, derived moves/views, receiver contracts, and allocations under region opens establish the tracked facts. Under nogc enforcement, local ownership states are inferred as well. Ordinary unannotated managed code retains its RC/GC floor; inferred dependencies of annotated code are not exempt from checking merely because a local lacks a written annotation.

**2. Symbol-level granularity, with single-field borrow splitting.** The unit
of tracking is the *binding* -- a declared local or parameter, identified by
its symbol id. Moves, borrows, and consumption are facts about names, not
about heap objects:

- Field- and index-projections are tracked only back to their base symbol
  (`a.b.c` and `a[i]` are accesses *of `a`*). There is no path-sensitive
  *move* state: you cannot move `a.b` while keeping `a.c` live.
- Borrow *conflicts* (E1302, E1303) carry one extra fact: a borrow taken as
  exactly one attribute level on a root name (`&a.b`, `&mut a.b`) records the
  field it covers, and two loans on the same owner conflict only when their
  fields overlap (either names the whole object, or both name the same
  field). Everything else stays whole-object: subscripts, paths deeper than
  one level, and region-synthesized borrows collapse to the owner, and a
  field borrow still pins the whole owner for destruction (E1304), escape
  (E1306), and sendability (E1308). The element space is a pseudo-field
  `"[]"`: reference-yielding loop variables record loans on it, container
  element-writing methods (`append`/`insert`/`add`/`remove`/`pop`/`clear`/
  `extend`/`update`) conflict with any overlapping loan (E1303 for shared,
  E1302 for exclusive), and a loop-created loan's extent is the loop
  statement itself, structurally.
- Stores into a field whose `has` declaration is `own`-annotated are moves
  *within* the owned world, not membrane seals: the source binding is
  consumed as usual, but the enforcement rule (E1402) exempts them when the
  root object is itself an `own` binding outside `glob` state. The ownership
  annotation on a `has` var rides on the inner tag expression
  (`UnaryExpr.ownership` under `SubTag.tag`), not on `SubTag.ownership`.
- Calls use ownership signatures, inferred receiver modes, and borrowed-result dependencies; they do not solve arbitrary cross-function aliasing. An `own`/`lin` argument moves when the destination consumes it; a borrow parameter lends it instead. Callee bodies are checked separately. Two
  contract-known exceptions borrow instead of consuming: read-only builtin
  methods (`find`, `startswith`, `split`, `join`, `replace`, `get`, `write`,
  ...) and calls into the native stdlib surface (`os`/`sys`/`time`/`math`/
  `random`/`struct`), whose C-backed shims copy or read transiently and never
  retain. String reads do not consume their source; under enforcement step-free slices carry view dependencies, while explicit stepped slices materialize owned strings. Named owned strings copy into containers and remain live. Named owned archetypes instead move into list elements and dict values; later source use is E1301.
- There is no alias analysis through arbitrary managed storage. Owned fields and owned container elements retain ownership contracts; ordinary managed stores cross the membrane. Local views preserve borrow roots through borrow-containing types, including inherited fields and generic arguments.
- Flow-sensitivity is per-function CFG dataflow over those symbol ids (the
  `in_consumed` / live-borrow sets), solved on the compiler's shared worklist
  framework (`passes/dataflow.jac`). Branches merge conservatively:
  consumed on *some* path means consumed at the join.

**3. Facts once, consumed everywhere.** The analysis is computed exactly once
per module by the core pass; diagnostics emission and backend policy are both
thin consumers of the same facts. Whether diagnostics are *displayed* is a
property of the compile request (`CompileOptions.emit_diagnostics`), and can
never change what is generated -- display-neutrality is enforced by
construction, not by prohibition. The analysis itself always runs: the
analysis schedule is unconditional on every compile.

## Per-code guarantees (the fact schema's soundness contracts)

For each code: if the checker ran over a function and did not emit it, this is
what diagnostics have verified and what a consumer of the facts may rely on --
always within the symbol-level, intraprocedural bounds above.

| Code | Guarantee when clean |
|------|----------------------|
| `E1301` | No tagged `own`/`lin` binding is read on any CFG path after the move that consumed it, unless it was reassigned (revived) in between. |
| `E1302` | No point in the function has two live borrows of one owner where at least one is `&mut`. Shared borrows may coexist; a mutable borrow is exclusive. |
| `E1303` | An owner is never written (assigned, field/subscript-written through, or `&mut`-reborrowed) while a shared `&` borrow of it is live. |
| `E1304` | No borrow outlives its owner's scope: if a borrow binding declared in an outer scope points at an owner declared in an inner one, the owner's scope end is flagged. |
| `E1305` | Every `lin` binding is consumed (moved to a final owner, passed on, or sealed into managed storage) at least once before its scope ends. Consuming it *twice* is `E1301`, so a clean function uses each `lin` binding exactly once. Plain `own` is affine -- never consuming it is *not* an error, and E1305 is only ever emitted for `lin`. |
| `E1306` | No `&`/`&mut` value escapes the scope that created it: not returned (except the single-passthrough-parameter case), not stored into longer-lived storage. Local borrow-containing views and borrowed-result derivation preserve owner dependencies; they do not grant arbitrary escaping lifetimes. |
| `E1307` | No reference rooted in an `in <handle> {}` region open outlives the handle: not returned (except via single-region elision on a lone `&Region` parameter), not stored where it outlives the handle (legal outward flows become shared borrows of the handle), not handed to an opaque callee (calls that also receive the handle, non-retaining builtins per `JAC_TYPE_REGISTRY`, methods on region-rooted receivers, and constructors under the open are exempt), not sent across a concurrency boundary while borrows of the handle exist, and not wired into managed topology. Extent is dynamic, so the heap-typed result of a call made under the open is region-rooted by the same rules unless the call receives the handle -- with one carve-out: a *directed* connect from a managed anchor into a region-local node, under an open on an owned named handle, is the **seal** (it consumes the handle via the operator-move dataflow and promotes the subgraph; the open admits no archetype instantiation or connect after it, and reuse of the handle is `E1301`). The non-seal shapes (region edge out to managed, undirected wiring, anonymous opens, borrowed `&Region` handles) keep the rejection. Scalar values and `own` reboxes of scalars/strings copy out freely. The bulk free at the handle's drop point therefore cannot create a dangling reference to a region-rooted binding. |
| `E1308` | Every value crossing a `flow`/`thread_run` send boundary is statically race-free at the binding level: a deep-immutable scalar (`int`/`float`/`bool`/`str`/`bytes`, sendable by value), a deep-immutable `imm`, an `own`/`lin` moved into the boundary, or a join-bounded lend -- an inline `&`/`&mut` of an owner whose flow handle is bound and `wait`-ed in the same statement block before any other use of the owner (the join is the borrow's extent). Live borrows outside that shape and unconsumed `lin` bindings do not cross. `wait` is a receive, not a send: the payload crossed at `flow` time, so reading a handle in `wait` is not a boundary crossing. |
| `E1309` | An `imm` binding is never mutated *through that binding*: no reassignment, no field/subscript write through it, no `&mut` of it. (It is the binding that is deep-immutable; the checker cannot see writes through a separately-obtained managed alias.) |
| `E1311` | Every expression-position `imm x` operand is statically unique: an `own` binding (consumed by the operator) or a fresh expression. Uniqueness is the proof that no other handle can ever write the frozen value, which is what lets the operator erase to its operand on every backend. |
| `E1313` | A `flow for` uses a lent element/chunk collection, keeps control flow within its join, and does not grow its borrowed structure; unsupported loop and chunk forms are rejected. Capture safety is checked separately by E1308, with the recognized integer reductions exempted. |
| `E1314` | `partition(n)` uses an owned Region, a literal count, and immediate unpacking into exactly that many plain names; every child is independently affine. |
| `E1315` | A view is not made an owner or stored into a field, container, or global. Returned views derive only from borrowed parameters/receivers, with dependencies preserved at callers. |
| `E1316` | Reading an owned field into an owning destination cannot duplicate its ownership; optional fields must be extracted with `take`. |
| `E1317` | Reading an owned container element cannot silently move it; use a removing operation such as `pop`. |
| `E1318` | A shared borrowed receiver cannot invoke a mutating method, including inferred user methods and builtin container mutators. |
| `E1319` | `take` addresses optional local/attribute storage; `swap` receives two explicit mutable borrows of same-typed local/attribute storage. |

What none of the codes guarantee: memory safety of unannotated code, absence
of aliasing through the managed graph, arbitrary cross-function alias relationships, or foreign-handle lifecycle correctness. Borrowed-result signatures carry only the dependencies the checker can derive. The managed RC/GC floor is
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
- **`Module.gen.rc_move_in`**: stamped by `RcFactsPass._stamp_move_in`; the
  set of Name-node ids that are the single non-definition, loop-free use of
  a LOCAL binding in its own function. The native backend's container
  element preparation consumes it: a grow argument in the set moves in
  (no copy) and its slot is nulled so the binding's release is a no-op.
- **Inferred anonymous opens**: `RegionInferPass` (first in the analysis
  schedule, before `TypeCheckPass`) runs the conservative may-reach-root scan
  over connect operations. Within one code block, fresh node-archetype locals
  connected only among themselves and consumed by expression-statement spawns
  form an unrooted component; any contact with `root`/`here`, any use outside
  the block or outside the connect/spawn forms, any unblessed archetype
  instantiation in the extent, or any control-flow exit through it poisons the
  component. Survivors are rewritten in the tree: the extent becomes a real
  `OpenStmt` whose target is `Region()`, linked as a kid scope of the enclosing
  scope. Every later consumer sees one node kind -- the ownership checker
  (`W1310`, `E1307`), the Python lowering (`try`/`finally` around
  `_jac_region_open`/`_jac_region_close`), and native codegen -- so the graph
  is arena-allocated, drop hooks fire LIFO at the close, and teardown is a bulk
  free, identically in every gc mode and on the Python backend. An `E1307` on
  an inferred open is a bug in the inference, now caught instead of silent.
  `RcFactsPass._stamp_escapes`; the backend stack-allocates an eligible
  instantiation when the target symbol has `na_stack_ok`. For unannotated
  locals any use under a call or return disqualifies. For `own`-annotated
  locals the analysis consumes the checker's guarantees: a `&`/`&mut`
  argument whose resolved callee receives it in a borrow-annotated position
  (and cannot passthrough-return it), and scalar-typed field reads
  (`b.n` under a call or return), do not count as escapes -- the borrow is
  frame-local by E1306 and a scalar copy never carries the object's storage.
  Scalar-field-read safety is ownership-independent, so it also applies to
  *unannotated* locals (droppless affine inference): the codegen gate
  excludes any type with a `drop` hook from stack placement, which is what
  keeps hook timing unobservable. The facts are gc-mode-independent.

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

The pass runs in the unconditional analysis schedule (it needs symbols
resolved), after symbol resolution, inference, and CFG construction, on
every compile -- native-module compiles included. `RcFactsPass` runs
in the native codegen schedule immediately before IR generation, so its
stamps are always freshly computed in-process for the module being lowered.
The checker's cost is proportional to the number of *annotated* symbols;
unannotated modules exit the E13xx analyses early (the move-elision liveness
proof runs regardless, as it serves unannotated code too).
