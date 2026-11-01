# Native Mid-Level IR

The native backend lowers a typed module in two steps. **Lowering** turns the
typed tree into a typed mid-level IR (MIR), and it is the only place the
compiler decides how a value is represented natively and whether a piece of
code can be native at all. **Emission** turns MIR into LLVM IR mechanically.
This page records the design, the invariants it keeps, the runtime ABI it must
preserve, and the plan for replacing `NaIRGenPass`.

It replaces the old split, in which `NaIRGenPass` chose representations while
it emitted LLVM: a local took the LLVM type of the first value stored into it,
signedness and ownership travelled as flags on LLVM values, container and
closure identity were keyed on LLVM type strings, and a function that failed
halfway through emission was demoted afterwards and left behind an `abort()`
stub. Epic #10471 explains why that had to go.

## Invariants

1. **One decision point.** Every value, local, field, parameter, return and
   container element gets its representation while the tree is lowered into
   MIR. Nothing after lowering inspects an LLVM type to decide anything.
2. **Refusals are decided before emission.** Lowering either produces MIR for a
   function or refuses it with a reason (`NativeRefusal`: code, kind, name,
   help, node). Refusals propagate over the call graph before emission starts.
3. **Emission is total.** Every MIR construct has an emitter. An emitter that
   cannot handle its input is a compiler bug: it raises an internal compiler
   error (ICE) and never produces a user diagnostic.
4. **Units meet only through interfaces.** An importer reads a dependency's
   interface, expressed in MIR types. It never re-analyzes or re-lowers the
   dependency's tree.
5. **The schedule is static.** Units are lowered in topological order of the
   analyzed import graph, with import cycles collapsed. Nothing discovers a
   dependency by running lowering.
6. **Facts are data, not flags.** Signedness lives in the type; ownership is a
   result of the ownership and refcount passes; closure environments are
   explicit values.

## Position in the pipeline

```
typed tree  (TYPE_OF, CFG, OWNERSHIP, RC_FACTS, LAYOUT, COMPTIME)
    │  declare      signatures, layouts, vtables, enums  → unit interface
    │  lower        bodies → MIR, or refusals
    │  settle       refusals propagate over the call graph → demoted set
    ▼
MIR passes          monomorphize → closures → ownership/RC → exceptions
                    → generators → regions/nogc → runtime lowering
    ▼
emit                MIR → LLVM IR (compiler/backends/native/llvm/ir)
    ▼
link plan           unchanged: objects, glue, init order
```

`declare` runs for every unit of an import-cycle group before any body in the
group is lowered. A group's interfaces therefore exist before its bodies need
them, and a cycle needs no deferral.

## Representations

MIR types are interned values (`compiler/backends/native/mir/types.jac`).
Equality is structural; no MIR type is identified by a rendered string.

| MIR type | Jac types | LLVM form (unchanged ABI) |
|---|---|---|
| `int(w, signed)` | `int` (64, signed), `i8`…`u64` | `iW`; signedness kept in the type |
| `float(w)` | `float` (64), `f32`, `f64` | `double` / `float` |
| `bool` | `bool` | `i1` |
| `none` | `None` in value position | no storage |
| `str` | `str` in locals and values | `JacStr` descriptor (`jacstr3`, `jacstr2` when headerless; `i8*` on wasm) |
| `str.ref` | `str` in fields, parameters, returns, elements, union members | `i8*` |
| `bytes`, `bytearray` | `bytes`, `bytearray` | `jacbytes*`, `List.u8*` |
| `opt(T)` | `T \| None` in value position | `JacOpt {i8 present, T}` |
| `opt.ref(T)` | `T \| None` in a field or element, when `T` is a reference | nullable pointer |
| `any` | `any`, `object`, unions that share no representation | `JacVal {i8 tag, i64 payload}` |
| `list(E)` | `list[E]` | `List.<storage(E)>*`; `E` stays in the MIR type |
| `list.aos(S)` | lists of value structs | `List.aos.<S>*` |
| `dict(K, V)`, `set(K)` | `dict[K, V]`, `set[K]` | `Dict.<k>.<v>*`, `Set.<k>*` |
| `tuple(T…)` | `tuple[...]` | literal struct pointer (by value when all scalar) |
| `obj(A)` | archetype `A` | `%A*`, from the layout registry |
| `osp(kind)` | `Node`, `Edge`, `Walker` | `OspAnyRef*` |
| `enum(E)` | enum `E` | its underlying type (`i64` or the value type) |
| `fn(P…, R)` | function values | `JacClosure {i64 fn, i8* env}*` |
| `iter(E)` | iterators, generators | `JacIter {i64 next_fn, i8* state}*` |
| `range`, `complex`, `slice` | | `JacRange*`, `JacComplex*`, `JacSlice` |
| `c.*` | C interop: `ptr`, `PtrView`, `Pinned[T]`, `VaList`, clib structs | as `_lower_c_interop_type` today |
| `region`, `type` | `Region`, class values | `i8*` |

Rules that used to live in the emitter become rules of lowering:

- **Locals** take the representation of their symbol's type
  (`get_type_of_symbol`), never the type of the first value stored. The store
  site's own type is only the source of a conversion.
- **Position decides the string and optional forms.** Lowering inserts explicit
  conversions (`str.to_ref`, `str.from_ref`, `opt.to_ref`, `opt.from_ref`) where
  a value crosses positions, so emission never guesses.
- **Containers keep their element type.** `list(int(32, true))` is stored in an
  `i64` slot, but reads are typed in MIR, so no read has to be "restored" from
  per-variable state.
- **Unions** become `opt(T)` when they are `T | None`, keep a single shared
  representation when every member has it, and otherwise become `any`. The
  decision is made on MIR types, not on lowered LLVM types.
- **Generic code** is MIR with type variables. Monomorphization substitutes
  MIR types; it no longer re-runs lowering on the generic tree.

## Instructions

A MIR function is a list of blocks of instructions in SSA form over typed
values, with explicit local slots for variables that are assigned more than
once (LLVM's `mem2reg` promotes them as before). The instruction families:

- **Constants and locals:** `const`, `slot`, `load`, `store`.
- **Scalar arithmetic and comparison**, typed by operand MIR type: no
  separate signed and unsigned opcodes are chosen by the emitter, because the
  type carries signedness.
- **Conversions:** numeric widening and narrowing (from the checker's
  `coerce_to` and fixed-width facts), `box`/`unbox` for `any`, the string and
  optional position conversions, list reflavoring.
- **Calls:** `call` (direct), `call.virtual` (vtable slot), `call.value`
  (closure), `call.runtime` (a runtime helper), `call.c` (clib, with ABI), and
  `call.python` (Python-base and imported-Python bridges).
- **Objects:** `new`, `field.get`, `field.set`, `vtable.get`, `isinstance`.
- **Containers:** high-level operations (`list.get`, `list.set`, `list.push`,
  `dict.get`, `dict.set`, `len`, `contains`, iteration) that the runtime
  lowering pass turns into helper calls.
- **Control:** `br`, `cond_br`, `switch`, `ret`, `unreachable`.
- **Exceptions:** `try` regions with typed handlers, `raise`, `finally`.
  The exception pass lowers them to the setjmp protocol.
- **Generators:** `yield`, `yield.from`. The generator pass turns the function
  into a frame and a state machine.
- **OSP:** spawn, connect, disconnect, edge references and filters, visit,
  report, disengage and skip lower straight to `call.runtime` instructions
  against the OSP kernel's native entry points (`runtime/osp_native.jac`,
  signatures in `MIR_OSP_ABI`), the way containers lower to their runtime
  helpers. Handles are object addresses; type and attribute filters are
  closures the kernel calls; event abilities are reached through thunks taking
  two `any` values.
- **Memory:** `retain`, `release`, `move`, region enter and leave. Only the
  ownership/RC and region passes insert these; lowering never does.

## Refusals and demotion

Lowering a construct either yields MIR or a `NativeRefusal`. There is no third
outcome, and there is no "no rule fired" fallback: a construct with no lowering
rule is refused by that fact, with a code that names it.

After every body in a unit (or cycle group) has been lowered, `settle`
propagates refusals over the call graph until nothing changes:

- **Direct calls** to a refused function refuse the caller.
- **Virtual calls** have an edge to every override of the slot, from the
  layout registry. If any override is refused, every virtual call through that
  slot is refused.
- **Function values:** taking a refused function as a value refuses the code
  that takes it.
- **`with entry` code and global initializers** are bodies like any other and
  are part of the graph.
- **Imported functions** carry their unit's verdict in its interface.

The demoted set, with reasons, is a module fact. Placement, the link plan, the
kernel build and `jac check` read it. When native is required (a kernel unit,
an AOT build, `native_require`), any refusal is an error. Otherwise a refused
function is placed in Python and keeps its Python body; native code never
calls it.

Diagnostics move to the stage that can decide them:

| Code | Stage |
|---|---|
| E1145, E1158, E5095 | type checker |
| E5090, E5092, E5088, E5089, E5091, E5113, E5114 | lowering (refusals) |
| E5026 duplicate global within a unit | lowering |
| E5026 symbol collision across units | link |
| E9001–E9003, E5020 | internal compiler errors |

## Interfaces

Interface format 6 (`compiler/driver/native_iface.jac`) carries MIR types:

- **Exports:** the symbol, kind, full parameter shape (kind, category,
  defaults as constants, comptime flags, varargs), parameter and return MIR
  types, and ownership.
- **Classes:** field MIR types and offsets, the vtable with slot signatures,
  `is_acyclic`, `is_osp`.
- **Generic and comptime callables:** their MIR template, which importers
  instantiate. Importers no longer hold the dependency's tree.
- **Demoted:** the set decided by `settle`, with reasons.

`declare` produces everything except the demoted set, which `settle` adds. The
interface digest covers declarations and the demoted set, so a body change that
does not change either does not invalidate importers.

## Passes over MIR

1. **Monomorphize** generic MIR templates per instantiation, keyed by MIR type
   and comptime constants.
2. **Closures:** materialize environments and closure values.
3. **Ownership and RC:** a dataflow pass that decides retains, releases and
   moves from the ownership pass's facts (`managed_borrow_binds`,
   `rc_last_use`, `own_move_sites`, parameter ownership) and MIR liveness.
4. **Exceptions:** lower `try` regions to the setjmp protocol and unwind
   records.
5. **Generators:** frames and state machines.
6. **Regions and nogc:** region scopes, headerless allocation.
7. **Runtime lowering:** container, string, hash and repr operations become
   calls to runtime helpers. OSP operations are already kernel calls when
   lowering emits them.

Each pass has a verifier that checks its output; the verifier is the contract
the next pass relies on.

## The runtime library

The native runtime is Jac source, compiled once by this backend and linked
like any other unit, the way `runtime/osp_kernel.jac`,
`runtime/region_native.jac` and `fmt_kernel.jac` already are. It replaces the
helpers `NaIRGenPass` emitted as hand-built LLVM IR into every unit (about 175
per unit, specialized per element type and sharing state through weak
globals).

- **Allocation and refcounting:** the object header, `__rc_alloc` and its
  pools, retain and release, drop dispatch and the cycle collector, written
  against the header constants in `compiler/frontend/codeinfo.jac` with the
  memory intrinsics (`__mem_load_*`, `__mem_store_*`, `__atomic_*`).
- **Exceptions:** handler push and pop, raise, the lineage table and the
  per-thread context. `setjmp` itself is emitted inline by the exception pass,
  because it must run in the frame that a `longjmp` returns to.
- **Strings, bytes, repr and hashing** as runtime functions over the `JacStr`
  descriptor and `jacbytes` layouts.
- **Containers** as generic Jac code (`list[T]`, `dict[K, V]`, `set[T]`), which
  the monomorphization pass instantiates per MIR type, in place of the
  per-element-type helpers.

Runtime state that every unit shares (the collector, the trace registry, the
exception context, the vtable and class-constructor registries) is defined
once in the runtime unit, so it no longer needs weak duplicates. The layouts
listed below stay byte-identical, so values cross between generated code,
kernels and C exactly as before. Generated code reaches the runtime only
through `call.runtime` instructions that the runtime lowering pass emits.

## Runtime ABI kept by emission

The new emitter must produce output that links with units, kernels and C code
it does not generate. These stay exactly as they are:

- **The object header:** 32 bytes before the user pointer (alloc id, pool
  class, magic and collector bits at -32; type name at -24; refcount at -16,
  with `RC_SENTINEL` for immortal objects; drop function or tagged string
  length at -8), as defined in `compiler/frontend/codeinfo.jac` and checked
  against `runtime/region_native.jac` by `verify_region_layout`.
- **Value layouts:** `JacStr`, `JacVal` and its tag numbers, `JacOpt`,
  `JacClosure`, `JacIter`, the generator frame header, `JacExceptionState`,
  container headers and names, tuples, and the vtable layout
  (`VTABLE_HEADER_SLOTS`).
- **Shared state:** the cycle collector, trace registry, exception context and
  lineage, TLS slots, `__jac_vtables`, `__jac_class_ctors`, region TLS and
  `__jac_rc_threaded` keep their names and layouts; they are defined once, in
  the runtime library.
- **Kernels:** `runtime/osp_kernel.jac`, `runtime/osp_graph.jac`,
  `runtime/osp_native.jac`, `runtime/region_native.jac` and
  `compiler/backends/common/fmt_kernel.jac` are Jac units lowered by this same
  backend. Their struct layouts are ABI, so they must lower identically. A unit
  that uses OSP depends on the three OSP units; every OSP archetype carries its
  type tag at +8 and a walker its reports list at +16, and each module
  registers its own archetypes and event abilities from its global
  initializer.
- **Symbols:** unit prefixes, `"{prefix}.{name}"`, pub naming, the fixed
  per-unit names (`__jac_glob_init_<prefix>`, `__jac_entry_<prefix>`,
  `__jac_rt_probe_<prefix>`, test and import-callback names), and the exported
  ABI shims (`jac_retain`, `jac_release`, `jac_str_new`).
- **Startup:** glob-init order and contents, entry, the runtime probe, and the
  link glue.

## Replacing `NaIRGenPass`

The replacement is wholesale. The new backend lives in
`compiler/backends/native/mir/` (types, lowering, passes, emission) and is
developed on the epic's branch until it covers everything `NaIRGenPass` does;
then `NaIRGenPass` and its 53 annex files are deleted in the same branch. The
merged result has one native backend and no switch.

The native tests are the oracle. Of the 2,271 tests in
`tests/compiler/backends/native/`:

- **about 1,584 check behavior only** and must pass unchanged. They depend on
  the ABI listed above through `tests/support.jac` (`compile_native`,
  `get_func`, `native_str_func`, symbol lookup through the interface).
- **about 335 assert on LLVM IR text or on `NaIRGenPass` internals** and are
  rewritten against MIR or against behavior.
- **about 61 assert that something must be demoted**, encoding per-function
  seam behavior. Each is reviewed against the refusal rules above; about 31
  assert that something must *not* demote and are kept.
- `assert_native_identity` (byte-identical output across memory profiles and
  Python) and the tier census (`tests/tier_census.jac`) are the whole-program
  ratchets.

Coverage is reached in this order, cheapest behavioral gates first: numerics;
strings, containers and tuples; control flow and loops; archetypes and
vtables; optionals and unions; closures and calls; generics; exceptions and
unwinding; generators; OSP; C interop; the stdlib units; memory profiles;
cross-module and Python interop; concurrency.

## Open questions

- **Generic templates across units.** MIR templates in interfaces need a stable
  serialization; the stub catalog's type encoding (`types/stubcat/writer.jac`)
  is the starting point.
- **Untyped expressions.** The checker does not guarantee a type on every
  expression, and `UnknownType` can survive analysis. Lowering refuses an
  untyped value; each such refusal found in the compiler's own code is a
  checker gap to fix, not a backend rule.
- **Generic call solutions.** The checker records the unspecialized signature on
  a call; lowering needs the solved one. The solution belongs in the checker.
