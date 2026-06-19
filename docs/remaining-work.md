# Remaining work - `jac-svelte` branch

Prioritized open items after Solid jsdom parity and TanStack Form migration.
`TODO.md` is the summary; `docs/tanstack-form-migration-gaps.md` covers forms.

**Last updated:** 2026-06-19

---

## Done (no longer tracked here)

- FrameworkBackend seam: React, Preact, Solid
- View IR Branches 1-5; native Solid router; `ref` thunk fix
- TanStack Form on all runtimes; `onTouched` UX; publish hardening
- Solid jsdom 5/5: counter, routing, control flow, `JacForm`, P2 matrix
  (dynamic prop, `ref` e2e, callback prop)

---

## P1 - Should-have (confidence, not blocking merge)

| # | Task | Notes |
|---|------|-------|
| 1.1 | Preact-specific form test | Low urgency; shares `client_runtime.cl.jac` |
| 1.2 | React stale onBlur/onChange `errorMap` regression (#1784) | Solid mitigated with onChange-only `onTouched` |
| 1.3 | Document `effectiveIsValid` in `form-migration.md` | Submit gate wording may be stale |
| 1.4 | Playwright submit disabled → enabled flow | `test_form.jac` covers error DOM only |

---

## P2 - Nice-to-have / defer

| # | Task | Why defer |
|---|------|-----------|
| 2.1 | Conditional `onChange` validator (true RHF `onTouched`) | Display gate + `effectiveIsValid` sufficient |
| 2.2 | Checker warning for RHF `register` / `formState` | Migration guide covers runtime break |
| 2.3 | Standard Schema field introspection (drop Zod `_def` fallback) | Last-resort for Zod v4 native enums |
| 2.4 | Sweep `react-hook-form` from out-of-scope `jac.toml` | `jac-scale`, `jaclang/cli/ai_ui`, etc. |
| 2.5 | Refresh RHF-era notes in `jac-client.md` | Historical only |
| 2.6 | Typed re-export at language/codegen level | Manifest + test sufficient for now |

---

## Accepted semantic gaps (not bugs)

1. **`onTouched` runs pre-blur** in the background; errors hidden until `isTouched`.
2. **Solid vs React validators** - Solid `onTouched` is onChange-only; React/Preact use onBlur+onChange.
3. **Raw `useJacForm().state.isValid`** may be false before touch; `JacForm` compensates.
4. **Custom RHF form UIs** (`register`, `formState`) break at runtime.

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
| Solid backend | `jac/jaclang/compiler/passes/ecmascript/backends/impl/solid.impl.jac` |
| Solid jsdom | `jac/tests/runtimelib/test_solid_jsdom.jac` |
| P2 fixtures | `fixtures/solid_dynprop_app.cl.jac`, `solid_ref_app.cl.jac`, `solid_callback_app.cl.jac` |
| Form fixture | `fixtures/solid_form_app.cl.jac` |
| Migration guide | `jac-client/jac_client/docs/advance/form-migration.md` |
