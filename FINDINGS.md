# Formatter performance verification

## Summary

| Ticket | Verdict | Evidence |
|---|---|---|
| #8489 | **Improved; operator-chain rendering now scales near-linearly in local samples** | Same source launcher, 5,000 terms went from 4.71 s before this follow-up to 0.99 s after; 10,000 terms took 1.32 s. |
| #9421 | **FIXED / not reproduced** | Reference formatter processed a valid 3,000-line file in 1.480 s: **2,027 lines/s**, versus the ticket's reported ~350 lines/s/file. This is a single-file sample, not a whole-repository benchmark. |

## Baseline and first fix

The original benchmark used fresh `/tmp/jac-fmt-perf-*` scratch directories and ran `fmt -j 0`; timings included CLI startup. Inputs used valid Jac assignments with a left-associated `+` chain.

Reference executable: `/Users/jaseci/repos/jac-green-verify/jac/zig-out/bin/jac` (read-only).

Root cause of the initial quadratic DocIR work: `jac/jaclang/compiler/tools/impl/doc_ir_gen_pass.impl.jac`, `DocIRGenPass.exit_binary_expr`. Each same-operator binary node recursively flattened the full same-operator subtree. The fix flattened each chain once and skipped unused intermediate DocIR.

The first fix reduced reference 5,000-term time from 50.047 s to about 4 s using the source launcher. However, 10,000 terms still took about 15 s, with a fitted exponent near 1.7. This showed a second quadratic path in rendering.

## Follow-up: lazy flat-tail traversal

Root cause: `jac/jaclang/compiler/tools/impl/jac_formatter_pass.impl.jac`, `JacFormatPass._flat_tail_width`. The caller invokes it for each child in a `Concat`, with a width cap of at most one line (normally 88 columns). The helper eagerly copied **all remaining siblings** into a deque before measuring, even though it stopped after reaching the cap. For a concat with N parts this caused O(N²) queue setup.

The helper now schedules and processes one top-level sibling at a time. It still traverses nested `Concat` parts in the same order and preserves the same early exits for line/group boundaries and the width cap. Once the cap is met, it returns without enqueueing the rest of the sibling tail.

### Measurements

All runs used the worktree source launcher (`jac`), `fmt -j 0`, valid `with entry` assignments, and separate fresh temp directories. A first run after the edit rebuilt one compiler cache module and is excluded. Timings below are warm-cache process times:

| Operator terms | Before lazy traversal | After lazy traversal |
|---:|---:|---:|
| 2,000 | not captured separately | 0.83 s |
| 5,000 | 4.71 s | 0.99 s |
| 10,000 | not captured separately; previous report had 15.35 s | 1.32 s |

The 5,000-term change is about **4.8x faster** versus the immediate pre-edit run. Compared to the prior report's ~15.35 s at 10,000 terms, the follow-up run is about **11.6x faster**, but that comparison spans earlier source-run conditions and should be treated as indicative rather than a controlled benchmark. Post-change growth from 2k to 10k terms is 1.6x, which is consistent with near-linear behavior at these sizes.

## Verification

- `jac test jac/tests/compiler/tools/test_jac_format_pass.jac` - **43 passed**.
- `git diff --check` - clean.
- Existing tests cover long plus/comparison chains, line wrapping, operator placement, and idempotency.
- Benchmark files were created in `/tmp` and removed after each run.

## Limitations

The native/Zig build was not run in this follow-up. Timings are from the Python source launcher, include CLI startup, and use one synthetic operator-chain shape. The pre-edit 5,000-term sample (4.71 s) and post-edit samples were run with the same local launcher; broader repository and alternate DocIR shape benchmarks remain useful if this optimization is to be generalized.
