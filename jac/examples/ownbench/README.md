# ownbench

Benchmark suite for Jac's memory-management research: the gradual
borrow checking experiments ("the ownership dial") and the topology-aligned
region experiments share one tree, one measurement discipline, and one
differential-identity oracle.

## Part 1: ownership kernels

Six kernels, one source each, annotated to the enforced zero-RC
endpoint, run under three memory modes from the same source:

| mode | flags | meaning |
|---|---|---|
| none | `--enforce-nogc --gc none --assert-no-rc` | headerless codegen, static drops, machine-checked zero RC |
| rc | `--gc rc` | pure reference counting, no cycle collector |
| cycles | `--gc cycles` | reference counting + cycle collector (default) |

The kernels print a deterministic digest on stdout plus one `ns=<wall ns>`
timing line; byte-identical digests across all modes are the executable
witness of the erasure/monotonicity theorems (RQ1 in the paper).

## Kernels

- `own_binarytrees`: CLBG-style tree churn: recursive owned construction,
  borrow traversal, recursive synthesized drops. Includes a drop-order
  witness (`Probe.drop` prints) exercised across all modes.
- `own_vecdot`: float list churn + arithmetic floor.
- `own_histogram`: dict/set pressure with int keys, per-round container churn.
- `own_vm`: stack bytecode interpreter: owned VM object, hot dispatch over a
  borrowed program list.
- `own_rbtree`: left-leaning red-black tree in index-arena style (parallel
  owned int lists). Pointer-based in-place rotations are inexpressible
  under whole-binding affine moves; the arena is the design-intended idiom.
- `own_deriv`: symbolic differentiation: borrow-read input, fresh-build output,
  explicit `clone` where RC systems share subtrees.

Kernel style constraints (load-bearing): no comments/docstrings (repo fmt
strips them), annotations only in the shapes `x: own T`, `p: &T`,
`p: &mut T`, `f(&x)`, `f(&mut x)` so `harness/erase.jac` is exact, no
bitwise `&`, deterministic output only (fixed LCG seeds, no clocks in the
digest, sorted/ordinal iteration).

## Running

From this directory (`jac/examples/ownbench`; the dev-mode `jac` reroutes
to the in-repo compiler anywhere inside the repo, and a one-time
`zig build vendor-musl` in `jac/` is needed for native linking):

    ./run_own.sh            # ownership: identity gate + measurements + IR audit
    ./run_reg.sh [--quick]  # regions: differential matrix + measurements
    ./run_all.sh            # both families
    ./ci_own.sh             # fast ownership gate only (small sizes)

Outputs land in `results/` (gitignored): `results.json` (median ns, max
RSS, digests per kernel x mode) and `ir_audit.json` (`__rc_*` reference
counts; the enforced build must be zero).

The kernels double as compiler regression tests:
`tests/compiler/passes/native/test_ownbench_differential.jac` compiles and
runs every kernel under all three modes at small sizes and asserts digest
identity (plus an erase.jac round-trip), and
`tests/compiler/passes/main/test_ownership_regressions.jac` pins the
checker-level fixes the suite originally surfaced.

Do NOT add a `jac.toml` in this tree: a nested jac.toml becomes the
project root, which disables the repo-root `[dev] jaclang_source` reroute
and silently falls back to the jac binary's bundled (older) compiler.

## Part 2: region kernels

Four kernels cover the topology-aligned region experiments (regions
coexist with the managed heap; these never use enforcement or
`--gc none`):

- `reg_graph`: build-traverse-discard. Per request: build a subgraph of N
  nodes under `in r { ... }` (optional back-edges every B nodes for
  cycle density), traverse with a visited-guarded walker, drop the
  region. Prints per-request tail latencies (`m:p50/p99/pmax`) and the
  node-drop count. `harness/rerase.jac` deletes the handle and open
  lines (the mechanical diff) to produce the managed baseline.
- `reg_wspawn`: walker-spawn reclamation. One walker per request carrying a
  drop-managed resource over a persistent graph; `m:wdrops`/`m:rdrops`
  count the reclamations.
- `reg_transfer`: subgraph transfer. `move` sends the `own Region` handle
  across a `flow`/`wait` boundary (O(1)); `copy` re-traverses and
  rebuilds into a fresh region; `serial` encodes/decodes through a
  string. All three must agree on the subgraph checksum;
  `m:transfer_ns` is the money number.
- `reg_overhead`: the `region_of(here)` growth-rule micro: identical
  walker allocation loops anchored to a managed node vs a region node.

Run with `./run_reg.sh [--quick]` -> `results/regions_results.json`.
The differential tests live in
`tests/compiler/passes/native/test_ownbench_regions.jac`.

Two measured semantics to know when reading results: managed nodes and
edges are pinned immortal by the native runtime (the bare reg_graph
baseline reports `m:drops=0` and monotonically growing RSS -- that IS
the baseline, regions are the reclamation mechanism), and walkers are
ordinary managed objects whose drop hooks fire. Kernel style: traversals
must carry their own visited/stamp guards (cyclic graphs + `visit [-->]`
do not self-terminate), and region-rooted references must stay within
the handle-owning function (the escape checker enforces this).

## Erasure and the RQ3 lattice

`harness/erase.jac` is the executable counterpart of the paper's erasure
function: it deletes every annotation, and `ci_own.sh` checks the
erased program reproduces the annotated digest. Partial erasure (the
annotation-lattice sweep) is deliberately not implemented yet: ownership
annotation sites are not independent -- a call-site borrow `f(&x)` is only
well-formed while the callee parameter keeps `&T` -- so valid lattice
points are the configurations closed under this caller/callee borrow
coupling. Site groups must be borrow-closure classes, which makes the
ownership lattice a strict sub-lattice of the gradual-typing hypercube.
That observation belongs in the paper's RQ3 experiment design.
