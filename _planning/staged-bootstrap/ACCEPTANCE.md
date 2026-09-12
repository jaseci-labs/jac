# Staged compiler bootstrap

Replace live seed transpilation with a pinned prior Jac toolchain that builds
the current compiler as an ordinary, independently runnable compiled image.
Packaging consumes explicit build artifacts. The running compiler and target
compiler sources must remain isolated.

## Acceptance criteria

- [ ] Pin and verify the bootstrap compiler for supported build hosts; reuse
  existing toolchain acquisition infrastructure and reject incompatible inputs.
- [ ] Build all current compiler modules through the full compiler, including
  former seed modules, with explicit producer/target isolation.
- [ ] Provide independently runnable stage-1 and self-rebuilt stage-2 images.
- [ ] Use one boot-safe compiled-image loading contract; preserve integrity,
  runtime/format compatibility, traceback mapping, and native layout validation.
- [ ] Remove jac0, seed membership, seed-only spatial adapters, seed bytecode
  caching, seed freezing, and seed-specific publishing/analysis branches.
- [ ] Relocate retained jac0core responsibilities to their architectural owners;
  remove obsolete launcher compatibility aliases and bootstrap-only indirection.
- [ ] Make kernel, compiler image, stub catalog, launcher, and distribution
  explicit targets; packaging must not compile implicitly or write build outputs
  into compiler sources.
- [ ] Replace implicit compiler-source rerouting with explicit development image
  selection and an incremental compiler development workflow.
- [ ] Centralize artifact identity and compiler fingerprints; retain sound
  dependency invalidation and report stage timings/cache misses.
- [ ] Migrate runtime publishing and experimental JacPython dependency-image
  preparation off jac0 while preserving their supported behavior.
- [ ] Update CI/release workflows, documentation, and tests; retain language
  regression coverage when removing tests of obsolete bootstrap mechanisms.
- [ ] Validate toolchain isolation, stage-1 execution, self-rebuilding, packaged
  independence, native/runtime compatibility failures, and relevant suites.
- [ ] Address PR CI failures until required checks are green.

## Scope discipline

Retain the ordinary application importer, Python runtime, LLVM/native backend,
runtime dependency management, and artifact integrity checks. Their responsibilities
do not disappear with seed bootstrapping. Retire source-only bootstrap and old
launchers importing new source trees from the active architecture; the pinned
historical compiler is the explicit bootstrap starting point.

Refactors should consolidate existing infrastructure, preserve typing and clear
ownership, and avoid adding parallel loaders, compilers, or cache-key definitions.
Do not mark an acceptance criterion complete without validation evidence.
