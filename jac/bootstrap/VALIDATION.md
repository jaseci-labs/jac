# Staged bootstrap validation

Local validation uses macOS ARM64, Zig 0.16.0, and the checksum-pinned Jac
0.37.13 producer. CI validates Linux separately. These measurements are local
observations, not estimates of cold CI speedup.

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

## Outstanding validation

Push the final revision and resolve required CI checks until green.
