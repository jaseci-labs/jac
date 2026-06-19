# TanStack Form migration - status

`react-hook-form` → `@tanstack/*-form` on the `jac-svelte` branch.

**Last updated:** 2026-06-19
**Status:** **Complete.** Remaining items are optional polish.

---

## Shipped

| Area | Status |
|------|--------|
| TanStack Form on React / Preact / Solid | Done |
| RHF / resolvers / `solid-hook-form` removed | Done |
| Peer deps, client deps, npm publish maps | Done |
| `onTouched` display + border gated on `isTouched` | Done |
| React `effectiveIsValid` submit gate | Done |
| Solid onChange-only `onTouched` + `createMemo` submit | Done |
| Solid jsdom: email, checkbox, select, radio, submit | Done |
| Import guards + publish tarball scans | Done |
| jac-client Playwright Jac error DOM | Done |
| Migration guide + example `jac.toml` cleanup | Done |

---

## Validator mapping

| `validateMode` | React / Preact | Solid |
|----------------|----------------|-------|
| `onChange` | `onChange` | `onChange` |
| `onSubmit` | `onSubmit` | `onSubmit` |
| `onBlur` | `onBlur` | `onBlur` |
| `onTouched` | `onBlur` + `onChange` | **onChange only** |
| unknown | `onBlur` fallback + warn | same |

Solid uses onChange-only for `onTouched` to avoid stale `errorMap["blur"]` on
sibling fields (TanStack #1784-style). Display and borders stay gated on `isTouched`.

---

## Accepted gaps

1. Pre-blur validation runs in the background for `onTouched`.
2. Raw `useJacForm().state.isValid` may be false before touch.
3. Zod `_def` fallback remains for v4 native enums.
4. Custom RHF UIs (`register`, `formState`) break at runtime.

---

## Optional follow-ups

| Item | Notes |
|------|-------|
| Preact-specific form test | Shares `client_runtime` |
| React multi-field stale `errorMap` | Solid fixed; React not |
| Playwright submit enabled/disabled | Error DOM only today |
| `form-migration.md` `effectiveIsValid` wording | Doc polish |
| RHF in `jac-scale` / `ai_ui` tomls | Out of `@jac/runtime` scope |

---

## Key files

| Area | Path |
|------|------|
| React shim | `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` |
| Solid shim | `jac/jaclang/runtimelib/impl/solid_runtime.impl.jac` |
| jsdom tests | `jac/tests/runtimelib/test_solid_jsdom.jac`, `fixtures/solid_form_app.cl.jac` |
| Compiler pins | `test_solid_backend.jac`, `test_preact_backend.jac` |
| Migration guide | `jac-client/jac_client/docs/advance/form-migration.md` |
| Release note | `docs/docs/community/release_notes/unreleased/jaclang/6539.refactor.md` |
