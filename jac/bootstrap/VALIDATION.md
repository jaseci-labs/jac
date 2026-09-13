# Staged bootstrap validation

Local validation uses macOS ARM64, Zig 0.16.0, and the checksum-pinned Jac
0.37.13 producer for the baseline measurements below. The integrated build
now pins the published 0.37.14 producer, which supports JIR format 26.
CI validates Linux separately. These measurements are local
observations, not estimates of cold CI speedup.

## Pre-integration baseline

Upstream introduced mandatory native JacPython and JIR format 26 after these
measurements. That merge is being validated; these results do not establish
acceptance for the final merged revision.

## Build and runtime evidence

- A clean stage-1 image compiled all 727 modules through the full compiler in
  1,263 seconds with zero module-cache hits. The complete distribution built
  successfully (18/18 Zig steps).
- The resulting binary verified its compiler manifest, loaded its native
  frontend kernel, and started without importing `jac0` or `jac0core`.
- Twenty focused compiler-image, dependency-cache, kernel, abstract-contract,
  class-field, and packaging tests passed against the built binary.
- The complete experimental JacPython distribution also built successfully
  (18/18 steps). Its binary verified the image and native kernel and compiled
  Python code without seed imports. Its source-built runtime passed the build
  graph's runtime smoke tests.
- The isolated website browser journey passed, including account creation,
  repository posting, comments, likes, channels, navigation, documentation,
  reloads, and browser-console checks.
- Native module-resolution, runtime-sharing, and Mach-O rebasing regressions
  passed. Mach-O validation covers both target architectures structurally and
  executes the matching host's executable and shared-library callbacks.

## Incremental build measurement

Command, run from `jac/` with an already built LLVM shim:

```sh
zig build -Dshim-bin=jaclang/compiler/backends/native/llvm/libjacllvm.dylib --summary all
```

Before environment normalization, an unchanged build reused all 727 modules
in 2.16 seconds but took 212.72 seconds overall: unrelated inherited process
environment changes invalidated the kernel, catalog, and packaging steps.

After normalizing the environment and ordering source inputs, the unchanged
full build took 4.22 seconds. All expensive compiler and packaging steps were
cache hits, even after changing `GITHUB_RUN_ID` and setting an invalid ambient
`JAC_COMPILER_IMAGE`. This is about 50 times faster for that warm local case.
The module cache independently reused all 727 modules in 2.13 seconds when the
outer build graph needed rebuilding.

## Self-rebuild and source analysis

Stage 1 rebuilt the native kernel, all 727 stage-2 modules, and the catalog.
The cold module phase took 1,829 seconds with zero cache reuse. Both isolated
image verification steps passed; the complete verification graph succeeded
with 23/23 steps. The stage-2 catalog evaluated 597 modules without failures.

The full source check using CI's ignore configuration passed 925 files and
reported six unknown-JavaScript-global errors in two client bridge modules.
Explicit client placement for those two source modules, using the existing
`[placement.pins]` configuration, resolved all six errors. Both files passed
when checked again. No checker suppression was added.

CI now preserves the small compiled-module cache for PR iterations as well
as main. The large runtime and binary caches retain their existing main-only
save policy. Restored modules still undergo producer and dependency validation.

## Mandatory native JacPython integration

After integrating upstream 0.37.14 (JIR 26), the pinned release built all 757
compiler modules. Stage 1 built the mandatory JacPython object through the
ordinary native backend, and the runtime builder consumed that object without
invoking a compiler. The combined installation and Stage-2 self-rebuild passed
all 26 build steps, including isolated image verification.

On this local machine with eight compiler workers, the initial Stage-1 module
phase took 476.93 seconds. A subsequent source revision reused 747 modules and
compiled ten in 21.10 seconds. Stage 2 rebuilt all 757 modules in 805.70 seconds.
These module-phase measurements do not predict total cold CI duration.

The full native suite passed 1,318 tests but exposed two upstream nogc ownership
bugs, stale subprocess/fixture paths, and a ctypes function-signature leak
between tests. After fixes, the focused native ownership/kernel suite passed
41 tests; the path/Mach-O/JIT suite passed 13. The packaged native rerun passed
1,470 tests with ten skips in 1,231.05 seconds.
The checker suite passed 80 tests, including lazy context-alias inference;
the previously failing client source check also passed. All 246 staged source
checks passed; the remaining precommit formatting corrections were applied.
Payload/graph tests passed 24 tests and packaged lazy PostgreSQL/literal tests
passed 20. Diagnostic delivery/registry tests passed 11 tests, and the
configuration-method check passed both cold and warm with the updated compiler.

The compiler-cache suite now passes all 35 tests, including exact cold/warm
compiler-tree diagnostics, hydration, invalidation, retained interface state,
and installed-interface relocation. Interface serialization uses a scoped
diagnostic context, and cache serving validates and replays the dependency
closure's diagnostic profiles. The checker/diagnostic suite passed 87 tests.

A later combined installation and self-rebuild again passed all 26 steps.
Stage 1 reused 672 modules and compiled 85 in 208.85 seconds; Stage 2 rebuilt
all 757 modules in 879.80 seconds. These are intermediate-revision results.

The packaged runtime suite exposed eager authority resolution and a deferred
scratch reset shared incorrectly between graph and identity stores. After the
fixes, a pinned executable with the updated image passed 690 runtime tests with
six skips in 193.76 seconds. Authority/permission/context tests passed 29 tests.

A runtime upgrade during testing also exposed unsafe stale-runtime collection.
A native integration test now replaces the executable while an old process is
alive, verifies its runtime survives, then verifies collection after exit.
It passed in 10.51 seconds; the associated source checks also passed. Validation
executables are pinned while their test processes are running.

The subsequent packaged installation passed all 20 build steps. Startup and
purge-command isolation passed all 12 tests, including cache-owner delegation
and preservation of unrelated runtime files.

The final packaged revision passed all 20 installation steps. Its incremental
image phase reused 752 modules and compiled five in 24.36 seconds. Testing that
exact binary passed 135 cache/checker/startup/runtime-upgrade regressions in
325.10 seconds and 690 runtime tests with six skips in 340.59 seconds.

## Downstream regression fixes

The final pre-fix Stage-2 graph passed 19/19 steps and rebuilt all 757 modules
in 800.02 seconds. The broader pass/ES suite passed 1,248 tests with five skips.

Broader compiler and runtime-support runs identified stale source-only subprocess
probes, macOS path assumptions, an invalid superclass call used by LSP completion,
and diagnostic deduplication that outlived a compile request. The fixes reuse the
compiled-image test helper, canonicalize workspace roots at the context boundary,
and scope diagnostic delivery to a compilation including its nested imports.
Focused regression runs passed 31 path/boundary tests, 47 workspace/LSP tests,
and 48 diagnostic/cache tests.

A symbols-only interface request could compile without producing its requested
interface. Fulfilling that request through the existing INTERFACE product reduces
the precompile fixture's cold pass count from 902 to 723, below the unchanged
760-pass limit. The warm run performs zero passes. All 41 cache/reparse tests
passed after this change, including exact cold/warm diagnostics and the assertion
that ordinary code generation does not encode interfaces eagerly.

The rebuilt downstream package passed all 20 installation steps and 80 focused
regressions in 98.99 seconds. Its Stage-2 verification passed all 19 steps,
rebuilding all 757 modules in 766.04 seconds. The broad top-level compiler suite
passed 1,093 tests with one skip in 1,002.58 seconds. Runtime-support suites
passed 1,294 tests with four skips in 571.00 seconds.

Client integration exposed a diagnostic formatter that compared unresolved
project paths against resolved source paths. The existing formatter now resolves
both before making the path relative; a symlink regression covers both directions
and preservation of outside-project paths. Client path/diagnostic tests passed
35 tests, and web development tests passed six. The full local client run also
includes Linux ELF assertions that cannot pass on macOS; Linux CI validates those
platform-specific assertions.

The client diagnostic package rebuild and isolated verification passed all 22
steps; its module phase reused 752 modules and compiled five in 13.47 seconds.
Native JacPython constants and code-object boundary validation also passed.
The client suite additionally exposed a macOS port probe that allowed wildcard
address reuse despite an active loopback listener. Disabling reuse in the shared
probe passed both existing port-selection regressions and the normal source check.

CI now checkpoints completed module compilation before the self-rebuild, retaining
that work when a newer push cancels verification. The final cache still includes
self-rebuilt modules, and trusted binary publication still follows verification.
The composite action parses and its consuming workflows pass actionlint with
the existing custom-runner label exception.

## Packaged downstream validation

Revision `5b14b0a01d` passed the combined installation and Stage-1/Stage-2
verification graph: 28 steps, with all 757 Stage-2 modules rebuilt in 768.85
seconds. An unchanged repeat completed in 18.30 seconds with compilation cached.
The exact packaged binary passed 41 client path/diagnostic regressions and both
port-selection regressions. The full CI source-check command passed all 941
inputs in 3,646.32 seconds.

The remaining equivalence lane exposed producer-owned interfaces being reused
as current analysis, lazy diagnostics discarded during interface encoding, and
packaged runtime methods excluded by a package-path native-lowering shortcut.
The updated analysis image passed 33 bootstrap/cache/npm tests, including the
negative cache-verification oracle. A cold/warm npm warning regression passed,
and the unchanged precompile work gate passed with interface verification enabled
in 41.95 seconds. The native import cleanup passed five strict regressions in 30.71 seconds,
including graph topology on Python/JavaScript/native, compiler-identity cache
invalidation, implementation-annex invalidation, and imports through a directory
symlink at a different depth. Native dependency keys now use the existing running
compiler identity instead of rescanning a partial source-file list. Generated
relative dependency paths are normalized before filesystem lookup.

## Packaged runtime and ownership follow-up

The complete local staged build passed all 28 install, compiler-image and Stage-2
verification steps. Stage 1 compiled 757 cold modules in 486.47 seconds, versus
604.54 seconds in the earlier comparable eight-worker build (about 20% less for
that phase). Stage 2 took 814.52 seconds under concurrent test load. These are
local observations, not a forecast for total CI duration.

The broad native/tools run passed 1,624 tests, with one assertion failure, one
worker crash, and 18 skips. The lifetime test that crashed under the C build-host
interpreter passed under the packaged runtime. Static archive linking exposed a
real runtime-location bug when selecting an external compiler image. Floor
lookup now uses the embedded interpreter's configured home, and selects the
complete OS/architecture target instead of accepting an unrelated host floor.
All seven static archive integration tests passed, including generated binary
execution and absence of dynamic library dependencies. All 11 floor-resolution
tests passed after the target-selection fix.

Compiler namespace resolution now respects a loaded parent's search path. The
six self-tree/namespace regressions passed; the deploy duplicate-type error was
removed (the affected test then skipped locally without Kubernetes installed).
Implicit void results are instances of NoneType, preserving rejection of the
NoneType class as a return value. The new regression and all 15 eager-spawn tests
passed.

MTIR generation now writes to the compilation's explicit JacProgram through the
existing host-pass infrastructure. All nine pass tests, including compilation
with no global runtime program, passed. The combined SSO and MTIR integration
rerun passed 38 tests, covering compilation-owned metadata, runtime imports,
serialized metadata, and typed SSO mocks. All five outbox tests passed.

The normal interface-cache suite passed 26 tests, including its corrupted-cache
oracle; the npm regression passed three tests with verification explicitly
enabled. An additional whole-suite globally enabled verification stress run was
stopped after over 33 minutes; it is not counted as passing.

## Verification history

The normal integration commit hook passed all 261 source checks in 1,738.67
seconds. The downstream compiler fix passed all 11 normal source checks; analysis
and native follow-ups passed ten and two checks respectively.

CI on preceding revision `5b14b0a01d` completed the Linux kit, Linux ARM64 and
macOS ARM64 native builds successfully. Linux kit Stage 1 took 2,222.54 seconds,
Stage 2 took 3,060.59 seconds, and warm materialization reused all 757 modules in
5.90 seconds. Both Stage-1 and final caches were saved. Total cold kit time was
about 120 minutes; Linux ARM64 completed in about 92 minutes. The runtime test
runner lost communication with GitHub without a test result. Downstream CI
identified the ownership and typing issues described above. Its cold-work
limit failure (795 versus the unchanged 760 ceiling) was followed by a passing
strict-verification run on the fixed compiler: 723 cold passes and zero warm passes.

Revision `90bdbacc82` passed all 28 staged build checks, 115 tests against its
Stage-1 image, and 32 native/ownership tests plus 97 primitive equivalence tests
with strict interface verification against its packaged runtime (one platform
skip). Packaged Jac sources matched the checkout.

## Compile-time alias cycle performance

The Stage-2 build exposed an import-alias cycle in compile-time evaluation.
The symbol guard ended before recursive alias evaluation, while the resolver's
16-hop cutoff repeatedly returned another unresolved alias. A 45-second profile
recorded 44,329 symbol evaluations from 40 name evaluations, with most time in
alias resolution. The complete profiled binding compile took 587.76 seconds;
that includes profiler overhead and is not a controlled wall-time baseline.

Commit `2b1cd40984` retains the existing guard for the entire symbol evaluation
and uses a visited-symbol set to terminate alias cycles without a hop cutoff.
The same LLVM pass-manager binding compiled with zero diagnostics in 1.68 seconds
and 1.91 seconds in two unprofiled runs. The second made 747 symbol-resolution
calls. Its bounded-work regression fails on the preceding compiler and passes
with the fix. A 40-module acyclic alias chain still folds correctly; all 21
compile-time operator/cache/determinism/type-parameter tests passed. Both normal
commit checks passed.

The complete staged rebuild passed all 28 steps. Stage 1 reused 754 modules and
rebuilt three in 171.23 seconds through the unchanged pinned producer. Stage 2
rebuilt all 757 modules in 450.70 seconds, versus 761.77 seconds in the preceding
local build: about 41% less time for that phase, with eight workers in both runs.
These observed local timings are not a prediction of total CI duration.

## Source contracts and runtime type values

The full source check completed 878 inputs: 875 passed and three failed in
1,234.62 seconds with eight workers. The failures were in byLLM telemetry,
provider dispatch, and the ES generation pass. The earlier two-worker check was
stopped at 25% to use the available local CPUs; it is not counted as completed.

ES generation now initializes its manifest and JSX processor in the pass
lifecycle, uses its existing backend resolver, and retains component-call ABI
metadata in the pass. Typed pattern/construction helpers replace overly broad
node annotations. Redundant module caching and unreachable main-module lookup
fallbacks were removed. Provider clients use SDK types; stream methods expose
iterator contracts, invocation IDs are declared fields, and the JSON HTTP
transport rejects unsupported streaming requests explicitly.

Runtime union values retain their existing type flags through inference,
substitution, identity and argument matching. They remain distinct from unions
of instance values. Callable guards narrow object values, and optional attribute
probes on object preserve unknown runtime values without permitting unchecked
direct access. These fixes use the existing type representation and prefetch
infrastructure.

Diagnostic compiler images passed all three previously failing source checks,
81 type-checker regressions, 44 ES generation tests, four runtime-type regressions,
and 82 provider/telemetry/streaming tests. The provider tests used a temporary
project environment with the same SDK version ranges as CI. Initial provider
runs without those dependencies reported missing-litellm errors and are not
counted as passing. The final staged rebuild is being verified separately.

CI on `90bdbacc82` completed all three platform builds successfully. Linux
Stage 1 took 2,243.23 seconds and Stage 2 took 3,099.97 seconds; subsequent warm
materialization reused all 757 modules in 5.14 seconds. Its superseded downstream run was cancelled after the next revision started. These precede the compile-time cycle and source-contract fixes.

Required checks and final-revision status are tracked on
[PR #9149](https://github.com/jaseci-labs/jac/pull/9149).

## Generic annotations and dynamic instance inference

The source-contract rebuild exposed runtime-union flags leaking into fresh
standard-library TypeVar bounds and constraints. TypeVar and ParamSpec now use
the existing recursive annotation-to-instance conversion, and generic inference
normalizes runtime union arguments before binding type variables. Two regressions
fail on the preceding diagnostic image and pass after the fix.

The broader source check also exposed dynamic indexing/iteration returning the
`Any` type object. These expression paths now return instance types, and dynamic
bitwise OR preserves `Any`. A loop regression reproduces the ELF linker's failure
on the preceding compiler. The updated diagnostic image passes the ELF linker
source check and 137 type-system tests (five skips), including all six runtime
value regressions. Fresh-catalog, staged-build and final CI verification remain
in progress; intermediate diagnostic images and incomplete runs are not release
acceptance evidence.

## SDK-backed provider contracts

With CI's SDK ranges installed, provider checking exposed ten response-shape
errors and a quoted legacy type alias. The message alias now uses native Jac
syntax and includes dictionary messages already accepted by the runtime. SDK
response and streaming boundaries use the existing cast infrastructure. All
three provider/telemetry/type modules pass checking with those dependencies,
and all 82 provider/telemetry/streaming tests pass in the updated compiled image.
The nine byLLM exclusions have been removed from the repository check gate.
The pinned stage-0 compiler also executes a native forward type-alias smoke test.

The full source check on the preceding diagnostic compiler finished with 877
passes and only the ELF linker failure in 1,846.53 seconds. The corrected compiler
passes that file and all 137 type-system regressions (five skips) with the fresh
catalog. The in-flight intermediate staged build installed and verified Stage 1
but stopped at 24/29 steps on Stage-2 compilation of `ifacecache`; that file also
passes with the current diagnostic compiler and fresh catalog. A complete build
from the settled sources is running; the intermediate build is not counted as a
passing self-rebuild.

## Runtime worker memory budget

The test runner recycled workers at an 8 GB default RSS ceiling but omitted that
ceiling when asking the shared pool to size automatic concurrency. It now follows
the existing checker integration: one helper supplies the same configured ceiling
to pool sizing and retirement. Explicit worker counts continue to take precedence.
The regression models a 16 GB runner, verifies default/configured ceilings and
retirement thresholds, fails before the fix, and passes afterward. All three
pool-sizing/recycling tests pass. This corrects a demonstrated budgeting mismatch;
it does not establish the cause of the earlier CI runner communication loss.

The complete byLLM directory additionally passes 241 tests (one skip). The actual
Stage-1 image, including its newly generated catalog, passes all six previously
failing source files with CI's provider SDK dependencies installed.

## Complete provider/compiler staged build

The provider/compiler revision passed all 29 install and verification steps.
Stage 1 reused 731 modules and compiled 26 in 188.07 seconds. Stage 2 rebuilt
all 757 modules in 390.74 seconds. Both stages generated catalogs with zero
evaluation failures (69.43 and 71.05 seconds) and passed image verification.
This includes all compiler/provider type fixes; the subsequent test-worker
budget change is undergoing its own final rebuild. CI status is tracked on the PR.

## Runtime integration follow-up

Single-worker test runs now use the shared recycling pool; explicit `--jobs 0`
retains in-process execution. Process-ID coverage fails before the fix and passes
afterward. Workers also run their own `atexit` handlers before retirement, without
running inherited parent handlers. Shutdown coverage fails on the preceding
compiler; five pool tests and eight pooled notification/worker tests pass afterward.

A native crash in the template tests exposed a duplicate dependency-verdict lookup
that skipped JIT dependency compilation. Imported functions now use the existing
native verdict resolver, including its pending state for cyclic imports. The cold
JIT regression fails before the fix; 21 focused and 272 broader native tests pass
afterward (three skips). That revision passed all 29 staged build steps: Stage 1
reused 749 modules and compiled eight in 181.12 seconds; Stage 2 compiled all 757
in 413.86 seconds. Both catalogs had zero evaluation failures.

The runtime sweep passed 1,590 tests before this Mac exhausted PostgreSQL shared
memory IDs. All five notification tests pass after stopping this task's database.
The continuation exposed the React harness omitting explicit client placement for
independently compiled browser dependencies; all three React behavior suites pass
with that corrected. Upstream's extended-import-bytecode regression and the other
ten application-preparation tests pass after normalizing its temporary path.
The four GNU-time integration tests require Linux and are left to their CI lane.
Final rebuild, remaining runtime tests, and latest-head CI remain acceptance gates.

### Dependency analysis and child-process follow-up

CI run `34773029168` passed Linux build-kit, Linux ARM, macOS ARM, and the
native backend suite. Its runtime lane passed 1,987 tests and exposed two
sealing failures caused by checkout shadowing in the precompiler child.
The shared CLI command constructor now pins the running image; sealing,
service-spawn, and MCP regressions pass together (107 tests), including a
seal with `JAC_COMPILER_IMAGE` removed.

The current diagnostic image passes 78 cache, context, timing, and comptime
regressions (one skip). Interface requests now consult the existing product
ledger to avoid recursively serializing complete dependency interfaces.
Source-only dependency records retain source fingerprints and diagnostics;
actual symbol reads record dependency edges. The new regression covers an
unneeded leaf staying unloaded, zero-pass warm replay, later demand for the
leaf, and invalidation after its member type changes.

A cold six-app scaffold check passes in 93.46 seconds locally, versus
326.02 seconds before this scheduling change. This is not yet acceptance
of CI's 90-second/2,560 MiB gate: macOS `time` reported 4,880,793,600 bytes
maximum RSS. Packaged rebuild and CI verification remain required.

### Reuse analysis across independent check entries

Revision `205360c5cc` passed the complete compiler toplevel suite locally:
1,098 tests passed and one was skipped in 793.99 seconds. Its packaged
executable passed 22 image, precompiled-interface, sealing and workspace
checks without an image override.

The follow-up removes the requested entry path from compilation-context
identity. App identity, project root, placement and compiler options still
separate contexts; the entry path remains request information. A regression
fails before this change when a second entry recompiles its shared dependency,
then passes with reuse and still detects an edited dependency's return type.
The compiled diagnostic image passes 101 workspace, diagnostic, interface,
scheduling and compile-time regressions. A twelve-file check probe generated
26 interfaces instead of 60 and took 2.76 seconds instead of 6.33 seconds;
these local measurements do not establish a CI-wide speedup.

Bundling current-compiler analysis metadata was also tested without changing
the production build. It did not meet the scaffold time or memory limits;
consumer diagnostic profiles still require contextual analysis. No additional
metadata-generation stage or relaxed performance budget was added.

Revision `1478a13517` passed all 28 staged build and verification steps.
Stage 1 reused 746 modules and rebuilt 11 in 58.12 seconds; Stage 2 rebuilt
757 modules in 417.86 seconds. Both catalogs reported zero failures.
Repository-wide checking with CI's exclusions passed 941 files in 1,750.12
seconds. The fresh scaffold check remained above its CI budget at 92.27
seconds and 4,867,653,632 bytes maximum RSS on macOS.

### Native object reproducibility

Temporary snapshot paths appeared in native global-initializer names and
assertion strings, changing `jacpython.o` and invalidating the runtime cache
without changing the Python compiler implementation. Explicit source-prefix
mapping now belongs to compiler options and the existing compilation scope;
the native symbol and assertion emitters consume that shared mapping.

Two independent processes built the full native Python object from different
snapshot directories and emitted identical 4,060,392-byte objects, SHA-256
`c1d1deb6949a3a2e63cf4b3e7aa04d3425630936bf0e4b44c076397afd927b8a`.
The runtime builder took 93.12 seconds to build with the first object, then
accepted the second object through its unchanged cache validation and passed
runtime smoke checks in 10.61 seconds. This is a local component measurement,
not a forecast of whole-CI duration.

Native regressions cover byte-identical object emission, mapped assertion
locations, default source paths, longest-prefix matching, path-component
boundaries, scoped restoration, option cloning, and cache-key separation.
The checksum-pinned prior compiler also successfully loaded the updated
bootstrap recipe; current-only options are passed as typed keyword arguments.
Revision `dc6cb86ef0` passed all 28 staged build and verification steps.
Stage 1 compiled 757 modules in 479.38 seconds; Stage 2 independently rebuilt
757 in 402.01 seconds. Both catalogs reported zero evaluation failures.
The actual staged build emitted the same native Python object hash recorded
above. The complete native suite passed 1,477 tests with ten skips in 1,290.07
seconds. The packaged executable passed 24 image, interface, packaging,
workspace and native reproducibility regressions in 34.25 seconds; SHA-256
`23caac329aed7327bbc6415740cc94b3ac88e523691d475d94f10ebd82694843`.

The follow-up applies the same source mapping to the two native debug-metadata
emitters, preserving synthetic module names. Twenty-five focused tests passed,
including byte-identical objects with debug information, shared libraries,
RC debug behavior and cyclic imports. Latest-head CI remains required.


Revision `7ff42f86bc` passed all 28 staged build and verification steps after
the debug-metadata change. Stage 1 reused 753 modules and rebuilt four in
170.38 seconds; Stage 2 rebuilt 757 modules in 388.51 seconds. The native
Python runtime reused content key `092f7a8c1d8ceebb`, and packaging reused its
compressed dependency layer. This confirms cache reuse after a compiler edit
through the full graph.

### Diagnostic ownership collection

A fresh scaffold profile exposed repeated scans of the diagnostic ledger for
every transitive module. The ledger now collects diagnostics for a batch of
modules, checks each distinct owner once per batch, and preserves module and
annex ordering. It keeps no persistent index that can become stale after ledger
edits. The shared annex predicate rejects ordinary unrelated paths before
splitting them; 22,500 path-pair comparisons matched the previous behavior.
Twenty-two diagnostic, interface, workspace and compiler-tree regressions passed.

Sequential fresh six-entry scaffold checks with no full build competing for CPU
passed in 91.94 seconds before the change and 89.72 seconds afterward. Process
wall time was 92.75 versus 90.33 seconds; maximum RSS was 4,885,708,800 versus
4,899,880,960 bytes on macOS. These results do not establish compliance with the
unchanged CI wall-time and memory limits. Latest-head CI remains required.


The diagnostic follow-up passed the complete compiler toplevel suite:
1,102 tests passed, one skipped, in 581.62 seconds. All 28 staged build and
verification steps passed. Stage 1 reused 722 modules and rebuilt 35 in
199.98 seconds; Stage 2 rebuilt 757 in 383.88 seconds. Both catalogs reported
zero evaluation failures, and the native runtime reused its existing content
cache. The packaged executable passed 28 focused regressions in 36.56 seconds;
SHA-256 `c227dc9183d5ccc4866567f4eb4a0bb7c9c68adc754076f18fdd1a39239d121f`.

The final packaged compiler also passed the repository-wide CI source-check
selection: all 941 files passed in 1,628.97 seconds with two workers. The
performance budgets and latest-head CI acceptance criterion remain unchanged.
