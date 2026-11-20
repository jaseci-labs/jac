# Testing jac-scale

Scale code is the part of jaclang whose failures only appear when real
processes talk to each other: a gateway forwards to a service, a pod pulls a
binary, a deploy waits on a rollout, a second replica reads what the first one
wrote. A green unit test says almost nothing about any of that. This document
is the protocol for validating a change to `jac/jaclang/scale/**` so the result
means something.

It has three parts: the rig you must have before any result is trustworthy,
the kind of test a scale change earns, and the ladder you walk before opening a
pull request.

## 1. The rig

### 1.1 Build the binary from the branch under test

jaclang ships as one self-contained binary. A test run is only about your
change if the binary running it links your source.

```bash
cd jac && zig build -Ddev
```

`-Ddev` links the compiler from the checkout instead of bundling it, so edits
under `jac/jaclang/` take effect with no rebuild. Rebuild only when something
inside the binary itself changes (the launcher, `sitecustomize.py`,
`_jac_finder.py`, the bundled CPython).

Do not validate a scale change against a released binary. A release binary
carries the jaclang that shipped with it, so it will happily run your tests
against code that is weeks old and report success.

### 1.2 Prove the binary is serving your source

This is the step that silently invalidates whole sessions when it is skipped.
The dev-source override resolves in this order: an application's
`[dev] jaclang_source` in the nearest `jac.toml` wins over the binary's own
linked-source marker, and if that path is stale or does not exist there is
**no error**. The binary quietly falls back to its baked jaclang.

Two checks, both from the directory you will actually run from:

```bash
cd /path/to/the/app        # the app directory, not the jaclang checkout
jac --version
```

Expect the dev-mode banner naming your checkout:

```
jac dev mode - using compiler source at /home/you/jaseci/jac
jac 0.37.0  (Linux x86_64)
```

A bare version line with no banner means you are running baked jaclang and
every conclusion drawn from that run is about someone else's code.

The banner proves a path is configured. To prove that path is *the tree you
edited*, plant a marker: add a temporary string to a line on the boot path,
run the command again, and confirm the string appears. Remove it afterwards.
Version strings do not bump between commits, so they cannot do this job.

### 1.3 Re-pin the capability dependencies after every rebuild

The global site is keyed to the binary hash, so a rebuilt binary starts with an
empty one and scale imports fail with `ModuleNotFoundError`. Those failures
look exactly like flaky rig artifacts and have been misread as such. Re-install
the pins from `.github/workflows/ci.yml` (they mirror
`jac/jaclang/project/capabilities.jac`) after every rebuild:

```bash
jac install \
  "python-dotenv>=1.2.1,<2.0.0" \
  "prometheus-client>=0.21.0,<1.0.0" \
  "opentelemetry-sdk>=1.27.0,<2.0.0" \
  "opentelemetry-exporter-otlp-proto-http>=1.27.0,<2.0.0" \
  "apscheduler>=3.11.2,<4.0.0" "kubernetes>=34.1.0,<35.0.0" \
  "docker>=7.1.0,<8.0.0" "boto3>=1.40.0,<2.0.0" \
  "requests>=2.32.0,<3.0.0" "moto[s3]>=5.0.0" \
  --global
```

Take the list from CI rather than from this file if the two ever disagree: CI
is the one that gates merges.

### 1.4 Host requirements

The build fetches an LLVM slice and a full CPython, and the compiler suite is
memory-hungry enough that CI runs it in chunks. Budget several gigabytes of
free disk before starting, and do not run the toolchain build on a small
laptop VM. `ModuleNotFoundError`, `No bytecode found` and
`failed to import Jac test module` are all things a full disk says.

## 2. What a scale change earns

### 2.1 The trophy, not the pyramid

Weight the effort where scale actually breaks:

- **End to end** carries the most weight: a real `jac run`, a real deploy to
  a real cluster, a real request through a real gateway.
- **Integration** next: real objects wired to each other in one process, the
  registry with the middleware with the transport.
- **Unit** last, and only where isolated logic is genuinely intricate: a
  planner, a parser, a state machine, a retry ladder. A unit test on a
  three-line accessor is maintenance cost with no signal.

### 2.2 No mocks

No `unittest.mock`, no monkeypatched collaborators, no fake gateway objects. A
mock encodes the behaviour you assumed the collaborator has, which is the
assumption the bug lives in.

When a boundary must be stubbed, stub it with something real:

- an in-process HTTP server instead of a fake transport,
- a temporary Postgres instead of a stubbed store,
- a local cluster instead of a fake Kubernetes client,
- a fixture app under `scale/tests/fixtures/` instead of a synthetic config
  dict.

### 2.3 A regression test must fail before the fix

For a bug fix, write the test first and watch it fail on unmodified code, by
travelling the path the bug travelled. A test that asserts on internals can
pass on broken code; a test that never failed proves nothing about the fix.

Two honest exceptions, both stated plainly in the pull request rather than
papered over with a test that passes either way:

- **Deletions of dead code.** There is no wrong behaviour to reproduce. State
  what the deletion could have broken and how you checked that instead.
- **Defects that need a whole cluster to appear.** If the reproduction is a
  deploy, the deploy is the evidence: capture the failing run before the fix
  and the passing run after, and say which suites cover the seam.

## 3. The ladder before a pull request

Walk these in order. Each step assumes the rig from part 1.

**Step 0, static.** CI runs the formatter with lint rules, and the lint rules
are stricter than the compiler, so a file that runs fine can still fail the
build.

```bash
jac fmt --check --lintfix <changed files>
jac check <changed files>
```

Bare `--check` is not enough; it validates layout only. Fork pull requests do
not receive the CI autofix push, so a miss here is a red build.

**Step 1, targeted suites.** Run the suites covering the surface you touched,
one process per file, the way CI does:

```bash
jac test --jobs 0 jac/jaclang/scale/tests/<group>/test_<name>.jac
```

`--jobs 0` forces serial execution. Since 0.37 every command resolves its
worker count through one precedence chain -- `--jobs` beats `JAC_TEST_JOBS`,
which beats `JAC_JOBS`, which beats `[dev] test_jobs` in `jac.toml`, which
beats `[dev] jobs`, which falls back to one worker per core. Prefer the flag:
it is the only form that cannot be overridden by something already in the
environment. `JAC_TEST_JOBS=0` still works and is what CI sets.

CI runs six groups under `jac/jaclang/scale/tests/`, and they map to
surfaces: `apps/` for the fleet read from `[apps]` and the per-app scale
overrides, `microservices/` for the gateway, registry, routing and local fleet,
`server/` for serving and the admin API, `data/` for identity and persistence,
`deploy/` for manifests and targets, `misc/` for the rest. Every test file
lives in one of those five directories. `deploy/test_deploy_k8s.jac` is the one
that needs a cluster: it gates on `JAC_TEST_K8S` and runs on the cluster-backed
leg, not in the `deploy` group. Per-file isolation is not decoration: several
suites mutate process state.

**Step 2, the real command.** Run the CLI the user runs, as a subprocess, and
read what it prints. Most scale defects are visible here and nowhere else: a
silent fallback, a message that reports success while nothing is reachable, a
config key that never arrives. For serving changes this means a real
`jac run` against a fixture app; for local fleet changes it means a workspace
with `[apps.<name>] kind = "service"` entries run with `jac run <app> --fleet`
(or `[scale.gateway] colocate = false`) so the gateway and service apps really
come up.

`jac start` and `jac dev` are tombstoned. `jac run` carries the serve surface,
deploy moved to `jac scale deploy`, and the serve flags now precede the
filename because `run` passes everything after it to the script.

| was | now |
|---|---|
| `jac start` | `jac run` (server kinds), `jac run --serve` otherwise |
| `jac start app.jac --port 3000` | `jac run --port 3000 app.jac` |
| `jac start --dev` | `jac run --dev` |
| `jac start --api_port 8001` | `jac run --api-port 8001` |
| `jac start --scale --target aws` | `jac scale deploy --target aws` |
| `jac start --scale --dry-run` | `jac scale deploy --dry-run` |

**Step 3, a real deploy.** Any change to `deploy/`, the injector, manifests or
the rollout path needs a real cluster. Local kind or minikube is enough for
most of it; reserve a hosted cluster for what only it reproduces, such as
load-balancer addresses and storage classes.

```bash
jac scale deploy app.jac --dry-run --show-yaml   # manifests, no cluster
jac scale deploy app.jac --target kubernetes     # the real thing
```

`--dry-run` is worth running first on every manifest change: it reaches the
realizer and prints what `apply()` would create, which catches a wrong
topology before a cluster is involved. It is not a substitute for step 3,
because it never observes a rollout.

Check the axes your change can differ across, because they routinely disagree:

| Axis | Why it bites |
|---|---|
| monolith vs microservice | different gateway, different dispatch path |
| local vs kubernetes | different realizer, different lifecycle |
| kind vs a hosted cluster | ingress class, storage class, load balancer, node arch |
| embedded vs external database | provisioning runs or does not |
| single vs multiple replicas | anything holding process state breaks at two |

### 3.1 Cluster discipline

- Create your own cluster and name it after yourself, so ownership is legible
  from `kubectl config get-contexts`.
- Delete it in the same session that created it. Teardown is part of the task,
  not a follow-up.
- Never run against a cluster you did not create. Shared and production
  clusters carry other people's namespaces, and a broad delete has already
  cost this project an outage once.
- Clean up by namespace, never cluster-scoped resources.

## 4. What to write in the pull request

A validation section is evidence, so it names things that can be checked:

- the suites you ran, by file name, with their counts,
- what you exercised by hand, on what target, and what you observed,
- **what you did not run, stated plainly.**

The third line is the one that makes the other two believable. "Not run: the
k8s deploy suites, nothing in this change is reachable from the deploy path" is
a stronger sentence than silence, and it is how a reviewer knows where to look.

## 5. Traps that have cost real sessions

- **A stale binary.** A rebuilt branch with an old `zig-out/bin/jac` on `PATH`
  produces pods that crash-loop on imports the branch removed.
- **The dev-source override.** Covered in 1.2, listed again because it is the
  one that wastes a full day: `jac test` from inside the checkout can run your
  edits while `jac run` from the app directory runs baked jaclang.
- **Temp-directory subprocesses.** A test that shells out to `jac` in a
  temporary project runs the binary's baked jaclang, because the dev override
  resolves from the nearest `jac.toml` and a temp project has none. Use a
  linked dev binary, whose marker applies from any working directory.
- **Mutable image tags.** Nodes cache them. Testing an image change with
  `IfNotPresent` serves the old layer; push a new tag or set the pull policy to
  always.
- **Missing capability deps read as flakes.** See 1.3.
- **Stale client build artefacts.** Remove the app's `.jac/` directory before a
  run that must exercise a fresh client build.
- **Absolute timings on a shared box.** Burst-credit machines and cold image
  pulls swing totals by minutes. Compare per-step deltas, not totals.
