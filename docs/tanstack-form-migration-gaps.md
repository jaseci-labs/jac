# TanStack Form migration - status

Status doc for the `react-hook-form` → `@tanstack/*-form` migration on the
`jac-svelte` branch. Read this before continuing form work.

**Last updated:** 2026-06-18 (aligned with branch through `5a5cbd813`).

---

## Shipped summary

| Area | Status |
|------|--------|
| TanStack Form on React / Preact / Solid runtimes | Done |
| Remove RHF / `@hookform/resolvers` / `solid-hook-form` / `__zodResolver` | Done |
| Peer deps, default client deps, npm publish maps | Done |
| `onTouched` validator wiring (`onBlur` + `onChange`) | Done |
| `onTouched` error **display** gated on `isTouched` (`renderError` + `hasError` borders) | Done |
| Solid shim import guard (`@tanstack/react-form` forbidden) | Done |
| React shim symmetric import guard (`@tanstack/solid-form` / `solid-js` forbidden) | Done |
| Solid jsdom `JacForm` e2e (email blur/change + checkbox) | Done |
| Compiler pins for `onTouched` in `useJacForm` | Done |
| Solid published runtime tarball scan (no React ecosystem) | Done |
| Migration guide + `form-handling.md` caveat | Done |
| `diagnostics.impl.jac` `CORE_DEPS` → `@tanstack/react-form` | Done |
| True RHF-identical `onTouched` (no pre-blur validation) | **Not done** (approximation + display gate) |
| React dist / peer publish assertions for TanStack | Done |
| jac-client Playwright depth on Jac error DOM | Done |
| Solid jsdom for radio / select | **Not done** |

---

## Context

`useJacForm` / `JacForm` in `@jac/runtime` used to delegate to **React Hook Form**
(`mode: "onTouched"`, `zodResolver`). The migration swaps that for **TanStack
Form** on both runtimes:

| Runtime | Shim | Form API |
|---------|------|----------|
| React / Preact | `client_runtime.cl.jac` | `@tanstack/react-form` → `useForm` |
| Solid | `solid_runtime.cl.jac` | `@tanstack/solid-form` → `createForm` |

Zod schemas are passed directly as Standard Schema validators (no
`@hookform/resolvers`, no hand-rolled `__zodResolver`). See release note
`docs/docs/community/release_notes/unreleased/jaclang/6539.refactor.md`.

---

## Shipped on this branch

### Runtime migration (`fd749265b`)

- `useJacForm` / `JacForm` rewritten for TanStack Form on React and Solid.
- `client_deps.impl.jac`, `config_loader.impl.jac`, `runtime_npm.impl.jac` updated
  for `@tanstack/react-form` / `@tanstack/solid-form` peers.
- Solid runtime uses `createForm`; React uses `useForm`.
- `JacForm` uses `form.Field` render props with explicit `handleChange` /
  `handleBlur` per input type (replaces RHF `register` + `{**field}` spread).

### `onTouched` validator mapping (`a211465f2`)

Public default remains `validateMode = "onTouched"`. TanStack has no native mode;
both runtimes map it explicitly:

| `validateMode` | TanStack validators |
|----------------|---------------------|
| `onChange` | `onChange` |
| `onSubmit` | `onSubmit` |
| `onBlur` | `onBlur` |
| `onTouched` | `onBlur` + `onChange` |
| unknown | `console.warn` + `onBlur` fallback |

Compiler regression in `test_solid_backend.jac` (Solid shim must emit the
`onTouched` branch with both validators).

### `onTouched` error display gate (`5a5cbd813`)

`renderError` in both `client_runtime.impl.jac` and `solid_runtime.impl.jac`
suppresses the error paragraph until `field.state.meta.isTouched` when
`validateMode == "onTouched"`. Restores the RHF UX of “no error text until first
blur”; post-blur revalidation on change is covered by the dual validators.

Documented in `jac-client/jac_client/docs/advance/form-migration.md` and linked
from `form-handling.md`.

### Solid framework isolation

- `test "solid runtime shim imports no react ecosystem package"` forbids
  `react-hook-form`, `@hookform/*`, and `@tanstack/react-form` in Solid shim sources.
- `test_npm_publish.jac`: `build_runtime_tarball packages the Solid runtime with no
  React ecosystem` scans every `.js` in the Solid package and asserts
  `@tanstack/solid-form` in peers (no `react` / `react-dom` / `react-router`).

### Solid jsdom form e2e

- Fixture: `jac/tests/runtimelib/fixtures/solid_form_app.cl.jac`
- Test: `test "solid JacForm renders and validates in jsdom (TanStack Form end-to-end)"`
  in `test_solid_jsdom.jac`
- Proves: mount, invalid email → error after blur, fix clears on change without
  second blur, checkbox branch renders.

### Docs and tooling (shipped)

| Item | Where |
|------|--------|
| Migration guide (API table, `validateMode`, `jac.toml` diff) | `jac-client/jac_client/docs/advance/form-migration.md` |
| `onTouched` caveat + link to migration guide | `jac-client/jac_client/docs/advance/form-handling.md` |
| Release note for TanStack migration | `6539.refactor.md` |
| `6490.feature.md` corrected (TanStack, not `solid-hook-form`) | unreleased jaclang notes |
| `CORE_DEPS` uses `@tanstack/react-form` (RHF removed) | `diagnostics.impl.jac` |
| `multi_segment_app` test fixture deps | RHF entries removed from `jac.toml` |

---

## Still open - semantics

### `onTouched` is approximated, not identical to RHF

**Shipped:** dual validators + error text and `hasError` borders gated on `isTouched`.

**Still differs from RHF:**

1. **Validation still runs on change before first blur** (background work; users
   do not see error text or red borders, but `form.state.isValid` may be false early).
2. Submit stays `disabled={isSubmitting || !isDirty}`, not tied to `isValid`.

**Further fix options if stricter parity is required:**

- Conditional `onChange` validator (only when `field.state.meta.isTouched`)
- Change public default + document breaking change
- TanStack `revalidateLogic` / `onDynamic` (form-submit-scoped; different model)

### Zod schema unwrapping reaches into private `_def`

`useJacForm` and `JacForm` unwrap `schema._def.schema` / `.shape` for defaults
and field enumeration. Supply-chain / Zod version fragility; no Standard Schema
field introspection path yet (`TODO.md` #7).

---

## Still open - tests

| Gap | Notes |
|-----|--------|
| ~~**React-side symmetric import guard**~~ | **Done** - `test_preact_backend.jac` forbids `@tanstack/solid-form` and `solid-js` in `client_runtime.cl.jac` + impl. |
| ~~**jac-client `test_form.jac` shallow**~~ | **Done** - Playwright asserts Jac `Invalid email` error `<p>` after blur and hidden after fix. |
| **No Preact-specific form test** | Reuses `client_runtime.cl.jac`; unproven after migration. |
| ~~**React published `@jac/runtime` tarball**~~ | **Done** - `test_npm_publish.jac` asserts `@tanstack/react-form` peer and no `react-hook-form` / `@hookform` in any `.js`. |
| **Solid radio / select** | Email + checkbox covered in jsdom; radio/select branches not exercised end-to-end. |

---

## Still open - runtime / JacForm

- **Manual field wiring** in both runtimes - every input type calls
  `handleChange` / `handleBlur` explicitly; TanStack API changes need dual edits.
- **Stale `onBlur` vs `onChange` error maps** - TanStack footgun (#1784); not
  explicitly regression-tested.
- **Custom form UIs** using RHF `register` / `formState` break at runtime;
  migration guide exists but no compile-time warning.

---

## Still open - docs and housekeeping

| Location | Issue |
|----------|--------|
| Unrelated `jac.toml` fixtures | `jac-scale`, `jaclang/cli/ai_ui`, etc. still pin `react-hook-form` for their own UIs (outside `@jac/runtime` migration scope). |
| Historical release notes | `jac-client.md` still mentions RHF-era `{**field}` fix (accurate history, not current stack). |
| Local `.jac/client/compiled/` cache | May show old RHF until recompiled; not a source-of-truth issue. |

---

## Recommended order before calling migration done

1. **Solid jsdom** for select/radio if cheap.
2. **Optional:** conditional `onChange` validator if background pre-blur validation
   causes real submit/state bugs.
3. **Preact-specific form test** if we want explicit coverage beyond shared `client_runtime`.

---

## Related files

| Area | Path |
|------|------|
| React `useJacForm` | `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` |
| Solid `useJacForm` | `jac/jaclang/runtimelib/impl/solid_runtime.impl.jac` |
| Public API | `client_runtime.cl.jac`, `solid_runtime.cl.jac` |
| Migration guide | `jac-client/jac_client/docs/advance/form-migration.md` |
| Compiler tests | `jac/tests/compiler/passes/ecmascript/test_solid_backend.jac`, `test_preact_backend.jac` |
| jsdom harness | `jac/tests/runtimelib/test_solid_jsdom.jac` |
| Form fixture | `jac/tests/runtimelib/fixtures/solid_form_app.cl.jac` |
| jac-client e2e | `jac-client/jac_client/tests/test_form.jac` |
| Deps / peers | `client_deps.impl.jac`, `runtime_npm.impl.jac` |
| Broader Solid parity | `TODO.md`, `docs/compiler-ir-vs-main.md` |
