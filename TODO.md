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

### TanStack Form migration

- `@tanstack/react-form` (React/Preact) and `@tanstack/solid-form` (Solid)
- RHF / resolvers removed; Standard Schema validators
- `onTouched` display + border gate; React `effectiveIsValid` submit gate
- Solid onChange-only `onTouched` validators (avoids stale cross-field `errorMap`)
- Import guards, publish tarball scans, jac-client Playwright error DOM

---

## Open (non-blocking)

Full list in `docs/remaining-work.md`. Summary:

| Area | Open items |
|------|------------|
| Form polish | Preact form test; React #1784 stale `errorMap`; Playwright submit flow |
| Docs | `effectiveIsValid` wording in `form-migration.md`; RHF pins in ancillary `jac.toml` |
| #6490 follow-up | Svelte backend; `lower_state_read` ([#6677](https://github.com/jaseci-labs/jaseci/issues/6677)); reactivity contract |
| View IR tail | `unsafe_html` → `innerHTML`; tier-3 `&&` / `JsxSlot` lifts; typed `@jac/runtime` re-exports |

---

## Reference docs

| Doc | Purpose |
|-----|---------|
| `docs/remaining-work.md` | Prioritized open work |
| `docs/tanstack-form-migration-gaps.md` | Form migration detail + accepted gaps |
| `docs/compiler-ir-vs-main.md` | Pipeline diff vs `main` (PR review) |
| `docs/framework-view-ir-plan.md` | View IR architecture plan |
| `docs/solid-dom-expressions-plan.md` | Solid dom-expressions rollout |
