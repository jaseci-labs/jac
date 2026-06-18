# TanStack Form migration  - what's done and what's missing

Status doc for the `react-hook-form` → `@tanstack/*-form` migration on the
`jac-svelte` branch. Read this before continuing form work.

> **Re-verified 2026-06-18** against the working tree. The migration itself is
> confirmed live in both runtimes and all "landed" items are present. Of the
> "still missing" items, only the `test_npm_publish.jac` row has since been
> *partially* addressed (Solid bundle scan added); it is refined below rather
> than struck. Two additional stale references (`multi_segment_app/jac.toml`,
> and `@tanstack/react-form` missing from `diagnostics.impl.jac` `CORE_DEPS`)
> were found and added. Every other gap remains open.

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
`@hookform/resolvers`, no hand-rolled `__zodResolver`). Peer deps, default client
deps, and npm publish maps were updated (`6539.refactor.md`).

---

## Landed on this branch (recent)

### 1. `onTouched` default no longer silently maps to `onBlur` only

**Bug:** Public default is `validateMode = "onTouched"`, but `useJacForm` only
handled `"onChange"` and `"onSubmit"` explicitly. Everything else  - including
the default  - fell through to `validators.onBlur`. TanStack Form has no
`onTouched` mode, so the default became blur-only validation (no revalidation
on change after touch).

**Fix (both `client_runtime.impl.jac` and `solid_runtime.impl.jac`):**

| `validateMode` | TanStack validators |
|----------------|---------------------|
| `onChange` | `onChange` |
| `onSubmit` | `onSubmit` |
| `onBlur` | `onBlur` |
| `onTouched` | `onBlur` + `onChange` |
| unknown | `console.warn` + `onBlur` fallback |

Compiler assertion added in `test_solid_backend.jac` (Solid shim must emit the
`onTouched` branch with both validators).

### 2. Solid negative-import guard extended

`test "solid runtime shim imports no react ecosystem package"` now forbids
`@tanstack/react-form` in addition to `react-hook-form` / `@hookform/*`, so a
regression that pulls the React form lib into the Solid shim fails the static
scan.

---

## Semantics

### `onTouched` - RESOLVED (display gate, Option 2)

`validateMode="onTouched"` wires **both** `onBlur` and `onChange` TanStack
validators. `renderError` now gates on `field.state.meta.isTouched`:

```
if validateMode == "onTouched" and not isTouched → return None
```

**UX result**: errors appear after first blur (matching RHF semantics), then clear
immediately on onChange without a second blur. Other modes (`onChange`, `onBlur`,
`onSubmit`) are unaffected.

**Residual difference from RHF**: validation *runs* in the background pre-blur
(so `form.state.isValid` can be `false` before any touch), whereas RHF skips the
validator entirely. This does not affect current UI because submit is gated on
`!isDirty`, not `!isValid`.

### Submit button `disabled` semantics may differ from RHF

Both runtimes disable submit when `form.state.isSubmitting || !form.state.isDirty`.
TanStack's `isDirty` / validity model differs from RHF's `formState.isValid`.
Confirm this is intentional; jac-client Playwright test only checks
`disabled` initially, not post-validation enablement.

### Zod schema unwrapping reaches into private `_def`

`useJacForm` and `JacForm` unwrap `schema._def.schema` / `.shape` for defaults
and field enumeration. This predates TanStack but remains a supply-chain / Zod
version fragility (called out in `TODO.md` #7). No typed Standard Schema field
introspection path exists yet.

---

## Still missing  - tests

| Gap | Why it matters |
|-----|----------------|
| ~~**No Solid jsdom form fixture**~~ | **RESOLVED** (`fixtures/solid_form_app.cl.jac` + `_FORM_HARNESS` + test in `test_solid_jsdom.jac`): mounts `JacForm` with email + checkbox, asserts error on blur, clears on onChange (no second blur), checkbox renders. |
| ~~**No runtime test for `onTouched` behavior**~~ | **RESOLVED** by same test: the harness proves the onBlur+onChange approximation end-to-end - error appears after blur, clears on onChange without second blur. |
| **No React-side symmetric import guard** | Solid forbids `@tanstack/react-form`; React shim has no corresponding ban on `@tanstack/solid-form` (lower risk, but asymmetric). |
| **jac-client `test_form.jac` is shallow** | Bundle contains validation strings; Playwright checks native `input.validity` (browser constraint validation), **not** JacForm / TanStack error messages or `validateMode` timing. |
| **No Preact-specific form test** | Preact reuses `client_runtime.cl.jac`; assumed covered by React path but unproven after migration. |
| **No test that the *React* published `@jac/runtime` resolves TanStack, not RHF** | Partially addressed for **Solid only**: `test_npm_publish.jac`'s `build_runtime_tarball ... with no React ecosystem` test now scans every `.js` in the Solid tarball and asserts no `react` / `react-dom` / `react-router` import, and positively asserts `@tanstack/solid-form` in peers. **The React runtime dist has no equivalent bundle-level scan**, and its peer-dep assertion (`build_runtime_tarball packages the runtime with exports`) is itself stale  - it asserts `react` / `react-router-dom` / `zod` but neither asserts `@tanstack/react-form` is present nor that `react-hook-form` is absent. (Note: the Solid bundle scan does not name `react-hook-form` / `@hookform/*` explicitly  - only `react`-family roots. The source-level ban lives in `test_solid_backend.jac`'s negative-import guard.) |

---

## Still missing  - runtime / JacForm implementation

- **Solid `JacForm` field wiring is manual**  - every input calls
  `field.handleChange` / `field.handleBlur` explicitly. No `{**field}` spread.
  Works today but diverges from patterns documented for RHF-era JacForm; any
  TanStack field API additions (e.g. `field.handleSubmit`) need dual-runtime edits.
- **Error source is `field.state.meta.errors`**  - TanStack separates `onChange` vs
  `onBlur` error maps; JacForm merges via `.errors`. Verify stale `onBlur` errors
  clear on `onChange` (known TanStack footgun in discussions #1784).
- ~~**`renderError` shows errors unconditionally**~~ **RESOLVED**: `renderError` now accepts `isTouched: bool`; when `validateMode == "onTouched"`, errors are suppressed until `field.state.meta.isTouched` is true. Other modes (`onChange`, `onBlur`, `onSubmit`) are unaffected.
- **Radio / select paths**  - compile and render in React jac-client example; no
  Solid jsdom coverage. Checkbox is now covered by `test_solid_jsdom.jac`'s form
  test. `TODO.md` #1 (ref thunking) was fixed for generic `ref={...}`; confirm
  form controls don't rely on broken ref paths.
- **No `useJacForm` consumer docs for TanStack**  - public API unchanged
  (`validateMode`, `JacSchema`) but underlying field handle shape changed; custom
  form UIs that reached into RHF `register` / `formState` will break silently.

---

## Still missing  - docs and tooling

| Location | Issue |
|----------|-------|
| `docs/docs/tutorials/fullstack/setup.md` | Still lists `react-hook-form = "^7.71.0"` |
| `docs/docs/community/release_notes/unreleased/jaclang/6490.feature.md` | **Resolved on this PR.** The Solid router+form parity bullet previously claimed `solid-hook-form` + a hand-rolled zod resolver + `formState.errors`; updated in-place to `@tanstack/solid-form` + Standard Schema validators + `field.state.meta.errors`, with a forward pointer to #6539. (The note's other three bullets - Solid signals backend, View IR seam, native Solid routing - were correct and left untouched.) |
| `jac-client/jac_client/plugin/src/impl/diagnostics.impl.jac` | `CORE_DEPS` still lists `react-hook-form` + `@hookform/resolvers` **and is missing `@tanstack/react-form`**  - so a real missing-dep error for TanStack gets misclassified as a regular (non-core) dep with the wrong hint, while the dead RHF entries stay classified as core. |
| `jac-client/jac_client/docs/advance/form-handling.md` | Documents `onTouched` as an RHF mode name with no TanStack caveat |
| `.jac/client/compiled/client_runtime.js` (local cache) | May still show old RHF `useForm({mode, resolver})` until recompiled (confirmed stale on this checkout: still `import { useForm } from "react-hook-form"` + `zodResolver`) |
| `jac-client/jac_client/tests/fixtures/multi_segment_app/jac.toml` | Test fixture's `[dependencies.npm]` still pins `react-hook-form = "^7.71.0"` and `"@hookform/resolvers" = "^5.2.2"` even though the app source uses no forms at all |

Update user-facing docs when migration ships; note `onTouched` approximation
explicitly in `form-handling.md`.

---

## Recommended order before continuing

1. **Add Solid jsdom form fixture**  - smallest end-to-end proof the migration
   works (submit, validation messages, checkbox/radio if cheap).
2. **Decide `onTouched` policy**  - approximation + doc, or conditional validator /
   error gating for true RHF parity.
3. **Harden jac-client Playwright test**  - assert JacForm error DOM, not just
   native `validity`.
4. **Sweep stale `react-hook-form` references** in docs, diagnostics, tutorials.
5. **Optional:** React shim negative-import test for `@tanstack/solid-form`;
   bundle-level "no RHF in **React** dist" check + positive `@tanstack/react-form`
   peer assertion (the Solid counterpart already exists in `test_npm_publish.jac`).

---

## Related files

| Area | Path |
|------|------|
| React `useJacForm` | `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` |
| Solid `useJacForm` | `jac/jaclang/runtimelib/impl/solid_runtime.impl.jac` |
| Public API | `client_runtime.cl.jac`, `solid_runtime.cl.jac` |
| Compiler tests | `jac/tests/compiler/passes/ecmascript/test_solid_backend.jac` |
| jsdom harness | `jac/tests/runtimelib/test_solid_jsdom.jac` |
| jac-client e2e | `jac-client/jac_client/tests/test_form.jac` |
| Deps / peers | `client_deps.impl.jac`, `runtime_npm.impl.jac` |
| Broader Solid parity | `TODO.md` (items #3, #7, jsdom matrix) |
