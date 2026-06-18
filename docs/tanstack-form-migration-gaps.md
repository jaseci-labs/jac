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

## Still missing  - semantics

### `onTouched` is approximated, not equivalent to RHF

RHF `mode: "onTouched"` means:

1. **Do not** validate on change until the field has been blurred once.
2. After first blur, validate on every subsequent change.

Our workaround wires **both** `onBlur` and `onChange` validators. That restores
post-blur revalidation (the main regression) but may validate on change **before**
first blur  - stricter than RHF.

**Proper fix options (pick one before calling this done):**

1. **Conditional `onChange` validator**  - only run schema when
   `field.state.meta.isTouched` / `isBlurred` is true (needs per-field awareness;
   form-level Standard Schema may require a wrapper function, not a bare Zod
   object).
2. **Gate error display, not validation**  - keep both triggers but only render
   `field.state.meta.errors` when `isTouched` (TanStack community pattern; errors
   still compute in the background).
3. **Change the public default** to `onBlur` or `onChange` and document the
   TanStack mapping explicitly in `form-handling.md` (breaking change for apps
   relying on RHF semantics).
4. **TanStack `revalidateLogic` / `onDynamic`**  - investigate
   `validationLogic: revalidateLogic({ mode: 'blur', modeAfterSubmission: 'change' })`
   for form-submit-scoped behavior (not per-field touched; different model).

Until one of these is chosen and tested, treat `validateMode="onTouched"` as
**best-effort parity**, not a guarantee.

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
| **No Solid jsdom form fixture** | Routing and control-flow have jsdom gates (`test_solid_jsdom.jac`); forms do not. `TODO.md` explicitly lists "JacForm submit/validation/checkbox/radio" as required before React-parity. |
| **No runtime test for `onTouched` behavior** | Compiler pins emitted validator wiring; nothing asserts blur-then-change UX (error appears on blur, clears/updates on change). |
| **No React-side symmetric import guard** | Solid forbids `@tanstack/react-form`; React shim has no corresponding ban on `@tanstack/solid-form` (lower risk, but asymmetric). |
| **jac-client `test_form.jac` is shallow** | Bundle contains validation strings; Playwright checks native `input.validity` (browser constraint validation), **not** JacForm / TanStack error messages or `validateMode` timing. |
| **No Preact-specific form test** | Preact reuses `client_runtime.cl.jac`; assumed covered by React path but unproven after migration. |
| **No test that the *React* published `@jac/runtime` resolves TanStack, not RHF** | Partially addressed for **Solid only**: `test_npm_publish.jac`'s `build_runtime_tarball ... with no React ecosystem` test now scans every `.js` in the Solid tarball and asserts no `react` / `react-dom` / `react-router` import, and positively asserts `@tanstack/solid-form` in peers. **The React runtime dist has no equivalent bundle-level scan**, and its peer-dep assertion (`build_runtime_tarball packages the runtime with exports`) is itself stale  - it asserts `react` / `react-router-dom` / `zod` but neither asserts `@tanstack/react-form` is present nor that `react-hook-form` is absent. (Note: the Solid bundle scan does not name `react-hook-form` / `@hookform/*` explicitly  - only `react`-family roots. The source-level ban lives in `test_solid_backend.jac`'s negative-import guard.) |

**Suggested first test to add:** `fixtures/solid_form_app.cl.jac` + jsdom harness  -
fill invalid email → blur → assert Jac error text → fix value → assert error
clears without second blur (proves `onTouched` post-blur revalidation).

---

## Still missing  - runtime / JacForm implementation

- **Solid `JacForm` field wiring is manual**  - every input calls
  `field.handleChange` / `field.handleBlur` explicitly. No `{**field}` spread.
  Works today but diverges from patterns documented for RHF-era JacForm; any
  TanStack field API additions (e.g. `field.handleSubmit`) need dual-runtime edits.
- **Error source is `field.state.meta.errors`**  - TanStack separates `onChange` vs
  `onBlur` error maps; JacForm merges via `.errors`. Verify stale `onBlur` errors
  clear on `onChange` (known TanStack footgun in discussions #1784).
- **`renderError` shows errors unconditionally**  - no `isTouched` gate. Even with
  correct validator timing, UX may show errors earlier than RHF `onTouched` users
  expect.
- **Checkbox / radio / select paths**  - compile and render in React jac-client
  example; no Solid jsdom coverage. `TODO.md` #1 (ref thunking) was fixed for
  generic `ref={...}`; confirm form controls don't rely on broken ref paths.
- **No `useJacForm` consumer docs for TanStack**  - public API unchanged
  (`validateMode`, `JacSchema`) but underlying field handle shape changed; custom
  form UIs that reached into RHF `register` / `formState` will break silently.

---

## Still missing  - docs and tooling

| Location | Issue |
|----------|-------|
| `docs/docs/tutorials/fullstack/setup.md` | Still lists `react-hook-form = "^7.71.0"` |
| `docs/docs/community/release_notes/unreleased/jaclang/6490.feature.md` | Describes `solid-hook-form` (superseded by 6539) |
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
