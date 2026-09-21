# Native list `append` performance diagnosis

## Executive finding

Jac native list `append` was roughly 3x slower than an equivalent C loop in the
measured list-churn workload. The cause was not cache locality, TLB behavior,
branch prediction, or the LLVM backend. The hot loop carried too much of the
list-growth implementation after LLVM inlined it: allocator and copy machinery
increased register pressure, forced spills, and left the loop with additional
reloads and control-flow work.

The landed fix moves list growth into a private, `noinline`, `nounwind` helper.
That keeps the cold `malloc`/`memcpy`/`free` path out of the caller's hot append
loop. It is a safe, verified improvement, not the complete optimization path.

## What was measured

The workload performed 100 million iterations of list churn and compared the
native Jac binary with an equivalent C binary:

| Metric | Jac baseline | Equivalent C |
| --- | ---: | ---: |
| Instructions/iteration | 29 | 14 |
| Cycles/iteration | 6.0 | 2.0 |
| Store-buffer stalls/iteration | 3.0 | approximately 0 |

Hardware-counter profiling showed approximately zero cache, TLB, and
branch-miss signal across the binaries; Jac even missed less than C on those
counters. The distinguishing signal was `RESOURCE_STALLS.SB`, which was about
3 cycles/iteration for Jac and negligible for C.

The profiling tools are [`scripts/native_profile.py`](../../scripts/native_profile.py)
and [`scripts/miniperf.c`](../../scripts/miniperf.c). The Python harness dumps
Jac's LLVM IR, compiles it with clang at `-O2`, and runs grouped
`perf_event_open` counters without requiring the `perf` command.

## Diagnosis, in causal order

### 1. The bottleneck was not the memory hierarchy

Cache, TLB, and branch-miss counters did not explain the gap. This ruled out
the usual interpretation that the list benchmark was simply paying for poor
memory locality or unpredictable growth branches.

### 2. The backend was not introducing a separate code-generation regression

Compiling the Jac-generated IR with clang at `-O2` reproduced the Jac binary.
The cost was therefore already present in the IR shape supplied to LLVM rather
than being a Jac-versus-clang backend mismatch. Native compilation defaults to
optimization level 2 in
[`compile_options.jac`](../../jac/jaclang/compiler/driver/compile_options.jac).

`llvm-mca` estimated about 39 uops for the loop. With a six-wide dispatch
front end, that is consistent with a roughly 6.5-cycle dispatch-bound loop and
matches the measured front-end pressure.

### 3. Inlined growth polluted the hot path

Before the fix, the append helper contained the list-growth path. After LLVM
inlined append into the user loop, the loop effectively included:

- the `malloc`/`memcpy`/`free` growth sequence;
- a control-flow merge between the no-grow and grow blocks;
- reloads of `len`, `cap`, and `data` at that merge;
- checked capacity arithmetic, including the `i * 3` overflow check and its
  `movabs`/`cmp`/conditional sequence; and
- enough simultaneously live values across the allocator and copy calls to
  create register pressure.

The register allocator consequently spilled values to the stack. In
particular, the loop's `n`/length state was reloaded for the loop comparison.
This explains the store-buffer signature: the dominant cost was the generated
instruction and spill shape, not the cost of fetching list data from cache.

Attributes such as `readonly` or `noalias` could not remove the structural
problem: values still had to cross the no-grow/grow CFG merge, and the inlined
calls still enlarged the live range. A state-threading variant also measured
no improvement because `-O2` already represented the relevant length state with
phis.

## What landed

The implementation now emits one helper per list element type:

```text
private noinline nounwind @__list_grow_<element>(list, len)
```

`append` checks capacity and calls that helper only from its grow block. The
normal store path remains in the append helper, while growth's allocation and
copy work is out of line.

Relevant implementation points:

- [`na_ir_gen_pass.jac`](../../jac/jaclang/compiler/backends/native/na_ir_gen_pass.jac)
  declares `_emit_slow_path_helper` and `_emit_list_grow_fn`.
- [`container_helpers.impl.jac`](../../jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/container_helpers.impl.jac)
  provides `_emit_slow_path_helper`, the reusable construction and attribute
  policy for outlined slow paths (`private` + `noinline` + `cold`, plus
  `nounwind` when nothing in the emitted module can unwind, which holds for the
  whole backend because exceptions use `setjmp`/`longjmp`, never LLVM
  unwinding), and emits the private `noinline nounwind` list helper around
  `_emit_grow_array`.
- [`lists.impl.jac`](../../jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/lists.impl.jac)
  calls the helper from the grow block and marks append/set `nounwind`.

`noinline` is load-bearing. A build without it byte-reproduced the baseline,
because LLVM inlined the helper and restored the original hot-loop shape.

## The pattern, centralized and audited

The list fix generalizes to a backend lowering rule: for an operation whose
fast path is small and hot but which carries a rare allocation, copy, or loop,
emit only the check and update inline, and build the slow branch through
`_emit_slow_path_helper`. The audit of other growth paths applied it to:

- dict/set rehash (`__{dict,set}_rehash_*`): already a separate function, but
  `private` linkage alone let LLVM inline it back into the hot insert path;
  it is now `noinline cold nounwind`.
- dict/set order compaction (`__{dict,set}_order_compact_*`): a scan loop
  reached from the insert path's rare full-order branch; same attributes.
- bytearray growth (`__bytearray_grow`): the doubling/flooring plus
  `_emit_grow_array` sequence moved out of `__bytearray_reserve`, whose
  capacity check stays inline for `extend`/`setslice`.

Deliberately left inlineable: `_hash_order_remove_fn` (deletion trim, not a
growth path), hash/probe and insert fast paths, and the tiny scalar accessors
that do not carry allocation or scan loops. The criterion is *small hot path
plus rare allocation, copying, looping, or complex control flow*; not all
container helpers.

The same rule now covers the remaining audited operators:

- string repetition (`__jac_str_repeat`);
- list repetition and concatenation (`__list_repeat_*`, `__list_concat_*`);
- list equality and lexicographic comparison (`__list_compare_*`);
- list membership (`__list_contains_*`);
- list slicing and stepped string slicing (`__list_slice_*`,
  `__jac_str_slice_step`); and
- cycle-root buffer growth (`__rc_push_root_grow`), while the root push
  fast path remains a short `nounwind` wrapper.

Capacity/holes checks stay in the caller. Allocation, copy, and scan loops are
private `noinline cold nounwind` helpers, so LLVM cannot re-inline their
machinery into a hot user loop. The native function factory also marks fixed
runtime helpers `nounwind`; callback thunks remain outside that default.

## Result and validation

The landed change reduced the measured churn loop from 29 to 26 instructions per
iteration and from 6.0 to 5.0 cycles per iteration: approximately a 17% cycle
improvement. Correctness checks preserved the list workload output and
`fib(35)`.

The scoped suite comparison reported 37 passing tests and one pre-existing
infrastructure failure requiring a built kit image. The profiling harness
itself was smoke-tested and prints the before/after counter table.

The release-note entry is
[`9362.feature.md`](../../release_notes/unreleased/jaclang/9362.feature.md).

## What remains separate: the V2 follow-up

A larger experiment constructed the list header on the stack for function-local
lists and kept only the data buffer on the heap. It measured approximately:

- 2.7 cycles/iteration instead of 6.0;
- a 55% improvement; and
- store-buffer stalls falling from about 3.0 cycles/iteration to approximately
  zero.

That result directly attacks the store-buffer signature, but it is not safe to
land as a local code-generation tweak. It requires escape analysis to prove
that the header does not outlive the function or escape through an alias, plus
a data-only release path that preserves ownership and destruction semantics.
Until those invariants exist, the stack-header version remains a follow-up
design rather than part of the shipped fix.

## Short explanation

Jac native lists were slower because list growth was fully inlined into the
append loop. The resulting IR caused reloads, overflow-check work, and register
spills, producing store-buffer and front-end stalls. Moving growth to a
`noinline` helper cut the measured cost by 17%. The remaining 55% opportunity
is the stack-constructed-header design, which needs escape analysis and a safe
data-only release path before it can land.
