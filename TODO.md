# jac-svelte branch status

**Last updated:** 2026-06-19
**PR:** [#6539](https://github.com/jaseci-labs/jaseci/pull/6539)
**Checklist:** `docs/remaining-work.md`

---

## Shipped

### FrameworkBackend seam (#6490 core)

- `FrameworkBackend` interface + neutral `reactive_intent` / `view_ir` layers
- **React**, **Preact**, **Solid** backends; `[client] framework` in `jac.toml`
- Backend-driven Vite plugins/aliases, runtime globals, entry scripts
- `E5081` for unknown framework names

### Solid backend

| Area | Status |
|------|--------|
| View IR Branches 1-5 (dom-expressions, `vite-plugin-solid`, drop `h`) | Done |
| Native `@solidjs/router` file-based routing + layout bridge | Done |
| `ref` excluded from Solid view thunk seam | Done |
| `solid_runtime.cl.jac` framework-free shim | Done |
| `CORE_RUNTIME_SYMBOLS` export manifest + parity test | Done |
| Strict runtime peer deps (no `"*"` fallback) | Done |
| jsdom gate (`test_solid_jsdom.jac`, 5 tests) | Done |

**jsdom coverage:** counter, routing, `<For>`/`<Show>`, full `JacForm` (email,
checkbox, select, radio, submit), dynamic prop, `ref` e2e, callback prop.

### TanStack Form migration (complete)

- `@tanstack/react-form` (React/Preact) and `@tanstack/solid-form` (Solid)
- RHF / resolvers removed; Standard Schema validators
- `onTouched` display + border gate; `effectiveIsValid` submit gate (React)
- **onChange-only `onTouched` on all runtimes** (TanStack #1784 fix; React matches Solid)
- Solid reactive submit via `form.Subscribe` + `createMemo`
- Import guards, publish tarball scans
- jac-client Playwright: error DOM + submit disabled → enabled → `onSubmit` fires
- Preact compiler smoke for `JacForm` / `useJacForm` (`test_preact_backend.jac`)

---

## Open (follow-up PRs)

| Area | Items |
|------|-------|
| #6490 tail | Svelte backend; `lower_state_read` ([#6677](https://github.com/jaseci-labs/jaseci/issues/6677)); reactivity contract |
| View IR tail | `unsafe_html` → `innerHTML`; tier-3 `&&` / `JsxSlot` lifts; typed `@jac/runtime` re-exports |
| Defer | True RHF-identical `onTouched`; RHF `register` checker warning; Zod `_def` introspection |

---

## Reference docs

| Doc | Purpose |
|-----|---------|
| `docs/remaining-work.md` | Open follow-ups only |
| `docs/tanstack-form-migration-gaps.md` | Form migration (complete) |
| `docs/compiler-ir-vs-main.md` | Pipeline diff vs `main` |
| `docs/framework-view-ir-plan.md` | View IR architecture |
| `docs/solid-dom-expressions-plan.md` | Solid dom-expressions rollout |
