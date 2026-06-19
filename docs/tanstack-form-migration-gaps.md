# TanStack Form migration - status

`react-hook-form` → `@tanstack/*-form` on the `jac-svelte` branch.

**Last updated:** 2026-06-19
**Status:** **Complete.**

---

## Shipped

| Area | Status |
|------|--------|
| TanStack Form on React / Preact / Solid | Done |
| RHF / resolvers / `solid-hook-form` removed | Done |
| Peer deps, client deps, npm publish maps | Done |
| `onTouched` display + border gated on `isTouched` | Done |
| `effectiveIsValid` submit gate (React/Preact) | Done |
| onChange-only `onTouched` on **all** runtimes (TanStack #1784) | Done |
| Solid reactive submit (`createMemo` + `form.Subscribe`) | Done |
| Solid jsdom: email, checkbox, select, radio, submit | Done |
| Import guards + publish tarball scans | Done |
| jac-client Playwright: error DOM + submit flow | Done |
| Preact `JacForm` compiler smoke | Done |
| Migration guide + example `jac.toml` cleanup | Done |

---

## Validator mapping (final)

| `validateMode` | React / Preact / Solid |
|----------------|------------------------|
| `onChange` | `onChange` |
| `onSubmit` | `onSubmit` |
| `onBlur` | `onBlur` |
| `onTouched` | **onChange only** |
| unknown | `onBlur` fallback + warn |

All runtimes use onChange-only for `onTouched` so sibling fields do not keep stale
`errorMap["blur"]` entries after cross-field blur (TanStack #1784). Error display
and borders stay gated on `isTouched`.

---

## Accepted gaps

1. Pre-blur validation runs in the background for `onTouched`.
2. Raw `useJacForm().state.isValid` may be false before touch.
3. Zod `_def` fallback remains for v4 native enums.
4. Custom RHF UIs (`register`, `formState`) break at runtime.

---

## Optional defer

| Item | Notes |
|------|-------|
| True RHF-identical `onTouched` | Not needed for UX |
| Preact runtime jsdom form test | Compiler smoke sufficient |
| RHF `register` checker warning | Migration guide only |

---

## Key files

| Area | Path |
|------|------|
| React shim | `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` |
| Solid shim | `jac/jaclang/runtimelib/impl/solid_runtime.impl.jac` |
| jsdom | `jac/tests/runtimelib/test_solid_jsdom.jac` |
| Playwright | `jac-client/jac_client/tests/test_form.jac` |
| Compiler pins | `test_solid_backend.jac`, `test_preact_backend.jac` |
| Migration guide | `jac-client/jac_client/docs/advance/form-migration.md` |
