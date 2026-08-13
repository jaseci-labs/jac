# Controlled re-capture dataset -- 2026-07-24/25 (CANONICAL)

Interopbench captures under a **pinned CPU governor** (`performance`) **and
disabled turbo** (`intel_pstate/no_turbo=1`), replacing the quarantined
n5/n7/n30 captures (which ran on `powersave` + turbo-on, unpinned -- the root
cause of the contradictions; see `results/archive/`).

## Why this exists

Diagnosis (see memory `interopbench-slope-contradiction-rootcause`): the
contradictions were **uncontrolled-CPU-frequency artifacts**, not a toolchain
bug and not commit `367a786cc` (exonerated). The sweep "two attractors"
(88 & 185 ns/work) were turbo vs base clock on the same Python loop.

Two knobs, two fixes: **pinning the governor** fixed the *comparisons* (call vs
cb agree); **disabling turbo** fixed the *absolutes* (no thermal droop over the
8-min sweep, so slopes/intercepts stop drifting).

## Conditions

| field | value |
|---|---|
| governor | `performance` (all 16 cores) |
| turbo | **disabled** (`no_turbo=1`) |
| affinity | 0-15 (not pinned per-process) |
| git sha | `8495b2ad5` (benchmark tree sha256 `43e8f7357...` -- **identical** to `367a786cc`; benchmark code frozen/unchanged) |
| tree | code clean; only the result artifacts below are uncommitted at capture |
| jac | 0.34.1 dev mode (in-repo compiler source) |
| clock check | `direct` path 385us (turbo) -> 805us (no-turbo) = 2.09x = the boost ratio |
| full provenance | `env.json` |

## Files

| file | what | result |
|---|---|---|
| `env.json` | capture_env.py provenance | governor=performance, **turbo=off**, sha=8495b2ad5, benchmark_tree_sha256 unchanged |
| `sweep_perf_n20.json` | sweep, governor pinned, **turbo ON** (superseded) | resolved call-vs-cb contradiction but absolutes still drift (thermal) |
| `sweep_noturbo_n20.json` | sweep, governor pinned + **turbo OFF** (canonical) | all crossing slopes converge to **212-217 ns/work**; intercepts positive |
| `xruntime_perf_small_n20.json` | svc_split/feed, turbo ON, single run (superseded) | 376x / 270x, but n=1 (no reproducibility shown) |
| `xruntime_noturbo_small_n20_rep{1,2,3}.json` | svc_split/feed, turbo OFF, 3 reps (canonical) | svc_split **369x** (CV 3.7%), feed **243x** (CV 3.0%) |
| `bridges_noturbo_small_n20_rep{1,2,3}.json` | family-1 single-size + FFI + floor, turbo OFF, 3 reps (canonical) | iop_cb crossing **1.13x** (CV 1.2%); iop_call native 8.7x; base_call floor 40144 ns |
| `wasm_noturbo_small_n20_rep{1,2,3}.json` | xop_wasm_call, turbo OFF, 3 reps (canonical) | wasm **6.8x** native (was 10x turbo); native CV <0.1% |
| `payload_noturbo_n20.json` + `_rep{1,2,3}.json` | xop_feed_payload N=1..100k, turbo OFF, **3 sweeps** n=20 (canonical) | direct **342 ns/el** (CV 0.1%); rpc **15ms + 890 ns/el** (2.6x, slope CV 1.8%), break-even N~17k |
| `xtool_ffi_noturbo.json` | cross-tool FFI, 3 kernels (sqrt/struct/bytes) x 5 toolchains (ctypes/cffi/cext/pybind11/pyo3), matched+isolated, digest oracle | struct-by-value tax: ctypes/cffi **~1.1us** vs cext/pybind **~90-135ns**; scalar band 23-61ns; jac na 3ns. Driver `scripts/xtool_ffi.py`. See `xtool_verdict.md` |
| `xtool_rpc_noturbo.json` | cross-tool RPC verdict: jac_sv (shipped) vs FastAPI+httpx/generated-client vs minimal_http, matched+isolated+RTT, digest oracle | jac_sv boundary **9.7x** hand FastAPI, **25.5x** minimal endpoint; loopback RTT ~30us (floor is framework+marshalling, not wire). Driver `scripts/xtool_rpc.py`. See `xtool_verdict.md` |

## Headlines (canonical)

1. **Sweep contradiction resolved.** Under no-turbo every boundary-crossing
   slope collapses onto ~212-217 ns/work:

   | variant | perf (turbo on) | **no-turbo** |
   |---|---|---|
   | iop_call.free | 165 | **217** |
   | iop_cb.free | 163 | **212** |
   | iop_cb.bridge | 246 (noisy) | **213** |
   | sym.sv_local | 212 | **212** |
   | sym.na_to_sv | 179 | **214** |
   | sym.na_local | 4.6 | **5.0** |
   | sym.sv_to_na | 5.0 | **5.1** |

   The pair that read 87-vs-182 (n5) and 185-vs-88 (n30) now agree within ~2%.
   The one path still noisy under turbo (`iop_cb.bridge`, 246) falls into line
   at 213 once thermal drift is removed.

2. **Placement penalty ~42x (the real effect).** Work on the server/interpreted
   side costs ~213 ns/unit; native-side ~5 ns/unit. 214 / 5.1 = **42x**. Crisp,
   physical, reproducible.

3. **The "5.4 us callback fixed cost" is retracted.** Under turbo the fits gave
   nonsense negative intercepts (`iop_cb.bridge` -8682, `iop_call.free` -1222)
   -- an artifact of the clock drooping over the sweep (early points fast, late
   slow, line tilts up, intercept goes negative). Under no-turbo all intercepts
   are positive and small (~130-5000 ns), and **variant-dependent** -- there is
   no single clean fixed-crossing constant; it is a few us but not "5.4".

4. **Cross-runtime ratios reproducible (3 reps).**

   | cell | rep1 | rep2 | rep3 | mean | run-to-run CV |
   |---|---|---|---|---|---|
   | svc_split | 384x | 351x | 373x | **369x** | 3.7% |
   | feed | 252x | 235x | 241x | **243x** | 3.0% |

   All jitter lives in the RPC *numerator* (189-309 ms, loopback/node
   scheduling); the `direct` baseline is rock-solid (CV 0.2-0.3%, ~805 us every
   run). The RPC/direct ratio survives it, stable to ~+/-4%. The earlier
   single-run caveat is discharged.

## Scope of claims

Portable claims are the **ratios** and the **ns-slopes-at-recorded-clock**.
Absolutes (805 us direct, 212 ns/work) are specific to this CPU
(Ultra 7 255H) at pinned base clock / no-turbo. The RPC numerator carries
intrinsic loopback+scheduler jitter that no governor setting removes -- that is
real system noise, characterized (CV ~3%), not a defect.

## Prior caveats -- disposition

1. ~~Thermal drift in absolutes~~ -> **fixed** (turbo disabled; slopes stable).
2. ~~`iop_cb.bridge` noisy (246, unstable intercept)~~ -> **fixed** (213,
   positive intercept under no-turbo).
3. ~~xruntime is a single run~~ -> **fixed** (3 reps; CV ~3%).
4. ~~Dirty tree (paper/notes/probe)~~ -> committed in `8495b2ad5`; only result
   artifacts are uncommitted at capture time.

## Coverage (2026-07-25 update)

The whole suite is now captured under the pinned governor + turbo-off, folded
into `paper.tex`:

- **family-1 single-size** (`bridges_*`): iop_call/iop_cb/iop_symmetric + FFI
  scalar/struct/vtable, 3 reps n=20. iop_cb crossing 1.13x (was 1.17x turbo);
  iop_call native 8.7x; iop_symmetric na 32x; struct-ABI 6.9x; base_call floor
  40144 ns.
- **family-2 cross-runtime** (`xruntime_*`, `wasm_*`): svc_split 374x, feed
  241x, wasm **6.8x** (was 10x turbo). All 3 cells 3 reps n=20.
- **payload sweep** (`payload_noturbo_n20` + `_rep{1,2,3}`): median of **3**
  pinned sweeps. direct 342 ns/el (R2=.99998, run-to-run CV 0.1%); rpc 15ms fixed
  plus 890 ns/el (bootstrap CI 848-983, R2=.994, slope run-to-run CV 1.8%);
  break-even N~17k; ratio 2.6x (CV 1.8%). Fixed-cost floor is the noisy term
  (CV 7.2%, 14.6-17.0ms). Driver: `scripts/payload_sweep_controlled.py`.
- **cross-tool FFI verdict** (`xtool_ffi_noturbo`): 3 kernels x 5 toolchains,
  committed producer (closes STEPS #39). Struct-by-value marshalling tax now
  visible (ctypes/cffi ~1.1us vs compiled ~90-135ns) -- the "more kernels"
  expansion. Driver: `scripts/xtool_ffi.py`.
- **cross-tool RPC verdict + RTT** (`xtool_rpc_noturbo`): the FastAPI/RPC verdict
  matrix. Jac's shipped generated RPC is 9.7x hand FastAPI / 25.5x a minimal
  endpoint on the boundary term; loopback RTT ~30us proves the floor is
  framework+marshalling. `--provider-host` gives real-network RTT. Driver:
  `scripts/xtool_rpc.py`. Write-up: `xtool_verdict.md`.

Dataset is complete: whole suite pinned no-turbo, all cells 3 reps (payload 3
full sweeps). The cross-tool verdict matrix (FFI + RPC) and RTT capability are
now committed producers; the only remaining scope expansion is the
**cross-machine** RTT campaign (run `xtool_rpc.py --provider-host` on a second
box), not a gap in the local instrument.
