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
in 41.95 seconds. Native import cleanup is still undergoing validation.

## Outstanding validation

The normal integration commit hook passed all 261 source checks in 1,738.67
seconds. The downstream compiler fix commit passed all 11 normal source checks.
The latest completed Linux installation passed all 21 build steps, with 757 cold
modules compiled in 2,203.82 seconds, before a newer push cancelled verification.
The new analysis/native import changes require a final packaged self-rebuild and
normal commit checks. Required CI checks on the final revision remain pending.
