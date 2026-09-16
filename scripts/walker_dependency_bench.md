# Native walker dependency inspection experiment

Dependency inspection prevented known conflicts before body execution in every
case below. It did **not** improve elapsed time on this workload: both speculative
modes were slower than serial execution, and dependency scheduling was slower
than the original speculative scheduler. These measurements are an implementation
baseline, not a speedup claim or a CI performance threshold.

Measured on 2026-09-16 using the working tree based on `3c3a7ffb2`, Linux x86-64,
glibc 2.42, an AMD Ryzen AI 7 350, 16 logical CPUs and 4 workers. All binaries use
Native AOT, RC, opt=2 and the host libc. The local LLVM shim was rebuilt from the
repository's LLVM 22 headers and libraries. Other test runs had finished before
measurement.

The [fixture](../jac/tests/compiler/backends/native/fixtures/perf_walker_dependencies.jac)
has 16 entry calls. Each follows two typed, directed hops through a filtered
intermediate node and updates its target values using a scalar arithmetic helper.
Topology stays fixed during traversal. With 16 target pools, no calls share
targets; with 4 pools, four calls share each pool; with 1 pool, every call shares
the same targets. Query size is the number of final targets per call. Body steps
are arithmetic iterations per target.

Each mode receives one warmup and five measured executions per case, in
alternating mode order. Times below are medians in milliseconds, including
process startup, graph construction, traversal, commit and output; compilation
is excluded. Every execution verifies the same final-field/report checksum
across all three modes. Inspection time is the median coordinator time spent
running inspectors and collecting their access descriptors. It excludes
dependency-index construction, worker execution and commit.

| Pools | Query size | Body steps | Serial ms | Original speculation ms | Dependencies ms | Attempts, original/new | Validation failures, original/new | Inspection ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 16 | 1 | 20,000 | 1.82 | 7.09 | 9.63 | 16/16 | 0/0 | 1.45 |
| 16 | 1 | 200,000 | 14.66 | 37.84 | 40.12 | 16/16 | 0/0 | 2.08 |
| 16 | 4 | 20,000 | 6.44 | 19.23 | 22.30 | 16/16 | 0/0 | 2.34 |
| 16 | 4 | 200,000 | 49.64 | 100.60 | 103.98 | 16/16 | 0/0 | 2.12 |
| 4 | 1 | 20,000 | 2.27 | 7.01 | 9.53 | 16/16 | 0/0 | 1.82 |
| 4 | 1 | 200,000 | 13.03 | 29.26 | 31.85 | 16/16 | 0/0 | 1.90 |
| 4 | 4 | 20,000 | 5.78 | 14.47 | 18.12 | 16/16 | 0/0 | 1.74 |
| 4 | 4 | 200,000 | 48.47 | 97.23 | 103.21 | 16/16 | 0/0 | 2.02 |
| 1 | 1 | 20,000 | 2.05 | 10.29 | 19.72 | 30/16 | 8/0 | 4.72 |
| 1 | 1 | 200,000 | 12.54 | 61.54 | 95.09 | 30/16 | 8/0 | 5.56 |
| 1 | 4 | 20,000 | 5.90 | 28.85 | 50.51 | 30/16 | 8/0 | 4.64 |
| 1 | 4 | 200,000 | 49.35 | 242.62 | 330.76 | 30/16 | 8/0 | 7.34 |

All dependency runs had 16 successful commits, zero unknown inspections and zero
validation failures. There were 40 inspections with 16 or 4 pools, and 136 with
1 pool. Dependency deferrals were respectively 0, 24 and 120. Peak body
concurrency was four for independent pools and one when all targets overlapped.
Rechecking every unstarted call costs more as dependency chains grow. The
original scheduler also falls back to uninstrumented serial execution eight
times in the fully shared cases, while the new scheduler executes all 16 bodies
with speculative tracking. Fewer body attempts alone therefore do not imply
less total work or lower latency.

The [raw samples and counters](walker_dependency_bench.results.json) contain the
fixture SHA-256, all measured elapsed times, inspection samples and checksums.
Reproduce with the [benchmark runner](walker_dependency_bench.jac):

```sh
jac run scripts/walker_dependency_bench.jac --rounds 5 --output results.json
```

Correctness verification covered dependency ordering and retained results,
mutable filters and node-reference fields, aliases, helpers, unknown branches,
reports, visits, exceptions, topology fallback and the existing RC/nogc/managed
walker regressions. The selected suite had 197 passes and one existing failure:
`test_osp_transient_graph` measured 1475 bytes per edge against a 1400-byte bound.
An isolated, unmodified HEAD checkout reproduced the same 1475-byte result.
The Jac formatting check, 104-module seed-manifest check, Markdown lint and
release-fragment validation passed. Only Linux x86-64 was exercised locally.
