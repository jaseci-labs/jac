# The Artifact Router

Every optionally built or native part of Jac, and every tool an app build
provisions, is one entry in one registry, resolved by one router. This page
records that design: `jac0core/artifact_registry.jac`, `artifacts/model.jac`,
`artifacts/router.jac` and `artifacts/kit.jac`, plus the `jac native` command
that drives them.

## Kinds and release policy

An entry is one of two kinds:

| Kind | Rule | Examples |
|---|---|---|
| **Accelerator** | It has a floor that gives the same results, only slower. Use the artifact when it is built and current; otherwise run on the floor and say so. | the compiler kernel (floor: the bytecode compiler), the stub catalog (parsing typeshed), the precompiled bundle (compiling from source), JacPython (CPython), js_engine (bun) |
| **Capability** | It has no floor. Without it the feature does not exist, and asking for it fails with the command that builds it. | the LLVM shim, the C floor archives, musl, wasm libc, llvm-cbe, bun, Postgres, Node, the JDK |

Separately, every entry declares a **release policy**:

- `required`: a release carries the built artifact, and `jac native status
  --require release` fails without it.
- `floor`: the release ships the floor on purpose. Today that is JacPython
  (releases ship CPython) and js_engine (releases ship bun). Promoting one
  flips it to `required`.
- `on-demand`: not part of a release (llvm-cbe, and your app's Postgres and
  toolchains).

## Resolution

`resolve(name)` decides every entry the same way and caches the answer for
the process:

1. **Being built.** While an artifact builds, it and everything that
   `consumes` it resolve to the floor, in-process and in the build's children
   (the build marks travel in the handoff record).
2. **Left out.** If the sealed image this process runs, or the kit it runs on,
   lists the artifact in its manifest's `omits`, it runs its floor quietly.
3. **Sealed image.** A sealed process takes its own copy or its floor. It
   never looks at a checkout.
4. **Checkout.** The artifact in the source tree, accepted only when its
   recorded inputs match the sources now. The kernel's sidecar lists every
   unit; the shim's record holds the hash of `native/`, `build.zig` and the
   LLVM pin, plus its target.
5. **Kit.** A checkout rerouted onto a kit's interpreter loads the kit's copy
   where the kit keeps it, when that copy was built from these sources.
   Nothing is copied.
6. **Floor.** Otherwise the process says so once on stderr: what moved, and
   the `jac native build <name>` that fixes it. `floor`-policy entries stay
   quiet, because shipping their floor is the plan.

Resolution never builds. `require(name)` is `resolve` for callers that cannot
run without the artifact: a capability on its floor raises
`ArtifactUnavailable` naming the fix. The exception is an on-demand entry
marked `provision` (Postgres, Node, the JDK, patchelf). `require` installs
it once with a notice, and refuses instead when the project sets `[network]
offline = true`.

## Building

`jac native build [names] [--force] [--exact] [--release]` builds in
dependency order (`requires`). It skips what is current unless `--force` is
given, and checks each result by resolving it again. `--release` builds
exactly the release set, and an artifact this host cannot build is then an
error. Builds publish atomically: a private file, then the artifact and its
record under one short lock. Readers never lock.

`jac native status [names]` prints, for each entry, its kind, its policy, what
this process runs and why. Given one name, it also prints every tier's
verdict and every input that moved. `--require` asserts:

- `--require release`: every `required` artifact is in place and every
  shipped floor is present. Releases run it.
- `--require kit`: the same, less what this image declares it omits. Every
  CI kit runs it, in build-kit and in every reroute lane's warm step.
- `--require a,b`: just those.

## The handoff record

A process tree runs one compiler. Only the top-level process reads `[dev]`
from the nearest `jac.toml`. What it decides travels to its children in one
internal JSON record, `JAC_HANDOFF`: the compiler source (empty means
bundled), `exact`, build marks and the cache mode. A child is never asked to
judge again. The record is written by jac for its own children and is never
a user setting. `jac0core/handoff.jac` owns it, and `_jac_finder.py` keeps a
documented boot-time mirror.

## CI

- **Sealed and reroute lanes.** A sealed lane runs the kit's own compiler: the
  `jac-kit` action's `sealed: "true"` drops `[dev] jaclang_source` from the
  checkout (`seal-checkout`). A reroute lane keeps it and runs the checkout on
  the kit.
- **Pull-request kits.** A pull request's kit leaves the kernel out unless the
  pull request carries the `native:kernel` label. The `setup-jac` action sets
  `JAC_KIT_OMIT=kernel` for such a build; the seal reads it (`pr_kit_omits` in
  `artifacts/kit.jac`) and records it in `omits`.
- **Release kernels.** `build-binaries.yml`'s `kernel` job builds every leg's
  `kernel@<osarch>` on x86 Linux, and each leg's seal adopts its own
  (`zig build -Dkernel=DIR`); see "One builder, every target" in
  native-units.
- **The shim.** `zig build` reuses an in-tree shim whose record matches the
  current inputs and target. CI restores its cached shim there, and `zig build
  adopt-shim` records a content-addressed prebuilt one.

## Adding an entry

Subclass `Artifact` (or `ToolArtifact` for a provisioned tool) next to the
code that uses the artifact. Give it a name, kind, policy and summary
(plus a floor for an accelerator), and implement `probe_checkout`,
`checkout_path` and `build`. Add `probe_sealed` and `probe_kit` when a sealed
image or a kit carries it. Then register its import path in `ARTIFACTS`.
Callers go through `resolve` or `require`. A module that searches for,
version-checks or falls back from an artifact on its own is the bug this
design removes.
