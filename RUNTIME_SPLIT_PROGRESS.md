# Shared-core runtime split - progress

**Issue:** 6490 (framework-agnostic web codegen seam)
**Goal:** Split `client_runtime.cl.jac` into a framework-agnostic core + per-framework
JSX/router/form shims so a Solid build pulls in no React, while React/Preact reuse the core.
**Approach chosen:** Core split first, then pause for review before the Solid shim + build wiring + e2e.

## Status: Step 1 (core/React split) DONE + Step 2 (Solid shim) DONE + Step 3 (Solid router/form parity) DONE + Step 4 (Solid file-based-routing entry) DONE + Step 5 (backend-aware runtime npm publish) DONE

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

## Status: Step 3 (Solid router/form parity) DONE

The contract §8 follow-up "Router and form bindings are React-ecosystem-specific" is
now closed at the runtime-shim level: `solid_runtime.cl.jac` exposes the same router /
form / error-async surface as the React shim, sourced entirely from Solid-native
libraries, so `@jac/runtime` stays framework-identical for app code and a Solid build
still resolves **no** React-ecosystem package (the purity scan in `test_solid_backend`
still passes unchanged - the new imports `@solidjs/router` / `solid-hook-form` /
`solid-js` / `zod` are not on the forbidden list).

### Step 3 - completed changes

- **Router** (`@solidjs/router`): re-exports the directly-compatible primitives
  (`Router`, `useNavigate`, `useLocation`, `useParams`) and provides thin adapters for
  the components whose prop shape diverges from react-router-dom:
  - `Link` → `A` (`to` → `href`), `Navigate` (`to` → `href`; Solid always replaces),
    `Route` (`element={<C/>}` → `component={() => <C/>}`), `Routes` (no Solid
    equivalent - passthrough of children), `Outlet` (no Solid export - renders any
    children handed in).
  - Composed `useRouter` (returns the identical `{navigate, location, params, pathname,
    search, hash}` dict as React) and `AuthGuard` (mirrors the React body, swapping
    `__jacJsx(ReactRouterOutlet/Navigate)` for the Solid adapters).
- **Forms** (`solid-hook-form` + `zod`): `useJacForm` builds a `createForm` controller
  (a near-drop-in for react-hook-form's `useForm`); `JacForm` is ported from the React
  shim with the Solid divergences handled in place:
  - `form.watch(x)` → `form.values()[x]`; `formState.isDirty` is an accessor
    (`isDirty()`); there is no `formState.isSubmitting`, so a local `createSignal`
    tracks it around an inner **`async def submitHandler`** (a lambda can't carry
    `await`) that `handleSubmit` awaits; `useState` → `createSignal`.
  - Per-field error messages stay reactive: `renderField` passes `errors[fieldName]`
    **inline** at the `renderInput` / `renderError` call sites (not via a captured
    const), so the read lands inside the thunks `lower_view_expr` injects and tracks
    the `formState.errors` store.
  - **`__zodResolver`** is hand-rolled (`schema.safeParse` → `{values, errors}` in
    react-hook-form's resolver shape) so **no `@hookform/*` package** is needed -
    declared in the shim (non-pub) so its impl-annex body is spliced.
  - `JacSchema = __createJacSchema(z)` re-exported, exactly as the React shim.
- **Error / async**: `JacClientErrorBoundary` presents react-error-boundary's
  `{FallbackComponent, onError, children}` API over `solid-js`'s `<ErrorBoundary
  fallback={(err, reset) => ...}>`; `ErrorFallback` / `errorOverlay` are ported
  verbatim (framework-neutral JSX); `JacAwaiting` wraps `solid-js` `Suspense`;
  `__jacReactErrorHandler` mirrors the React reporter.
- **Deps** (`client/impl/client_deps.impl.jac`): default client deps are now
  framework-aware. A Solid project gets `solid-js` / `@solidjs/router` /
  `solid-hook-form` / `zod` (runtime) and `vite` / `typescript` (dev) - **no**
  `vite-plugin-solid` (the build uses the `solid-js/h` hyperscript runtime, not Solid's
  JSX compiler, so `SolidBackend.vite_plugin_lines` adds no plugin). React/Preact keep
  the react-hook-form stack.

### Verification

| Suite | Result |
|-------|--------|
| `test_solid_backend` | 21/21 (19 prior + 2 new: router/form parity link-check, full export surface) |
| `test_preact_backend` | 13/13 (React/Preact parity unaffected) |

The two new tests compile the real Solid shim (shim + `impl/` annex) the bundler way
and assert: every router/form/error body links, the submit wrapper is `async`, the form
validates via `safeParse` with no `@hookform`, **no** `React.createElement` leaks, and
`@jac/runtime` (solid) exports the full surface while *not* exporting `useState` /
`useEffect`.

### Known gaps (best-effort, pending browser e2e)

- **`Routes` / `Outlet` semantics**: `@solidjs/router` expects `<Route>` as direct
  children of `<Router>` and has no `<Outlet>` (nested content arrives via a parent
  route component's `props.children`). The passthrough `Routes` and children-rendering
  `Outlet` compile and cover the flat case; deeply nested route matching and true
  outlet/layout nesting need a running Solid build to validate.
- **Form value re-population**: `solid-hook-form`'s `register` is uncontrolled (no
  `value` in its return), so programmatic `reset`/`setValue` won't reflect in inputs
  built via `{**field}` spread in v1.

## Status: Step 4 (Solid file-based-routing entry) DONE

`_create_pages_entry_content` (`runtimelib/client/impl/compiler.impl.jac`) was the
last React-hardcoded generator (`React.createElement` + `react-dom/client` +
`react-router-dom`). It is now backend-aware: it keeps the framework-neutral
orchestration (load `auth_redirect` from routing config, detect the entry module's
`app` wrapper on disk, resolve the active backend) and delegates the JS body to a
new backend method. So a Solid build's file-based-routing entry now resolves **no**
React-ecosystem package - closing the last gap that kept file-based routing
React-only.

### Step 4 - completed changes

- **New `FrameworkBackend.build_pages_entry_script(entry_module, auth_redirect,
  has_app_wrapper) -> str`** (decl in `framework_backend.jac` + `backends/react.jac`
  - `backends/solid.jac`):
  - **React** (`backends/impl/react.impl.jac`) delegates to a new
    `build_pages_react_entry_script` in `runtimelib/react_entry.jac` - the exact
    body extracted verbatim from the old `_create_pages_entry_content` (`createRoot`
    - `<BrowserRouter><Routes>` tree, `AuthGuard` redirect wrapper, root-layout
    wrap, `JacClientErrorBoundary` mount). **Preact inherits it** and resolves
    `react`/`react-dom`/`react-router-dom` through `preact/compat` via
    `vite_aliases` - so React/Preact behavior is byte-for-byte unchanged.
  - **Solid** (`backends/impl/solid.impl.jac`) delegates to a new
    `build_pages_solid_entry_script` in `runtimelib/solid_entry.jac`: the same
    `_routes.js`-driven structure, but element creation via `solid-js/h`'s `h(C, {})`
    instead of `React.createElement`, the router tree through the shim's
    `@solidjs/router` adapters (`Router`/`Routes`/`Route`/`AuthGuard` from
    `@jac/runtime`), and mount via `solid-js/web` `render(() => ..., el)`. It also
    wraps the tree in `JacClientErrorBoundary` (the Solid shim now presents that
    React-shaped API over `solid-js`'s `ErrorBoundary`) - boundary parity the
    simpler `build_simple_solid_entry_script` does not yet have.
- **`_create_pages_entry_content`** is now ~25 lines: config-load + on-disk
  app-wrapper detection + `resolve_active_backend().build_pages_entry_script(...)`.
- **Unchanged by design**: `eject.impl.jac` and HMR `_update_entry_point` use
  `backend.build_entry_script` (explicit routing / simple mount) and never
  reproduced the file-based body, so they needed no edit. HMR does not regenerate a
  file-based-routing entry (pre-existing limitation, out of scope).

### Verification

| Suite | Result |
|-------|--------|
| `test_solid_backend` | 24/24 (21 prior + 3 new: Solid pages-entry content, auth_redirect/app-wrapper variants, per-backend dispatch) |
| `test_preact_backend` | 13/13 (React/Preact entry unaffected) |
| `test_client_codegen` | 6/6 (ViteCompiler delegation compiles + runs) |
| `test_router` | 2/2 |

### Known gaps (best-effort, pending browser e2e)

- The Solid pages entry mirrors the React route-tree shape through the shim
  adapters, so it inherits the **Routes/Outlet/auth-nesting** gaps already
  documented for the shim: `@solidjs/router` expects `<Route>` as a direct child of
  `<Router>` and has no `<Outlet>`, so deeply nested matching and true layout
  outlets need a running Solid build to validate. The flat-route + single
  root-layout + auth-guard case is covered.

## Status: Step 5 (backend-aware runtime npm publish) DONE

`publish/impl/runtime_npm.impl.jac` previously hard-compiled `client_runtime.cl.jac`
(the React/core shim) into the single `@jaseci/runtime` npm package. It is now
backend-aware, reusing the same `runtime_source.jac` seam every other generator
uses (`backend.runtime_source_basename()`): a React/Preact build still publishes
`@jaseci/runtime` byte-for-byte; a Solid build publishes `@jaseci/runtime-solid`,
compiled from `solid_runtime.cl.jac` and pulling in **no** React-ecosystem package.

### Step 5 - completed changes

- **`runtime_api_names`, `compile_runtime_js`, `runtime_export_names`,
  `build_runtime_tarball`, `build_runtime_to`** all take an optional
  `framework: str = ""` (`""` = active backend). The source `.cl.jac` is resolved
  via `runtimelib/runtime_source.resolve_client_runtime_cl_path(framework)` instead
  of a hardcoded path.
- **Caches keyed by resolved source path** (`_api_names_cache` / `_runtime_js_cache`
  are now `dict`s), so a React build and a Solid build in the same process never
  clobber each other's compiled output. `npm_sources` (which calls
  `runtime_api_names()` to detect runtime symbols in user libraries) is unaffected -
  it defaults to the active backend.
- **New `runtime_pkg_name(framework="") -> str`**: derives the package name from the
  runtime source basename - `client_runtime.cl.jac` (React/Preact) → `@jaseci/runtime`,
  `<fw>_runtime.cl.jac` → `@jaseci/runtime-<fw>` (e.g. `@jaseci/runtime-solid`) so
  two frameworks' runtimes never collide on the npm registry.
- **CLI `_bundle_npm_runtime(output, framework="")`** (`project.impl.jac`) resolves
  the package name via `runtime_pkg_name` and threads `framework` through to
  `build_runtime_to`, printing the framework-correct package name.
- **peerDependencies** (`_runtime_peer_deps`): the package now declares the external
  npm packages the compiled runtime actually imports, scanned from the compiled JS
  and versioned from a canonical `_PEER_VERSIONS` map (kept in lockstep with
  `client_deps`/`config_loader`). React → `react`/`react-router-dom`/
  `react-error-boundary`/`react-hook-form`/`@hookform/resolvers`/`zod`; Solid →
  `solid-js`/`@solidjs/router`/`solid-hook-form`/`zod`. `react-dom` is correctly
  absent (it lives in the generated entry, not the runtime module).

### Two real packaging bugs found by end-to-end npm validation (and fixed)

Validating with a real `npm install` + `node` import (not just tarball-content
string matches) surfaced two pre-existing defects that made every published runtime
package - React included - fail to load. Both are now fixed and regression-tested:

1. **Duplicate exports → invalid ESM.** The Jac→JS codegen already emits its own
   `export {...}` clause for `:pub` symbols; `build_runtime_tarball` then appended a
   second, overlapping one - `node` rejected it with `SyntaxError: Duplicate export
   of 'useState'` (React) / `'useRouter'` (Solid). `runtime_export_names` now
   subtracts names the codegen already exports (`_already_exported`), so the append
   only covers the genuine delta (usually none).
2. **Unbundled split core → `ERR_MODULE_NOT_FOUND`.** Since Step 1 extracted
   `client_runtime_core.cl.jac`, the shim compiles to `import ... from
   "./jaclang/runtimelib/client_runtime_core.js"` - but the tarball shipped only
   `index.js`. The builder now walks the relative-import graph (`_collect_dep_modules`),
   compiles each sibling module, and ships it at the matching relative path
   (`package/jaclang/runtimelib/client_runtime_core.js`).

### Verification

| Check | Result |
|-------|--------|
| `test_npm_publish` | 19/19 (incl. new: `runtime_pkg_name` suffixing; React-free Solid package across all `.js` members; no-duplicate-export; core module bundled; peerDependencies) |
| `npm publish --dry-run` | both `@jaseci/runtime` and `@jaseci/runtime-solid` publish cleanly |
| `node --check` | both `index.js` are valid ESM (was a duplicate-export SyntaxError before the fix) |
| React end-to-end | `npm install <tarball> + peers` → `import * as rt` in node: 56 exports, `__jacJsx("div", {id})` returns a real React element (`type: div`, `props.id: x`) |
| Solid end-to-end | all modules **resolve** + valid ESM + clean dry-run; runtime exec blocked only by `@solidjs/router`'s import-time client-only API guard (no DOM in bare node) - environmental, not a packaging defect |

## Out of scope / follow-ups

- **Solid runtime browser exec**: the Solid package is structurally correct and all
  modules resolve, but `@solidjs/router` calls a client-only `solid-js` API at import
  time, so the runtime can't be exercised in bare `node`. A jsdom/happy-dom harness
  or a real browser/vite build is needed to exec the Solid `__jacJsx` path; gated by
  CI / browser e2e.
- Browser e2e can't run in this environment (no vite/node_modules) - gated by
  compile/ecmascript suites here + CI for the full checker/eject/preact suites.
