# Shared-core runtime split - progress

**Issue:** 6490 (framework-agnostic web codegen seam)
**Goal:** Split `client_runtime.cl.jac` into a framework-agnostic core + per-framework
JSX/router/form shims so a Solid build pulls in no React, while React/Preact reuse the core.
**Approach chosen:** Core split first, then pause for review before the Solid shim + build wiring + e2e.

## Status: Step 1 (core/React split) DONE + Step 2 (Solid shim) DONE

### Step 1 - completed changes

- **New** `jac/jaclang/runtimelib/client_runtime_core.cl.jac` (+ `impl/client_runtime_core.impl.jac`):
  the 34 framework-agnostic `@jac/runtime` symbols - auth (login/signup/SSO/token), walker &
  function fetch with the auto-cache layer, localStorage, API base URL, History-API navigation,
  global error reporting, and the zod-schema proxy helper. Imports **no** framework package
  (`react`, `react-router-dom`, `react-hook-form`, …); uses only ambient JS globals
  (`window`, `globalThis`, `fetch`, `JSON`, `Date`, `Reflect`, …). Keeping this file
  framework-free is what lets a Solid build avoid the React ecosystem.

- **Rewrote** `jac/jaclang/runtimelib/client_runtime.cl.jac` into a thin React/Preact shim:
  - `import from jaclang.runtimelib.client_runtime_core { navigate as _navigate, ... }` (34 aliased)
  - `glob:pub navigate = _navigate, ...` (34 rebinds) to **re-export** the full core surface so
    `@jac/runtime` stays a single app-facing module → no React/Preact golden churn.
  - Keeps the React-only surface: `__jacJsx` (React.createElement), react-router-dom bindings,
    react-hook-form + zod forms, `JacAwaiting` Suspense wrapper, error boundary.
  - React imports are remapped to `preact/compat` at bundle time via `FrameworkBackend.vite_aliases`.

- **Rewrote** `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` to hold only the 9 framework
  impls: `__jacJsx`, `useRouter`, `AuthGuard`, `JacAwaiting`, `ErrorFallback`, `errorOverlay`,
  `useJacForm`, `JacForm`, `__jacReactErrorHandler`.

- **Wired** `compile_runtime_utils` in `jac/jaclang/runtimelib/client/impl/compiler.impl.jac`:
  after compiling the shim, if `client_runtime_core.cl.jac` exists and the shim JS references
  `./jaclang/runtimelib/client_runtime_core.js`, compile the core, rewrite the specifier to
  `./client_runtime_core.js`, and emit `compiled/client_runtime_core.js` (+ source map).

- **Fixed** `jac/tests/compiler/test_client_codegen.jac` (`jac call function sends params directly`)
  to read `client_runtime_core.impl.jac` - `__jacCallFunction` moved to core.

### Re-export mechanism notes (validated empirically)

- `import:pub` → emits empty JS. **Unusable.**
- `include` → emits references but not definitions; not self-contained. **Unusable.**
- **Chosen:** explicit `import X as _X` + `glob:pub X = _X` rebind, one per symbol.

## Verification

Verified earlier (before the "don't run tests locally" instruction), all green:

| Suite | Result |
|-------|--------|
| `test_client_codegen` | 6/6 |
| `test_router` | 2/2 |
| `test_preact_backend` | 13/13 |
| `test_eject` | 36/36 |

### Open risk - NOT yet verified

`checker_jac_runtime_alias` (in `test_checker_pass.jac`) compiles
`import from "@jac/runtime" { jacIsLoggedIn, jacLogout }` and asserts **0 errors / 0 warnings**.
Its purpose is that imported symbols keep declared types (`jacIsLoggedIn -> bool`) instead of
decaying to `Unknown`. After the refactor those symbols arrive via a re-export rebind chain:

```
fixture → client_runtime.cl.jac  glob jacIsLoggedIn = _jacIsLoggedIn
        → import alias of core's  def:pub jacIsLoggedIn -> bool
```

The type checker must follow the glob-from-imported-function-alias to recover `() -> bool`.
The full `test_checker_pass` suite times out locally (~8 min, EXIT=124), so this needs CI or a
targeted run. (`Unknown` is lenient in return position, so it *may* still pass - but unconfirmed.)

**Recommended:** run `test_checker_pass` in CI as the authoritative gate.

## Step 2 - completed changes

- **New** `jac/jaclang/runtimelib/solid_runtime.cl.jac` (+ `impl/solid_runtime.impl.jac`):
  the Solid framework shim. Imports only `solid-js/h` (no React ecosystem package) plus the
  shared core, and **re-exports** the same 34 core symbols using the identical
  `import X as _X` + `glob:pub`/typed-`def:pub` rebind structure as the React shim - so
  `@jac/runtime` stays a single, framework-identical module. The one divergence is `__jacJsx`,
  which lowers to Solid's hyperscript runtime (`h(tag, props, ...children)`) instead of
  `React.createElement`: filters `null`/`undefined` children, honors the `unsafe_html` sentinel
  via Solid's `innerHTML` prop, and treats a null tag as an array fragment (no `Fragment` import).
  Solid's reactive primitives (`createSignal`, ...) are imported by generated component code
  straight from `solid-js` (per `SolidBackend.import_source`), not re-exported here. Router/form
  bindings are React-ecosystem-specific and remain a documented follow-up (contract §8).

- **Overrode** `SolidBackend.runtime_source_basename -> "solid_runtime.cl.jac"`
  (`backends/solid.jac` decl + `backends/impl/solid.impl.jac` body). Previously SolidBackend
  inherited ReactBackend's `"client_runtime.cl.jac"` - i.e. a Solid build would have pulled in
  the React-flavored runtime. `SolidBackend.vite_aliases` correctly inherits React's `{}`
  (no `react -> preact/compat` remap), since the Solid runtime imports no React package.

- **Added 4 tests** to `tests/compiler/passes/ecmascript/test_solid_backend.jac`:
  runtime basename/path selection (`solid_runtime.cl.jac` resolves + file exists), empty
  vite_aliases, and a static purity scan asserting the Solid shim + impl import **no**
  react/react-dom/react-router-dom/react-hook-form/react-error-boundary/@hookform package.

### Wiring verified (no change needed)

- `compile_runtime_utils` (`client/impl/compiler.impl.jac`) resolves the runtime via the
  backend-aware `resolve_client_runtime_cl_path()` and emits to `client_runtime.js`; the
  core-sibling emit keys off `client_runtime_core.cl.jac` in the parent dir - both framework-neutral.
- `client_surface.jac` delegates JSX factory / import source / required globals / runtime module
  to the active backend; Solid prepends `import {__jacJsx, __jacSpawn} from "@jac/runtime";`,
  both provided by `solid_runtime.cl.jac`.
- `client_bundle.impl.jac` `postinit` defaults `runtime_path` to `client_runtime.cl.jac`, but it
  is used only for `.parent` (same dir) and as a non-None guard - functionally correct for Solid.

### Verification

| Suite | Result |
|-------|--------|
| `test_solid_backend` | 19/19 (14 lowering + 5 new runtime-split) |
| `test_preact_backend` | 13/13 (no regression) |
| `test_backend_purity` | 2/2 (backend edits stay pure) |

The new tests: runtime basename/path selection, empty vite_aliases, a static no-React purity
scan, **and** a compile-and-link test that compiles the real Solid runtime (shim + `impl/`
annex) and asserts `__jacJsx`/`navigate` bodies actually link to JS (no `createElement`,
imports `solid-js/h`). React/Preact basename tests still assert `client_runtime.cl.jac`.

**Bug caught during verification:** the initial `solid_runtime.cl.jac` / `impl/solid_runtime.impl.jac`
writes left stray `</content>` / `</invoke>` tags at EOF, producing a parse error
(`Unexpected token '</'`) that the text-only purity scan and lowering tests did NOT catch - the
runtime silently compiled to an empty stub (`gen.js` len 0, empty `__jacJsx`). Fixed by
stripping the tags; the new compile-and-link test now guards against this class of regression.
A plain `prog.compile(file_path=...)` does NOT run the cl→JS pass or splice annexes for a
`.cl.jac`; the bundler path (`Jac.program.compile` + a fallback `EsastGenPass`, with
`impl_mod` spliced by `JacAnnexPass`) is the one that exercises the runtime end-to-end.

## Out of scope / follow-ups

- **npm publish**: `publish/impl/runtime_npm.impl.jac` still publishes the React runtime as the
  `@jac/runtime` npm package. A Solid-published package is a separate follow-up.
- Solid router/form parity (solid-router, a Solid form lib) - contract §8 documented gaps.
- Browser e2e can't run in this environment (no vite/node_modules) - gated by compile/ecmascript
  suites here + CI for the full checker/eject/preact suites.
