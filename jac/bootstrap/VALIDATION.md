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

## Outstanding validation

Run the normal precommit hook, then push and resolve required CI
checks until green. The original Linux build-kit and bootstrap jobs passed;
final-revision CI remains pending.
