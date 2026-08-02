# results/archive/ -- quarantine index

Eleven historical interopbench captures, each in its own `<date>-<name>/` dir
with a `MANIFEST.json`. **All timing captures are EXCLUDED** pending
reproduction from a frozen revision under controlled conditions. The structural
audit is retained (correctness-only).

## Why everything is quarantined (the core finding)

Three independent headline contradictions were found, and **all three collapse
across the same commit boundary -- `367a786cc`** ("payload sweep to N=100k +
paper", 2026-07-23). Captures taken before it (n5/n7, 2026-07-22) disagree with
captures taken after it (n30, 2026-07-23/24) on every timing claim:

| paper claim (current) | source capture | value | contradicted by | value |
|---|---|---|---|---|
| svc_split ratio (L576) | `2026-07-22-xruntime-n7` | **135×** | `2026-07-24-xruntime-n30` | **515×** |
| feed ratio (L577) | `2026-07-22-xruntime-n7` | **213×** | `2026-07-24-xruntime-n30` | **329×** |
| iop_cb slope (L626) | `2026-07-22-sweep-n5` | **183 ns/work** | `2026-07-24-sweep-n30` | **88 ns/work** |
| callback fixed cost ~5.4 µs (L633) | `2026-07-22-sweep-n5` | **4471 ns** | `2026-07-24-sweep-n30` | **9 ns** |

Diagnostic clues (why this is NOT random variance):

- **Direct side is stable** across n7→n30 (690k→696k ns for svc_split). Only the
  RPC/client path inflated ~3.9×. A pure machine-state change would move both.
- The n30 sweep slopes (~88 ns/work) agree with `iop_call/free ≈ 86.7` internally,
  so the n30 set is self-consistent -- making the **n5** slopes the outlier, not
  vice-versa. But the two cannot be averaged without knowing what changed.
- Same `jac` binary (`/home/jac/.local/bin/jac`, dev-mode from this worktree) for
  all captures, so the binary is not the delta.

=> Root cause is either a harness/kernel change in `367a786cc` (or the uncommitted
tree present at n30 capture), or a connection-lifetime / cold-start difference in
the RPC host adapter. Resolving this needs Step 1 (frozen revision + env manifest)
and a controlled rerun (Phase C item 15). The manifests above attribute each
capture to the best-effort HEAD-at-capture commit.

## Per-capture status

| dir | status | feeds paper claim |
|---|---|---|
| `2026-07-22-interop-audit/` | **retained** (correctness-only) | structural audit -- not a timing result |
| `2026-07-22-bridges/` | excluded | native-bridge family (overlaps contradicted sweep) |
| `2026-07-22-ffi-baseline/` | excluded | FFI 102×/153× (needs matched controls, #35/#40) |
| `2026-07-22-sweep-n5/` | excluded | iop_cb slope 183, callback 4471 ns |
| `2026-07-22-xruntime-base/` | excluded | earliest baseline |
| `2026-07-22-xruntime-n7/` | excluded | **selected table: 135×/213×** |
| `2026-07-23-payload-sweep/` | excluded | 934 ns/element, N≈20810 break-even |
| `2026-07-24-sweep-n30/` | excluded | contradicts sweep-n5 |
| `2026-07-24-sweep-n30-ci/` | excluded | CI companion to sweep-n30 |
| `2026-07-24-xruntime-n30/` | excluded | contradicts xruntime-n7 (515×/329×) |
| `2026-07-24-xruntime-n30-ci/` | excluded | CI companion to xruntime-n30 |

Nothing here was deleted. Originals were moved from
`jac/examples/interopbench/results/` (untracked artifacts; the harness
regenerates them on next run). Regenerate via `scripts/quarantine_captures.py`.
