# Remaining work - `jac-svelte` branch

Open follow-ups after Solid jsdom parity and TanStack Form migration (both
**complete**). See `TODO.md` for the shipped summary.

**Last updated:** 2026-06-19

---

## Done

- FrameworkBackend seam: React, Preact, Solid
- View IR Branches 1-5; native Solid router; `ref` thunk fix; layout root JSX
- TanStack Form on all runtimes; `onTouched` UX end-to-end
- onChange-only `onTouched` on React, Preact, and Solid (TanStack #1784)
- Solid jsdom 5/5 + P2 matrix (dynamic prop, `ref` e2e, callback prop)
- Playwright submit semantics (`test_form.jac`)
- Preact `JacForm` compiler smoke (`test_preact_backend.jac`)
- Export manifest, strict peers, import guards, publish scans

---

## P1 - Defer (low urgency)

| # | Task | Notes |
|---|------|-------|
| 1.1 | True RHF-identical `onTouched` (no pre-blur validation) | Display gate + `effectiveIsValid` sufficient |
| 1.2 | Checker warning for RHF `register` / `formState` | Migration guide covers runtime break |
| 1.3 | Standard Schema field introspection (drop Zod `_def` fallback) | Last-resort for Zod v4 native enums |
| 1.4 | Typed re-export at language/codegen level | Manifest + test sufficient for now |
| 1.5 | Preact runtime jsdom form test | Compiler smoke exists; shares `client_runtime` |

---

## Accepted semantic gaps (not bugs)

1. **`onTouched` runs pre-blur** in the background; errors hidden until `isTouched`.
2. **Raw `useJacForm().state.isValid`** may be false before touch; `JacForm` compensates.
3. **Custom RHF form UIs** (`register`, `formState`) break at runtime.

---

## View IR / Solid - longer tail

| Item | Status |
|------|--------|
| `unsafe_html` → `innerHTML` structured marker | Open |
| `&&` JSX falsy-leak → `<Show>` | Deferred |
| Statement-form `JsxSlot` lifting | Deferred |
| `SlotChild` prebuilt IIFE (Svelte debt) | Deferred |

---

## Broader #6490 follow-ups (separate PRs)

| Item | Status |
|------|--------|
| Svelte backend | Not started |
| `lower_state_read` ([#6677](https://github.com/jaseci-labs/jaseci/issues/6677)) | Open |
| Reactivity contract / capability matrix | Open |

---

## File index

| Area | Path |
|------|------|
| React `JacForm` | `jac/jaclang/runtimelib/impl/client_runtime.impl.jac` |
| Solid `JacForm` | `jac/jaclang/runtimelib/impl/solid_runtime.impl.jac` |
| Solid jsdom | `jac/tests/runtimelib/test_solid_jsdom.jac` |
| P2 fixtures | `fixtures/solid_dynprop_app.cl.jac`, `solid_ref_app.cl.jac`, `solid_callback_app.cl.jac` |
| Playwright forms | `jac-client/jac_client/tests/test_form.jac` |
| Compiler pins | `test_solid_backend.jac`, `test_preact_backend.jac` |
