# ownbench

Benchmark suite for Jac's gradual ownership ("the ownership dial"): six
kernels, one source each, annotated to the enforced zero-RC endpoint, run
under three memory modes from the same source:

| mode | flags | meaning |
|---|---|---|
| none | `--enforce-nogc --gc none --assert-no-rc` | headerless codegen, static drops, machine-checked zero RC |
| rc | `--gc rc` | pure reference counting, no cycle collector |
| cycles | `--gc cycles` | reference counting + cycle collector (default) |

The kernels print a deterministic digest on stdout plus one `ns=<wall ns>`
timing line; byte-identical digests across all modes are the executable
witness of the erasure/monotonicity theorems (RQ1 in the paper).

## Kernels

- `binarytrees`: CLBG-style tree churn: recursive owned construction,
  borrow traversal, recursive synthesized drops. Includes a drop-order
  witness (`Probe.drop` prints) exercised across all modes.
- `vecdot`: float list churn + arithmetic floor.
- `histogram`: dict/set pressure with int keys, per-round container churn.
- `vm`: stack bytecode interpreter: owned VM object, hot dispatch over a
  borrowed program list.
- `rbtree`: left-leaning red-black tree in index-arena style (parallel
  owned int lists). Pointer-based in-place rotations are inexpressible
  under whole-binding affine moves; the arena is the design-intended idiom.
- `deriv`: symbolic differentiation: borrow-read input, fresh-build output,
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

    ./run_all.sh            # identity gate + measurements + IR audit
    ./ci_identity.sh        # fast gate only (small sizes, ~2 min warm)

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

## Erasure and the RQ3 lattice

`harness/erase.jac` is the executable counterpart of the paper's erasure
function: it deletes every annotation, and `ci_identity.sh` checks the
erased program reproduces the annotated digest. Partial erasure (the
annotation-lattice sweep) is deliberately not implemented yet: ownership
annotation sites are not independent -- a call-site borrow `f(&x)` is only
well-formed while the callee parameter keeps `&T` -- so valid lattice
points are the configurations closed under this caller/callee borrow
coupling. Site groups must be borrow-closure classes, which makes the
ownership lattice a strict sub-lattice of the gradual-typing hypercube.
That observation belongs in the paper's RQ3 experiment design.
