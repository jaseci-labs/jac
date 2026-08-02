# Ordered plan to strengthen the paper

## Priority definitions

- **P0 -- Submission blocker:** Fix before relying on any performance claim.
- **P1 -- Strongly recommended:** Needed for a credible architecture evaluation.
- **P2 -- Additional experiment:** Materially strengthens the paper.
- **P3 -- Stretch:** Useful if time permits.

The order matters. Do not add many new experiments until the existing capture contradiction and reproducibility problems are resolved.

---

## Phase A -- Make the existing evaluation reproducible

### 1. **[P0] Freeze one exact compiler and benchmark revision**

Record an immutable experimental revision containing:

- Git commit SHA.
- Whether the worktree is clean.
- Jac compiler version.
- Python version and executable path.
- Node and V8 versions.
- C compiler and linker versions.
- Optimization flags.
- Native backend/LLVM version.
- Benchmark source hashes.
- Harness and analysis-script hashes.

Build and run every paper result from this revision.

**Why:** The five-, seven-, and thirty-sample captures may have been produced from different compiler or benchmark revisions. Until this is known, their disagreement cannot be interpreted as variance.

**Acceptance criterion:** A clean checkout of one commit can produce every paper table.

---

### 2. **[P0] Quarantine all historical captures**

Move existing captures into explicitly named directories, for example:

```text
results/archive/2026-07-22-n5/
results/archive/2026-07-22-n7/
results/archive/2026-07-23-n30/
results/paper-canonical/
```

For each archive, add a manifest containing:

- Capture timestamp.
- Git SHA.
- Invocation command.
- Environment.
- Sample count.
- Whether the machine was controlled.
- Known code changes since the previous capture.
- Reason it is or is not suitable for publication.

Do not silently delete contradictory results.

**Why:** Reviewers will interpret unexplained selection of the favorable five-sample result over an unfavorable thirty-sample result as cherry-picking.

---

### 3. **[P0] Define a result-selection rule before rerunning**

A defensible rule might be:

> The paper reports the aggregate of five independent experimental sessions, each containing thirty paired observations per configuration, all produced from the frozen revision. No session is excluded unless a predeclared machine-health check fails.

Predeclare:

- Number of sessions.
- Observations per session.
- Warm-up count.
- Outlier policy.
- Failure policy.
- Machine-health criteria.
- Primary statistic.
- Confidence-interval method.

**Why:** The team must not decide which result looks best after seeing the numbers.

---

### 4. **[P0] Commit every result-producing script**

The repository currently lacks clear committed producers for some work-sweep, base-floor, and cross-tool FFI results.

Add commands such as:

```text
scripts/run_work_sweep.sh
scripts/run_payload_sweep.sh
scripts/run_cross_runtime_sweep.sh
scripts/run_ffi_baselines.sh
scripts/analyze_work_sweep.py
scripts/analyze_payload_sweep.py
scripts/analyze_cross_runtime.py
scripts/build_paper_tables.py
```

Each script should:

- Run from a clean checkout.
- Fail on a dirty worktree unless explicitly overridden.
- Save the command line.
- Save stdout and stderr.
- Save raw observations.
- Write one machine-readable result.
- Never manually copy numbers into another JSON document.

**Acceptance criterion:** `make paper-results` or one equivalent command regenerates all tables and plots.

---

### 5. **[P0] Track the canonical result artifacts**

The current `results/` directory is gitignored. Either:

1. Commit canonical machine-readable results, or
2. Publish an immutable artifact archive with a DOI/checksum and commit its manifest.

The artifact should include:

- Raw per-invocation timings.
- Aggregated JSON.
- Analysis scripts.
- Plot data.
- Environment manifest.
- Logs.
- Generated code where structural audits depend on it.
- SHA-256 checksums.

**Why:** Reviewers must be able to verify that table values were not copied or transformed manually.

---

### 6. **[P0] Store raw data, not only medians**

For every invocation, retain:

- Session ID.
- Round number.
- Variant execution order.
- Raw total time.
- Derived per-call time.
- Digest.
- Process ID.
- CPU ID if available.
- Provider/server ID.
- Warm-up status.
- Exit status.
- Timing source.
- Serialized byte count where relevant.
- Any retry or failure.

Never make the median the only retained observation.

**Why:** Paired analysis, uncertainty calculation, and diagnosis of multimodal behavior require the raw measurements.

---

### 7. **[P0] Unify the result schema**

The paper says every document uses schema version 2 with provenance, but several artifacts do not.

Create one schema covering:

- Scalar cells.
- Sweeps.
- Cross-tool comparisons.
- Structural audits.
- Confidence intervals.
- Session-level replication.

Required provenance should include:

```json
{
  "git_sha": "...",
  "benchmark_sha": "...",
  "captured_utc": "...",
  "host": "...",
  "cpu_model": "...",
  "microcode": "...",
  "cores": 16,
  "memory": "...",
  "kernel": "...",
  "governor": "...",
  "turbo": "...",
  "affinity": "...",
  "python": "...",
  "node": "...",
  "v8": "...",
  "jac": "...",
  "llvm": "...",
  "cc": "...",
  "build_flags": ["..."]
}
```

---

### 8. **[P0] Define every reported quantity precisely**

For each table column, state whether it is:

- Time for one operation.
- Time for a batch.
- Batch time divided by calls.
- Median of per-call observations.
- Per-element slope.
- Host-observed latency.
- Kernel-internal time.
- End-to-end latency.
- Throughput.
- Startup-inclusive or startup-exclusive.

Avoid using “per-call boundary cost” for a quantity that also includes:

- Callee work.
- Host-language loops.
- Serialization.
- Object creation.
- Process startup.
- Connection setup.

---

## Phase B -- Stabilize the measurement environment

### 9. **[P0] Control CPU placement and frequency behavior**

At minimum:

- Pin the benchmark to a physical core or fixed CPU set.
- Record the CPU governor.
- Record turbo/boost state.
- Record simultaneous multithreading status.
- Avoid migration between cores.
- Stop unrelated heavy workloads.
- Record thermal state before each session.
- Record whether the machine is plugged in.
- Run a short machine-health calibration before every session.

A calibration can repeatedly execute one stable native and one stable Python kernel. Reject a session only if calibration violates a predeclared threshold.

**Why:** The approximately 2× absolute slope changes between captures could arise from environment or code changes.

---

### 10. **[P0] Use independent experimental sessions**

Do not treat thirty subprocess invocations in one short run as thirty fully independent experiments.

Recommended structure:

- At least **five independent sessions**.
- Preferably on different days or after restarting benchmark services.
- Thirty paired rounds per point per session for noisy cells.
- Ten to thirty paired rounds for stable native cells.

Analyze both:

- Within-session variation.
- Between-session variation.

**Why:** Architecture reviewers care whether a result persists across machine state, JIT state and time.

---

### 11. **[P0] Preserve paired sampling correctly**

For each twin:

1. Randomize which variant runs first in each round.
2. Run both variants close together.
3. Store the pair ID.
4. Compute the paired difference or paired ratio for that round.
5. Resample complete pairs, not independent variant observations.

For more than two variants, use a randomized balanced block so every order appears roughly equally.

---

### 12. **[P1] Establish a warm-up protocol based on stability**

“One warm-up call” is insufficient for Node/V8 and may also be weak for server initialization.

For every runtime:

- Plot latency by invocation number.
- Determine when latency reaches a stationary region.
- Warm up until a fixed minimum plus a stability criterion.
- Keep warm-up observations but mark them excluded.
- Report the criterion.

For example:

> At least 100 warm-up calls, continuing until the medians of two consecutive 20-call windows differ by less than 2%.

Use a maximum warm-up limit to avoid infinite runs.

---

### 13. **[P1] Verify that process and connection lifetimes match the claim**

Document whether each timed operation includes:

- Process startup.
- Module loading.
- JIT compilation.
- Server startup.
- TCP connection establishment.
- HTTP keep-alive reuse.
- Client construction.
- JSON parser initialization.
- Wasm module instantiation.

If these are excluded, call the result **steady-state warmed-call latency**. If included, call it **cold-start latency**.

Ideally measure both separately.

---

### 14. **[P1] Add negative-control benchmarks**

Include operations whose expected behavior is known:

- Empty in-process call.
- Empty native function.
- Empty callback.
- Empty loopback endpoint.
- Endpoint returning an empty payload.
- Identity C function.
- Node-to-JS function call.
- Node-to-Wasm no-op export.

These controls reveal whether the harness is measuring the intended mechanism or mostly timer, loop and process overhead.

---

## Phase C -- Repair the work-sweep and callback claims

### 15. **[P0] Reproduce the callback contradiction first**

Rerun `iop_cb` from the frozen revision under controlled conditions before working on secondary results.

Use:

- Five or more independent sessions.
- Thirty or more paired observations per work point per session.
- Raw paired timings.
- Eight existing work sizes.
- Several additional low-work points.
- Fixed CPU affinity.
- Full provenance.

The first question is not “is the cost exactly 5.4 µs?” It is:

> Can a fixed callback overhead be resolved reliably above measurement noise?

---

### 16. **[P0] Measure callback overhead by sweeping call count**

The current paper infers fixed crossing cost by extrapolating execution time to zero work. A more direct experiment is to hold callback work minimal and vary callback count:

```text
calls ∈ {1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 5000}
```

Fit total time as:

\[
T(c)=T_\text{setup}+c\,t_\text{callback}
\]

Compare:

- Direct server call.
- Server→native→server callback.

The slope difference estimates callback overhead directly. It does not require extrapolating callee work to zero.

**This should become the primary callback-cost experiment.**

---

### 17. **[P0] Retain the work sweep only as an orthogonal validation**

The work sweep answers a different question:

\[
t(w)=t_0+s\,w
\]

It separates:

- Fixed dispatch/crossing terms.
- Work-dependent execution terms.

Use it to show that paired direct and callback paths have similar execution slopes. Do not call slopes “statistically identical” unless an equivalence test supports that statement.

A better hypothesis is:

\[
|s_\text{bridge}-s_\text{direct}| < \delta
\]

Choose a meaningful equivalence margin \(\delta\) before analysis.

---

### 18. **[P0] Use paired differences for callback inference**

For every work point and round, compute:

\[
d_{ij}=t^\text{bridge}_{ij}-t^\text{direct}_{ij}
\]

Then report:

- Median paired difference.
- Bootstrap interval over paired rounds and sessions.
- Distribution plot.
- Session-specific estimates.
- Whether zero is excluded.
- Whether the estimate is consistent across work sizes.

If zero remains inside the interval, report:

> We could not resolve callback overhead above measurement noise under this configuration.

That is scientifically acceptable and still useful.

---

### 19. **[P0] Remove the 5.4 µs result unless it reproduces**

Until reproduction succeeds, remove it from:

- Abstract.
- Results.
- Figure captions.
- Design implications.
- Break-even calculation.
- Conclusion.

Do not average the contradictory captures together without establishing that they measure the same code and environment.

---

### 20. **[P0] Recompute the native-placement threshold**

The claimed approximately eighteen-iteration threshold depends on:

- Native-entry fixed cost.
- Server execution slope.
- Native execution slope.

Estimate all three from the same controlled capture:

\[
w^*=
\frac{t_{\text{entry}}}
{s_{\text{server}}-s_{\text{native}}}
\]

Report a confidence interval for \(w^*\), not only a point estimate.

Then validate the prediction experimentally at work sizes around the estimate, for example:

```text
w ∈ {5, 10, 15, 20, 25, 30, 40, 50}
```

The observed crossing point should agree with the model.

---

### 21. **[P0] Reconcile the inconsistent server slopes**

The selected table contains:

- `iop_call/free ≈ 86.7 ns/work`
- Other server paths near `184 ns/work`

The newer capture moves some series near 90 and another near 185.

Determine whether this comes from:

- Different loop body semantics.
- Different number of LCG operations per “work” unit.
- Different compiler revisions.
- Optimization differences.
- Timer placement.
- Argument or call-count differences.
- CPU frequency.
- Accidental double work.
- Different integer representations.

Do not label every x-axis unit “one iteration” unless it represents the same operation in every kernel.

---

### 22. **[P1] Validate that the compiler cannot optimize away work**

Inspect generated native and Python code and add structural checks that confirm:

- Results depend on every iteration.
- The loop is not constant-folded.
- Calls are not inlined away when crossing overhead is being measured.
- No dead result is removed.
- Native and server paths perform equivalent arithmetic.
- The callback actually crosses the runtime boundary once per measured operation.

Where possible, inspect IR or assembly and archive it with the experiment.

---

## Phase D -- Repair the payload experiment

### 23. **[P0] Replace the current fit bootstrap**

The payload sizes are fixed experimental design points. Do not bootstrap the sixteen \(N\) values as if they were random observations.

A better procedure is:

1. Keep the same fixed \(N\) values in every bootstrap replicate.
2. Within each \(N\), resample paired timing rounds.
3. If using multiple sessions, resample sessions first.
4. Compute a per-\(N\) statistic for that replicate.
5. Refit the same fixed design.
6. Retain slope, intercept and crossover.
7. Construct intervals from those replicate estimates.

Alternatively use heteroskedasticity-robust regression on raw observations, with session-level clustering.

---

### 24. **[P0] Report uncertainty for the crossover**

For every bootstrap fit, compute:

\[
N_\text{cross}=\frac{t_0}{s}
\]

Report:

- Median crossover.
- 95% interval.
- Whether the interval lies inside the measured domain.
- Sensitivity to excluding low-\(N\) points.
- Sensitivity to fitting only \(N\ge1000\) or \(N\ge30000\).

Do not imply `N≈21,000` was measured directly; it is a fitted crossover bracketed by measured points.

---

### 25. **[P0] Rename “break-even”**

Use language such as:

> The fitted payload at which the RPC variable term equals its fixed term.

Avoid “break-even” without qualification because readers may think it means RPC equals direct execution. It does not.

At approximately 21,000 elements, RPC is still much slower than direct.

---

### 26. **[P1] Fit against serialized bytes, not only element count**

Record the exact serialized request and response sizes.

Fit:

\[
t(B)=t_0+s_B B
\]

where \(B\) is bytes on the wire.

Report both:

- ns/element.
- ns/serialized byte.

**Why:** Element cost is specific to lists of small integers. Byte cost is more comparable across payload types and serialization formats.

---

### 27. **[P1] Decompose the RPC slope**

Add component controls:

1. Provider list construction only.
2. Local JSON encoding.
3. Local JSON decoding.
4. Encode + decode without HTTP.
5. HTTP transport with pre-encoded bytes.
6. Full RPC.
7. Client-side traversal/checksum.
8. Direct list construction and traversal.

This enables a decomposition such as:

\[
t_\text{RPC}

=

t_\text{dispatch}
+t_\text{construct}
+t_\text{encode}
+t_\text{transport}
+t_\text{decode}
+t_\text{consume}
\]

Then “serialization slope” becomes defensible. Without this decomposition, call it the **full loopback-RPC per-element slope**.

---

### 28. **[P1] Add repeated sessions to the payload sweep**

Nine observations at each point in one capture are not enough to establish long-term stability.

Recommended:

- Five independent sessions.
- At least fifteen paired observations per point per session.
- Randomized payload-size order within each session.
- Randomized direct/RPC order within each point.

Randomizing payload order prevents machine heating or runtime evolution from correlating with increasing payload size.

---

### 29. **[P1] Test the linear model rather than assuming it**

Inspect:

- Residual versus fitted plots.
- Residual variance by payload size.
- Curvature.
- Piecewise behavior.
- Changes near transport-buffer thresholds.
- Large-payload garbage collection.
- JSON parser nonlinearities.

Compare:

- Linear model.
- Linear plus quadratic term.
- Piecewise linear model.
- Fixed cost plus per-byte cost.

Prefer the simplest model whose residuals do not show systematic structure.

---

## Phase E -- Repair the cross-runtime results

### 30. **[P0] Replace the selected seven-sample table**

The paper’s 135× and 213× values conflict with thirty-sample values of approximately 515× and 329×.

Rerun all cross-runtime cells with:

- Frozen revision.
- Stable warm-up.
- Persistent provider process.
- Connection reuse documented.
- Five independent sessions.
- Thirty or more paired rounds per session.
- Full Node/V8 provenance.
- Raw timings.

Report the aggregate across sessions.

---

### 31. **[P0] Avoid ratios across incomparable timers and hosts**

Where possible, time both sides from the same outer harness clock.

For example:

- A single Python driver times direct and RPC end-to-end.
- A single Node driver times JS direct and Wasm export.
- Native and Wasm comparisons use equivalent host structures.

If the clocks or host loops must differ, do not present a precise ratio as a boundary-cost measurement. Present separately scoped latencies.

---

### 32. **[P1] Separate cold-start and steady-state results**

For HTTP/client/Wasm cells, report:

- Cold process startup.
- Server startup.
- First request.
- Warm request.
- Wasm compile/instantiate time.
- Wasm warmed export time.
- Persistent-connection request.
- New-connection request.

This prevents very different lifecycle costs from being mixed into one “crossing” number.

---

### 33. **[P1] Report latency distributions**

For cross-runtime cells, include:

- Median.
- 5th and 95th percentiles.
- 99th percentile if enough observations exist.
- IQR.
- Session-to-session interval.
- ECDF or violin plot.
- Number of retries and failures.

Avoid interpreting min/max overlap as statistical evidence.

---

### 34. **[P1] Fix all table and uncertainty wording**

Correct at least:

- Full IQR versus `±IQR`.
- Captions promising min/max values that rows omit.
- Claims of `<3% IQR` where reference variants exceed it.
- “±5%” for asymmetric confidence intervals.
- “Statistically identical” without an equivalence test.
- “Effect is real” based on five extrema.
- “Directly observed” for fitted crossovers.
- “Pure boundary cost” where other work remains.

---

## Phase F -- Repair the FFI evaluation

### 35. **[P0] Add a no-op and identity-function FFI baseline**

Use a C library containing functions such as:

```c
void noop(void);
int64_t identity_i64(int64_t x);
double identity_f64(double x);
double do_sqrt(double x);
```

Compare each against a matching native reference.

Sweep the number of calls and fit total time versus calls. The slope difference gives per-call FFI cost more directly than integer division of one short batch.

---

### 36. **[P1] Separate call cost from numeric conversion cost**

Measure:

- Integer→integer.
- Float→float.
- Integer→float.
- Float→integer.
- Pointer pass-through.
- Small buffer.
- Large buffer.

This reveals whether the 3.1 ns result is call transition cost or conversion work.

---

### 37. **[P1] Measure every struct shape separately**

Do not average 4-, 12-, 16-, 24-, and 44-byte structs into one 15 ns result.

For each shape, compare:

- By-value call.
- Pointer-to-const call.
- Output pointer.
- Matching native reference.
- Copy-only reference.
- Register-class versus memory-class behavior.

Plot ns/call against struct size and mark ABI classification boundaries.

This could become a genuinely interesting architecture result.

---

### 38. **[P1] Remove setup from the vtable callback loop**

Construct handlers and vtables before timing.

Measure separately:

- Handler creation.
- Vtable registration.
- One callback.
- Repeated callbacks through the same registered object.
- Direct Jac callback.
- C→Jac trampoline callback.

Sweep callback count to derive steady-state trampoline cost.

---

### 39. **[P1] Make cross-tool FFI comparisons truly matched** -- DONE (2026-07-25)

Delivered by `scripts/xtool_ffi.py` (dataset `results/controlled/xtool_ffi_noturbo.json`,
write-up `results/controlled/xtool_verdict.md`): one compiled C fixture bound five
ways (ctypes / cffi / METH_O C-ext / pybind11 / PyO3), same inputs/calls, one
byte-identical digest per kernel enforced across all toolchains, matched +
isolated columns and overhead-above-no-FFI-ref reported. Extended past `sqrt` to
struct-by-value and bytes kernels ("more kernels"). The RPC half of the verdict
matrix (FastAPI + generated-client-equivalent vs Jac's shipped path) is
`scripts/xtool_rpc.py`. Original spec kept below for reference.

Use the same compiled C fixture, inputs, number of calls and digest for:

- Jac native FFI.
- Python ctypes.
- Python cffi ABI mode.
- Python cffi API/out-of-line mode.
- CPython C extension.
- pybind11.
- PyO3 if included.

Separate:

- Host loop cost.
- Conversion cost.
- Foreign-call transition.
- C function execution.

A fair table should report both total end-to-end cost and overhead above each tool’s matching no-FFI reference.

---

### 40. **[P1] Stop using the 102×/153× result as a generic headline**

Unless matched controls are added, describe it as:

> A compiled Jac-native loop calling `libm` versus interpreted Python loops using ctypes and cffi for one scalar operation.

That result is unsurprising because execution placement differs. It should not be presented as a general interop superiority result.

---

## Phase G -- Improve baselines and paper claims

### 41. **[P0] Integrate named floors into the harness**

Ensure `base_call` and `base_pyimport` are:

- Part of the runnable catalog.
- Produced by committed scripts.
- Captured in the same sessions as related cells.
- Stored in the canonical result document.

If NumPy is a required baseline, provision it in the experimental environment rather than leaving the result environment-gated.

---

### 42. **[P0] Rewrite the abstract last**

The abstract should contain only results that survive the final canonical analysis.

Likely safe abstract results are:

- All twin groups retained identical outputs.
- Native execution showed a large slope advantage on the tested integer kernel.
- Loopback RPC showed a fixed floor plus payload-dependent growth.
- Exact effects are scoped to the named host and workloads.

Do not headline callback cost until the contradiction is resolved.

---

### 43. **[P0] Distinguish three kinds of claims everywhere**

Use consistent labels:

1. **Correctness result:** identical digest.
2. **Mechanism result:** fixed or scaling cost in a controlled microbenchmark.
3. **Application implication:** batching, migration or placement may be beneficial.

Do not write an application implication as if it were experimentally demonstrated.

---

### 44. **[P1] Report effect sizes with uncertainty**

For every central comparison, report:

- Point estimate.
- Confidence interval.
- Paired difference.
- Paired ratio where meaningful.
- Session-level variation.
- Number of observations and sessions.

Prefer:

> Median paired overhead was 3.8 µs, 95% interval 3.1–4.5 µs across five sessions.

over:

> The bridge is 1.17× slower.

Ratios depend strongly on how much callee work was chosen.

---

### 45. **[P1] Add an explicit claim-to-evidence table**

A useful table would contain:

| Claim | Experiment | Estimand | Main confound | Scope |
|---|---|---|---|---|
| Native execution slope | work sweep | ns/work | kernel-specific | x86-64 LCG |
| Callback crossing | call-count sweep | ns/callback | runtime jitter | warmed process |
| RPC fixed cost | payload sweep | intercept | loopback/custom runtime | one host |
| RPC payload cost | byte sweep | ns/byte | JSON format | integer lists |
| Struct ABI | per-shape FFI | ns/call | copying/conversion | SysV x86-64 |

This makes reviewer interpretation much easier.

---

# Additional experiments that would strengthen the paper

## Phase H -- Highest-value additions

### 46. **[P1] Repeat the core experiments on ARM64**

Run the canonical suite on:

- Current x86-64 machine.
- One ARM64 machine, ideally Apple Silicon or a server-class ARM CPU.

This is especially important for:

- Struct ABI classification.
- Native entry cost.
- Callback cost.
- Wasm behavior.
- FFI register passing.

Do not expect identical absolute values. Look for whether qualitative cost profiles persist.

**High paper value:** It converts “one machine snapshot” into a cross-architecture characterization.

---

### 47. **[P1] Add realistic payload shapes**

The current integer-list sweep is useful but narrow. Add:

1. Flat integer list.
2. Float list.
3. UTF-8 strings.
4. Binary byte buffers.
5. Flat typed records.
6. Nested records.
7. Optional/null fields.
8. Maps/dictionaries.
9. Mixed records resembling a real feed item.
10. Arrays of feed records.

Measure:

- Elements.
- Serialized bytes.
- Encode time.
- Decode time.
- End-to-end latency.
- Peak memory.
- Digest identity.

This would make the payload result far more relevant to real client/server interop.

---

### 48. **[P1] Implement the actual typed cross-language feed**

The paper currently admits that `xop_feed` is a scalar floor using a minimal fetch shim. Build the experiment implied by its name:

- Jac server returns typed feed records.
- Generated JavaScript client consumes them.
- Use the shipped client runtime, not a custom minimal shim.
- Sweep record count and total bytes.
- Compare direct server-side provider, raw HTTP+JSON and generated client.
- Verify field-by-field identity.
- Measure both warm latency and throughput.

This closes one of the clearest gaps between the paper’s conceptual taxonomy and its actual workloads.

---

### 49. **[P1] Add a realistic end-to-end native placement case study**

Select one application-derived kernel where native placement is plausible, such as:

- Image transform.
- Vector normalization.
- Small numerical filter.
- Parsing/checksum kernel.
- Compression primitive.
- Graph-neighbor scoring.
- Audio feature extraction.

Measure:

- Server-only execution.
- Server→native execution.
- Several input sizes.
- Boundary overhead.
- Computation slope.
- Break-even input.
- End-to-end application impact.

The key question should be:

> Does the threshold predicted by the microbenchmark correctly predict when native placement helps a real kernel?

That validates the paper’s design implication.

---

### 50. **[P1] Add batching experiments**

For a fixed total amount of work, vary:

- Number of crossings.
- Items per crossing.

For example, return 10,000 elements as:

```text
10,000 × 1
1,000 × 10
100 × 100
10 × 1,000
1 × 10,000
```

Measure total latency and throughput.

This directly demonstrates the compiler strategy suggested by the paper: batching amortizes fixed crossing cost.

---

### 51. **[P1] Add concurrency and throughput**

The current HTTP experiments are sequential latency floors. Add:

```text
concurrency ∈ {1, 2, 4, 8, 16, 32, 64}
```

Report:

- Requests per second.
- Median latency.
- p95/p99 latency.
- CPU utilization.
- Context switches.
- Peak memory.
- Error rate.

Use a persistent server and a standard load generator or a carefully documented harness.

This transforms the RPC experiment from a scalar floor into an architecture-relevant workload characterization.

---

### 52. **[P2] Compare loopback, same-LAN and remote network placement**

Run the same endpoint under:

1. In-process dispatch.
2. Loopback HTTP.
3. Same machine but separate container/process.
4. Same LAN.
5. Remote/cloud region if practical.

This shows when software overhead dominates and when physical network latency dominates.

The result could reveal that optimizing serialization matters on loopback but becomes secondary over a real network--or vice versa for large payloads.

---

### 53. **[P1] Redesign the Wasm experiment with matched hosts**

Current native and Wasm paths use different outer host loops.

Use matched comparisons:

- Node→JavaScript reference.
- Node→Wasm export.
- Repetition inside Node for both.
- Identical inputs and reductions.
- Warmed Wasm instance.
- Separate instantiate/compile time.
- Same timer.

For native comparison, either:

- Use a Node native addon as the native target, or
- Present native and Wasm as separate within-host comparisons rather than taking a direct ratio.

Measure no-op, scalar and bulk-buffer exports.

---

### 54. **[P2] Add Wasm call-count and payload sweeps**

Separate:

- Fixed export-call cost.
- BigInt/i64 conversion cost.
- Linear-memory copy cost.
- Bulk buffer processing.
- Returning scalar versus returning array.

This could create a clean Wasm equivalent of the RPC fixed-plus-slope result.

---

### 55. **[P2] Compare the generated client against conventional implementations**

For identical API and payload, compare:

- Jac generated client.
- Hand-written fetch.
- OpenAPI-generated client.
- A conventional Python/FastAPI or Node service if appropriately matched.
- JSON and, optionally, protobuf/gRPC.

The comparison must keep:

- Data schema.
- Payload.
- Connection reuse.
- Work.
- Host.
- Warm-up.

This would help answer whether compiler-owned interop is competitive, not merely measurable.

---

## Phase I -- Broader characterization experiments

### 56. **[P2] Sweep compiler optimization levels**

Run native and Wasm cells under relevant optimization settings:

- Debug/no optimization.
- Standard release.
- Aggressive optimization.
- LTO if supported.

Report:

- Runtime.
- Compile time.
- Code size.
- Whether the boundary cost changes.
- Whether generated wrappers change.

This reveals whether the measured cost is fundamental or a code-generation artifact.

---

### 57. **[P2] Measure memory allocation and peak RSS**

For payload, RPC and Wasm paths, collect:

- Peak RSS.
- Allocated bytes per operation.
- Allocation count if available.
- GC activity.
- Copies of the payload.
- Wasm linear-memory growth.
- Server/client memory separately.

The compiler’s claim is not only about latency; owning both sides may reduce copies and allocations.

---

### 58. **[P2] Measure actual bytes and system activity**

Use tracing or counters to collect:

- Bytes encoded.
- Bytes sent and received.
- Number of read/write syscalls.
- Context switches.
- Page faults.
- CPU cycles and instructions.
- Branch misses.
- Cache misses where meaningful.

Tools could include `perf`, syscall tracing or runtime instrumentation.

This makes the result more architectural: reviewers can see _why_ a boundary costs what it does.

---

### 59. **[P2] Add copy-count or zero-copy experiments**

For buffers and arrays, compare:

- Regular marshalled copy.
- Memory view.
- Native list view.
- Pointer/borrowed buffer.
- Wasm linear-memory view.
- Explicit serialize/deserialize.

Measure latency and allocation volume across payload sizes.

This directly tests claims such as zero-copy `NativeListView` behavior.

---

### 60. **[P2] Add error-path and exceptional-control-flow costs**

Measure:

- Successful call.
- Typed application error.
- Server exception.
- Native error return.
- Wasm trap.
- Callback exception.
- Malformed payload rejection.

Verify semantic identity of error classification and measure the cost.

Interop boundaries often behave differently on error paths, and a compiler that owns both sides should preserve them consistently.

---

### 61. **[P2] Broaden the correctness oracle corpus**

The current repeated LCG digest is useful but narrow. Add deterministic inputs covering:

- Signed integer limits.
- Floating-point infinities and NaNs.
- Unicode.
- Empty and large collections.
- Nested optional values.
- Struct padding.
- Endianness-sensitive values.
- Aliasing.
- Error values.
- Cyclic or unsupported structures where appropriate.

Use many fixed seeds and publish the corpus.

This makes the correctness contribution harder to dismiss as one checksum passing repeatedly.

---

### 62. **[P2] Add perturbation tests demonstrating oracle sensitivity**

Intentionally inject controlled faults in a test-only branch:

- Change one field.
- Truncate one list.
- Swap byte order.
- Alter one callback result.
- Corrupt a Wasm return conversion.
- Remove one wrapper registration.

Show that:

- Digest identity catches semantic corruption.
- Structural audits catch wrapper/manifest corruption.
- Ordinary timing checks would not.

This demonstrates why the oracle adds value beyond conventional benchmarks.

---

### 63. **[P2] Evaluate multiple compiler revisions**

Run the canonical suite on:

- A known older Jac release.
- Current revision.
- One revision containing a relevant interop optimization, if available.

Show:

- Whether semantic identity remains stable.
- Whether the benchmark catches an actual regression.
- Whether a real compiler change moves an intercept or slope.

A concrete historical regression case would significantly strengthen the “regression witness” contribution.

---

### 64. **[P3] Prototype one compiler decision using the measurements**

The paper argues that the compiler could choose placement or batching. Implement one small proof of concept:

- Native placement above a measured threshold, or
- Automatic batching above a static call count, or
- Pointer passing for structs above an ABI threshold.

Evaluate:

- Prediction from microbenchmark.
- Chosen policy.
- End-to-end speedup.
- Cases where the policy correctly declines optimization.

This would turn the paper from “measurement substrate” into a demonstrated architecture mechanism. It is high value but potentially large scope.

---

## Phase J -- Presentation and release

### 65. **[P0] Generate tables and plots directly from canonical JSON**

Do not hand-enter numbers into `paper.tex`.

The generator should create:

- LaTeX tables.
- PGFPlots coordinate files.
- Claim macros such as callback overhead and payload slope.
- Sample counts.
- Confidence intervals.

For example:

```latex
\newcommand{\CallbackOverheadUs}{...}
\newcommand{\PayloadRpcSlope}{...}
```

This prevents stale values and contradictions between prose, tables and figures.

---

### 66. **[P1] Add plots that expose uncertainty**

Recommended figures:

1. Callback paired-difference distribution by session.
2. Work-sweep lines with uncertainty bands.
3. Native-entry threshold close-up.
4. Payload time versus bytes with fit bands.
5. RPC component decomposition.
6. Cross-runtime ECDFs.
7. FFI cost by struct size and ABI class.
8. Cross-machine normalized comparison.

Avoid relying only on fitted lines without showing observations.

---

### 67. **[P1] Include a complete experiment matrix**

A concise appendix or artifact document should list:

| Experiment | Sizes | Calls | Warm-up | Timed rounds | Sessions | Machine |
|---|---:|---:|---:|---:|---:|---|
| Work sweep | 8–12 | 40 | defined | 30 | 5 | x86/ARM |
| Callback-count | 10–12 | variable | defined | 30 | 5 | x86/ARM |
| Payload | 16+ | 20 | defined | 15+ | 5 | x86/ARM |
| RPC concurrency | 7 | duration-based | defined | 5 trials | 3+ | x86 |
| FFI shapes | 5+ | large batch | defined | 30 | 5 | x86/ARM |

---

### 68. **[P0] Perform a clean-room reproduction**

Have someone who did not write the harness:

1. Clone the repository.
2. Follow only the artifact README.
3. Build dependencies.
4. Run the fast reproduction.
5. Regenerate one or more tables.
6. Compare checksums.
7. Record every undocumented step.

Fix all issues they encounter.

---

### 69. **[P1] Provide full and reduced artifact modes**

A reviewer-friendly artifact should offer:

```text
make check          # correctness oracle, a few minutes
make reproduce-fast # reduced timing experiment
make reproduce-full # all canonical experiments
make paper           # regenerate tables and PDF
```

Document expected runtime, storage and hardware requirements.

---

### 70. **[P0] Reframe the paper around results that remain robust**

A strong final story could be:

1. Compiler-owned boundaries enable exact twin construction.
2. The oracle verifies semantics across heterogeneous runtimes.
3. Controlled sweeps separate fixed cost from scaling cost.
4. Native placement illustrates work-dependent break-even.
5. RPC payload experiments illustrate fixed versus per-byte cost.
6. One realistic case validates the model’s prediction.
7. Cross-architecture runs show which conclusions generalize.

This is stronger than a collection of large but unstable ratios.

---

# Recommended minimum submission-quality experiment package

If time is limited, I would prioritize this exact package:

1. Freeze one revision and controlled environment.
2. Commit all scripts and canonical raw results.
3. Run five independent sessions.
4. Replace the callback claim with a call-count sweep.
5. Repeat the work sweep and reconcile the slope discrepancy.
6. Reanalyze payload uncertainty using fixed design points and raw rounds.
7. Record payload bytes and narrow the serialization wording.
8. Replace seven-sample cross-runtime results with controlled multi-session results.
9. Redesign no-op/scalar/struct/vtable FFI controls.
10. Run the central experiments on one ARM64 machine.
11. Add one typed-record payload experiment.
12. Add one realistic native-placement case study.
13. Generate every table automatically from canonical JSON.
14. Perform clean-room artifact reproduction.
15. Rewrite the abstract and conclusion only after all numbers are frozen.

If these succeed, the paper would move from **an interesting benchmark prototype with unstable performance claims** to **a credible, reproducible characterization paper with a strong correctness methodology and defensible performance models**.
