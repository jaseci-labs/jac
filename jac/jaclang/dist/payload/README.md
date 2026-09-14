# Payload construction and reuse

`assemble.mk_payload` stages the compiler, builds or restores the native kernel,
installs the pinned runtime wheels, precompiles and seals the package, compiles
Python sources, and combines the dependency and Jac compression frames.
Each producer validates its own inputs and completed outputs before reuse.

## Identities and publication

| Product | Inputs and validation | Owner |
| --- | --- | --- |
| CI binary and source snapshots | Tracked Git tree records captured once before restore or build mutations | `scripts/build_cache_keys.sh`, shared `build-inputs` action |
| Module products | Compiler/toolchain, source and annex contents, compilation context, dependency interfaces, compile-time input contents | Compiler JIR and `IfaceRegistry` |
| Native kernel and layout | Compiler sources and type stubs, shim contents, host, interpreter, codegen options, ancestor project configuration, payload producer | `ArtifactStore` |
| Stub catalog | Compiler source identity, actual stub contents, Python/platform, catalog format, requested module selection | Catalog builder and its manifest |
| Bootstrap products | Existing jac0 bytecode identity, full precompile identity, dependency facts, debug-source mode | Bootstrap importer and seed sealer |
| Runtime dependency installation | Hash-locked requirements and build constraints, target interpreter, bundled pip wheel, native compiler/SDK where required, staging/archive producer | `ArtifactStore` |
| Python bytecode | Target interpreter, source contents, normalized filename, optimization mode | `ArtifactStore`, standard `py_compile` |
| Compressed frames | Deterministic tar contents, compression parameters, interpreter | Existing frame cache with decoded-content verification |

The broad compiler input set remains conservative. Its source authority lives in
`bootstrap_manifest.py`; both the compiler and the pre-build cache-key script use
that definition. Generated outputs never participate in tracked CI identities.
Kernel construction writes its completed library and layout to the staged build,
without copying them back into compiler sources.

`ArtifactStore` uses the common `FileLock` and `atomic_write` primitives. Its
manifest is published last and names the content hash and mode of every member.
Restoring a pair validates both members before replacing either destination.
Inactive artifact directories expire after 30 days; locked producers are retained.
Lock files keep stable inodes so concurrent processes continue to coordinate.
JIR publication uses the same locking primitives around its section merge.
Catalog build receipts and locks remain in the producer cache; runtime staging
excludes them so timing and cache-hit metadata cannot change payload bytes.

CI cache entries are immutable. The payload cache therefore restores by a source
prefix and saves changed contents under a new run snapshot, including when the
restored outer cache lacked a required inner artifact. The producer remains the
authority for compatibility after a prefix restore.

## Environment and deterministic staging

Kernel construction and catalog construction use their explicit bootstrap
settings. Module precompile and seal processes select the staged native kernel
when its library and layout exist; otherwise they select the bootstrap frontend.
The kernel loader performs its usual compatibility checks.

`python_dependencies.txt` pins wheel versions and SHA-256 hashes. Installation
uses the target interpreter's bundled pip wheel with hash verification, without
upgrading the build interpreter's environment. Watchdog can use its verified
source distribution when a compatible wheel is unavailable, including Python
3.14 on macOS. Pip's isolated build environment uses the verified setuptools and
wheel inputs in `python_build_constraints.txt`; native products also identify the
compiler, SDK, interpreter build flags, and requested environment flags. Cold
producers disable pip's wheel cache, fix `SOURCE_DATE_EPOCH`, and omit native debug
paths; completed installations reuse the verified artifact cache.
Generated command wrappers are
removed because they embed temporary paths; runtime tools run as Python modules.
The floor's existing `site-packages` is excluded from staging. Python bytecode
uses unchecked source hashes and `/jac-rt/` filenames. A distinct target
interpreter compiles all cache misses in one subprocess; unchanged files still
reuse their completed bytecode.

## Measurements

Set `JAC_BUILD_METRICS` to choose the producer report path. Otherwise the report
is written beside the payload as `<output>.metrics.json`, including on failure.
CI uploads `jac/.build-metrics` as `build-kit-measurements`.
Standalone precompilation writes detailed work records only when
`JAC_PRECOMPILE_METRICS` names an output file. Packaging requests that report in
its build directory and incorporates it into the producer report. Timings,
worker identities, and temporary paths never belong in the shipped
`_precompiled` tree or a content-addressed application bundle.

Stage transitions and cache outcomes atomically checkpoint the measurement file.
An interrupted build retains completed stages and lists the stages still active
at the last checkpoint, even when the producer cannot run its final cleanup.
Precompilation checkpoints its existing worker report before dispatch, every 32
completed jobs, and during cleanup. Its `complete` field distinguishes an
unfinished checkpoint from a completed run; packaging rejects unfinished reports.
While packaging runs, this report lives beside the main measurement file as
`<report>.precompile.json`, where CI also retains it after a hard timeout. A hard
termination can lose in-flight jobs and up to 32 completed job records.

- `stages` records wall time, process CPU, waited child CPU, process peak RSS,
  and success. These stages are inclusive; do not sum nested entries.
- `cache_outcomes` records producer hits, misses, and compiled/reused file counts.
- `compilation` includes the dependency plan, compiler and Python identities,
  worker configuration, per-job PID/setup/time/RSS, and per-file compiler work.
  `wall_seconds` and `cpu_seconds` measure the job itself. The separate
  `retirement_seconds` and `retirement_cpu_seconds` include the retirement hook's
  collection and session eviction, even when the worker survives. `rss` is the
  job's final RSS; `rss_after_retirement` reports it after the hook. Inline jobs
  do not invoke retirement and report zero retirement time.
  Each job completes one module. Cycle members run in order behind their external
  dependency barriers, so progress, failure handling, and worker retirement remain
  available between members of even the largest cycle.
- Compiler `exclusive_seconds` subtracts nested phases and passes, including
  dependency work. `frontend:parse` records parser work. Discovery trees transfer
  into their consuming module hub without copying; compatible later products
  reuse that hub. Product/cache events distinguish reuse from computation.
  `frontend:collect` records bounded collection of discarded syntax.
  `frontend:dependencies` records import discovery and resolution.
- `compilation.dependency_plan` reports planning duration, validated dependency
  hits, parsed/retained syntax counts, and preparation time before worker launch.
- `compilation.seal` records compiled, reused, and bytecode-only bootstrap reuse.
- `compilation.startup` and `compilation.seal.startup` separate process launch
  through the first Python statement from compiler/CLI initialization through
  precompile entry. Worker setup and replacement remain in the worker records.

Stage RSS is the process high-water mark, not a sum of live objects or a peak
across the entire process tree. Worker RSS records the current resident set on
Linux and macOS, with peak RSS as a fallback on other platforms. Child CPU includes
children already waited for; it is not a measure of parallel wall time.

For comparisons, keep the source revision, machine, Python/shim/kernel inputs,
worker count, and session/retirement budgets fixed. Run payload construction with
fresh producer and precompile caches, then preserve only selected artifacts for
a partially warm run, then repeat with all caches present. Use a fresh output
path so the enclosing Zig output cache does not skip the producer being measured.
Record the cache state with each report. Compare executable behavior and final
artifacts as well as durations; log gaps in buffered Zig output are not timings.
