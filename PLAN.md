# PLAN: Issue 6490 - Framework-agnostic web codegen (`FrameworkBackend` seam)

## Goal

Make Jac's client codegen (`.cl.jac` / `cl {}` → JavaScript) framework-agnostic
by extracting a `FrameworkBackend` seam from `EsastGenPass`. Today the pass
hard-wires React semantics (re-render model, setter functions, hooks, Suspense)
directly into the ESTree it emits. After this work the pass emits a
**framework-neutral reactive-intent vocabulary** and a pluggable backend lowers
that intent to ESTree. The ESTree layer (`estree.jac`) and the printer
(`es_unparse.jac`) are already neutral and stay shared.

The real deliverable is a **written reactivity contract** precise enough to
decide, before writing an adapter, whether a target framework is feasible. The
adapters (Preact, then a signals target) are validation, not the point.

Author-facing syntax compatibility is a hard requirement. Existing `.cl.jac`
component syntax (`has`, `awaiting`, JSX, refs, effects, etc.) must remain
source-compatible so existing applications keep compiling. The architectural
work here is an internal seam refactor, not a source-language redesign.

---

## Source-of-truth map (verified against the tree)

### Where React semantics live today

All inside `jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac`
(declarations in `esast_gen_pass.jac`):

| Reactive form | Jac source | Current React lowering | Site |
|---------------|-----------|------------------------|------|
| **State field** | `has count: int = 0;` | `const [count, setCount] = useState(0)` | `exit_arch_has` (impl ~3960) |
| **Ref field** | `has r: Ref[T];` | `const r = useRef(null)` | `exit_arch_has` (impl ~3903) |
| **State update** | `count = X` | `setCount(X)` | `exit_assignment` (impl ~1885) |
| **Setter naming** | - | `count` → `setCount` | `_get_setter_name` (impl ~3713) |
| **Effect** | `can with entry { ... }` | `useEffect(() => {...}, [deps])` | `_transform_to_useeffect` (impl ~3776+) |
| **Async boundary** | `try { ...await... } awaiting {...}` | `<JacAwaiting>` (Suspense) + `<JacClientErrorBoundary>` | `exit_try_stmt` / `_build_awaiting_wrapper` (impl ~3070, ~3175) |
| **View / JSX** | `<div>...</div>`, `<>...</>` | `__jacJsx(...)`, fragments | `exit_jsx_element` (impl ~3700), `_jsx_fragment` (impl ~3605) |
| **Runtime imports** | (implicit) | `useState`/`useEffect`/`useRef`/`__jacJsx`/`JacAwaiting` injected | `_inject_runtime_import` (impl ~3754) |

### State held on the pass (relevant to the seam)

`EsastGenPass` (`esast_gen_pass.jac:191`) carries:

- `reactive_vars: dict[str, str]` - `var_name -> setter_name`. **Tracking is
  structural** (which vars are reactive); **the `setCount` naming is
  React-specific**.
- `reactive_vars_stack` - save/restore per function boundary.
- `injected_imports: set[str]` - dedup for `_inject_runtime_import`.
- `_view_stack`, `_view_awaiting_tries`, `_view_acc_*` - JSX slot lowering.

### Already-neutral layers (KEEP AS-IS)

- `jac/jaclang/compiler/passes/ecmascript/estree.jac` - ESTree AST.
- `jac/jaclang/compiler/passes/ecmascript/es_unparse.jac` - ESTree → JS.
- `jac/jaclang/compiler/passes/ecmascript/primitives_es.jac` +
  `jac_runtime_js.jac` - Jac primitive `_jac.*` ops (language, not UI).
- `jac0core/passes/ast_gen/jsx_processor.jac` (`EsJsxProcessor`) - JSX tag
  lowering shared with the server AST gen. The **element factory name**
  (`__jacJsx`) is the only framework-touchpoint here.

### Runtime-source seam (partial, generalize it)

- `jac/jaclang/runtimelib/client_surface.jac` - maps each emitted runtime
  symbol to its source (`@jac/runtime` vs raw `react`, e.g. `useRef`), and
  builds the prepended JSX-runtime import (`prepended_runtime_import`,
  `with_runtime_globals`).
- `jac/jaclang/runtimelib/client_runtime.cl.jac` - the `@jac/runtime` virtual
  module, **React-backed** (re-exports `useState`, `useEffect`, router, error
  boundary, etc.).

### Compile entry + config

- `jac/jaclang/runtimelib/client/jac_to_js.jac` (+ impl) - `JacToJSCompiler`;
  `add_runtime_imports` calls `with_runtime_globals`.
- **Pass scheduling**: `EsastGenPass` is returned as a *type* from
  `get_py_code_gen` in `jac0core/compiler.jac:209`. Passes are constructed by
  the `Transform` framework, **not** by us - so **there is no constructor we
  can pass a backend through**.
- **How a pass reaches config (established pattern)**: `JacAutoLintPass.postinit`
  does `import from jaclang.project.config { get_config }; config = get_config()`.
  `EsastGenPass.before_pass` (impl ~6750) is the analogous hook for us.
- `jac/jaclang/project/config.jac` - `JacConfig` with one `*Config` obj per
  `jac.toml` section (`RunConfig`, `ServeConfig`, ...). **No `[client]` section
  exists yet.**

---

## Design

### 0. Compatibility and seam boundaries

- Preserve the existing client authoring syntax. Framework support must be
  introduced by changing lowering and runtime plumbing, not by changing Jac
  surface syntax.
- Keep `FrameworkBackend` narrowly focused on **compiler lowering**: reactive
  intent -> ESTree, plus closely related read/view hooks needed during lowering.
- Do **not** use syntax-compatibility as justification for one "god object"
  backend that also owns runtime-module selection, bundler wiring, Vite plugins,
  and bootstrap-script generation. Those are framework-specific, but they are
  **not** the same concern as AST lowering.
- Introduce or preserve an adjacent runtime/platform seam for non-lowering
  framework decisions (`client_surface`, runtime source selection, bundler
  aliases/plugins, entry bootstrap). Shared framework selection is fine; shared
  responsibility is not.

### 1. Backend selection - `[client] framework` in `jac.toml`

Follow the existing per-section config pattern exactly.

- Add `ClientConfig` to `jac/jaclang/project/config.jac`:

  ```jac
  obj ClientConfig {
      has framework: str = "react";
  }
  ```

- Add `client: ClientConfig = ClientConfig()` to `JacConfig.has`.
- Parse `[client]` in `_parse_toml_data` (mirror how `serve` / `run` parse).
- Default is `"react"`; selection is read once.

### 2. The neutral reactive-intent vocabulary

A small set of records (new file
`jac/jaclang/compiler/passes/ecmascript/reactive_intent.jac`) that reference
**already-lowered ESTree fragments** for expressions (the expression layer is
neutral) but leave reactive structure to the backend:

- `StateField { name: str, init: es.Expression }`
- `RefField { name: str, init: es.Expression }`
- `StateUpdate { name: str, value: es.Expression, aug_op: (str | None) }`
- `Effect { body: list[es.Statement], deps: list[es.Expression] }` - lowered
dep expressions are already ESTree nodes; backends stringify or ignore as needed.
- `AsyncBoundary { body, awaiting, excepts }` - try/await semantics.

Records hold the structural facts the backend needs; nothing React-specific
(no `setCount`, no `useState`, no `<JacAwaiting>`) lives in them.

### 3. The `FrameworkBackend` interface

New file `jac/jaclang/compiler/passes/ecmascript/framework_backend.jac`
(declaration) + `impl/framework_backend.impl.jac`. Each method takes neutral
intent and returns ESTree so the shared printer is unchanged. Long term, keep
this interface limited to lowering concerns:

```jac
obj BackendCaps {
    has memo: bool = False,
        cleanup: bool = True,
        async_boundary: bool = True;
}

obj FrameworkBackend(ABC) {
    def name -> str;                       # "react" | "preact" | "solid"
    def capabilities -> BackendCaps;

    # reactive lowering (intent -> ESTree)
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;

    # read lowering (signals backends; no-op on React/Preact) - #6677 + PR 5b
    def lower_state_read(name: str) -> es.Expression;
    def lower_view_expr(expr: es.Expression) -> es.Expression;
}
```

### 4. Backend registry + selection

- New dir `jac/jaclang/compiler/passes/ecmascript/backends/` with
  `react.jac` (+ impl). A tiny registry maps `"react" -> ReactBackend`,
  raising a clear diagnostic for an unknown name (reuse/extend the `E50xx`
  client diagnostic family in `jac0core/diagnostics.jac`).
- `EsastGenPass.before_pass` resolves the backend:

  ```jac
  import from jaclang.project.config { get_config }
  cfg = get_config();
  fw = cfg.client.framework if (cfg and cfg.client) else "react";
  self.backend = resolve_framework_backend(fw);  # default react on miss
  ```

  This matches `JacAutoLintPass.postinit`'s `get_config()` usage and needs **no
  schedule/constructor change**.

### 5. Runtime/platform surface (separate from lowering)

The symbol-source mapping (`runtime_import_source`, `RuntimeSymbol`), runtime
module selection, bundler aliases/plugins, and entry bootstrap are framework-
specific, but they are not part of AST lowering. Keep them behind an adjacent
runtime/platform seam rather than growing `FrameworkBackend`.

- `client_surface.jac` remains the single source of truth for runtime-import
  behavior, but it should resolve framework-specific policy through a dedicated
  runtime/platform abstraction rather than hardcoded React assumptions.
- Runtime source selection (`client_runtime*.cl.jac`), Vite aliases/plugins, and
  entry bootstrap should share the same framework selection, but not the same
  interface as compiler lowering.
- Enumerate every raw-React leak (today: only `useRef` from `react`) so each
  becomes an explicit runtime/platform decision instead of an incidental backend
  method.

---

## Workstreams (ordered; each a reviewable PR)

### PR 1 - Reactivity contract (spec only, no code change)

- `_planning/reactivity-contract.md` - per form: state identity & update/batching,
  effect deps + cleanup, view/render model, async boundary, event/closure identity.
- Include a **capability matrix**: React / Preact / Solid ×
  {supported, lowerable-with-shim, infeasible} per form.
- **Code-grounded read lowering:** audit which sites actually consume `exit_name`'s
  `gen.es_ast` (most write/binding/property sites rebuild from `sym_name` - no
  `NameRole` classifier unless audit finds a trap). See contract §4.1.
- **Honest scope limits:** block-level shadowing of reactive fields is a known v1
  limitation (`reactive_vars` is per-ability, not per-block). See contract §4.3.
- **`lower_state_read(name: str)`** must match #6677 literally in PR 5a; do not
  rename to `lower_reactive_read` without updating the issue.
- **JSX processor seam:** `lower_view_expr` touches shared `EsJsxProcessor` (Python +
  ECMAScript); plan for backend guard + cross-cutting review. See contract §4.2.
- **Architecture guardrail:** preserving `.cl.jac` syntax does not justify
  broadening `FrameworkBackend` to own runtime/bundler/bootstrap concerns.
- This is the acceptance test every future backend is checked against.

### PR 2 - Config: `[client] framework`

- `ClientConfig` + `JacConfig.client` + `_parse_toml_data` wiring in
  `jac/jaclang/project/config.jac`.
- Default `"react"`. Unit test in the project-config test suite.
- No codegen behavior change yet.

### PR 3 - Seam + ReactBackend (refactor, ZERO output diff) ← riskiest/most valuable

- Add `reactive_intent.jac`, `framework_backend.jac` (+impl),
  `backends/react.jac` (+impl), `backends/registry`.
- Move each table row above into `ReactBackend`, **verbatim** logic:
  - `_get_setter_name`, `useState`/`useRef` emission → `lower_state_field` /
    `lower_ref_field`.
  - `count = X → setCount(X)` (incl. aug-assign) → `lower_state_update`.
  - `_transform_to_useeffect` body → `lower_effect`.
  - `_build_awaiting_wrapper` + `<JacAwaiting>`/`<JacClientErrorBoundary>` →
    `lower_async_boundary`.
- Keep runtime-import/bundler/bootstrap decisions behind the runtime/platform
  seam; do not treat them as part of the long-term `FrameworkBackend` contract.
- `EsastGenPass` keeps `reactive_vars` **tracking** (structural) as
  `set[str]` (which vars are reactive). Setter *naming* moves into the backend.
  The pass asks the backend for update lowering by variable name.
- **Prerequisite**: audit all `reactive_vars` references across the ecmascript
  pass tree before editing (child passes, `exit_assignment`, `exit_aug_assign`,
  `enter_ability`/`exit_ability`).
- `before_pass` resolves `self.backend` via `get_config()`.
- If a temporary implementation colocates runtime/platform helpers with the
  backend for sequencing reasons, treat that as transitional and document the
  split target in-code.
- **Acceptance**: `jac/tests/compiler/passes/ecmascript/` golden tests pass
  byte-for-byte. Any diff must have a mechanical, reviewable explanation.
- Add release note `docs/docs/community/release_notes/unreleased/jaclang/<PR#>.refactor.md`.

### PR 4 - Preact backend (proof the seam is real)

- `backends/preact.jac` - differs only in import sources/runtime module, not
  reactivity model. Add a `client_runtime` Preact variant or alias.
- Parametrize the existing ecmascript fixtures to also run under
  `framework = "preact"`; assert they compile and differ only in imports.
- Release note `<PR#>.feature.md`.

### PR 5a - `lower_state_read` seam ([#6677](https://github.com/jaseci-labs/jaseci/issues/6677))

- Add `lower_state_read(name: str) -> es.Expression` to `FrameworkBackend`.
- React/Preact: bare identifier (zero diff). Thread through `exit_name` for names
  in `reactive_vars` (mostly safe - write targets do not consume Name `es_ast`).
- Fixture: stub Solid backend emits `count()` not `count`.
- **After PR 3, before PR 5c.** Signature must match #6677 acceptance criteria.

### PR 5b - `lower_view_expr` + JSX processor wiring

- Add `lower_view_expr(expr) -> es.Expression` (no-op on React/Preact).
- Wire in `EsJsxProcessor` only (guard Python path). Event attrs: `on[A-Z]…` prefix
  heuristic - do not view-wrap handlers. See contract §4.2.

### PR 5c - Signals backend (proof the seam survives model divergence)

- `backends/solid.jac` (or ripple) - depends on 5a + 5b.
- Compile representative subset (counter, effect, async boundary, dynamic JSX).
- Document gaps: refs deferred, block shadowing, functional-updater asymmetry,
  `solid-js/h` limitations vs full compiler.
- Release note + promote the contract from `_planning/` to `docs/`.

---

## Acceptance criteria (from the issue)

- `EsastGenPass` contains **no direct React primitive emission**; every table
  row routes through `FrameworkBackend`.
- React backend output is **identical to today** (golden tests green).
- A `framework = "preact"` build compiles the existing example apps.
- A signals backend compiles the representative subset, and the reactivity
  contract documents exactly what is supported / shimmed / infeasible per
  target.

---

## Risks & open questions

1. **Golden-test churn** - the PR 3 refactor must be output-stable. Mitigation:
   move logic verbatim; diff fixtures after each extracted form, not at the end.
2. **`reactive_vars` type change** - `dict[str,str] → set[str]` is mechanical
   for the pass itself but child passes or non-assignment sites may read the
   setter string. **Action: grep audit before editing.**
3. **`client_surface` / `with_runtime_globals` callers** - 5 paths (eject, HMR,
   cl test runner, jac_to_js, client_bundle) prepend runtime imports without
   a pass/backend instance. **Mitigation**: make `with_runtime_globals` accept
   an optional `framework` parameter (default `"react"`); compile-path callers
   pass `get_config().client.framework`.
4. **Dep inference location** - React reads explicit dep arrays; signals
   auto-track. `Effect.deps: list[es.Expression]` carries lowered expressions;
   backends consume or ignore.
5. **Element factory (`__jacJsx`)** - shared via `EsJsxProcessor`. For v1 keep
   `__jacJsx` as the neutral factory all current backends use; a fine-grained
   signals backend may need its own factory - capture in the contract, don't
   block PR 3 on it.
6. **`_build_awaiting_wrapper` entanglement** - This method calls
   `_build_view_iife()` and `_view_push_stmt()` (pass slot accumulator internals).
   **Fix**: the pass builds IIFEs, creates `AsyncBoundary` intent, and the
   backend *only assembles the wrapper expression*. The pass handles
   `_view_push_stmt`.
7. **Raw-React escapes** - only `useRef` (source `react`) today. Enumerate in
   the contract so each is an explicit backend decision.
8. **Maintenance cost** - N targets = N× test matrix. Build the seam now; gate
   additional targets on real demand (non-goal: ship all five).
9. **Block shadowing** - `reactive_vars` is per-ability, not lexical-block scoped.
   Local `let` shadowing a reactive field is a known Solid limitation in v1 unless
   block-scoped tracking is added. Do not claim fixture #5 passes without that work.
10. **Shared JSX processor** - `lower_view_expr` is a cross-cutting change in
    `jac0core/passes/ast_gen/jsx_processor.impl.jac`, not a trivial pass-local hook.
11. **Functional updater asymmetry** - aug-assign vs plain `count = count + 1` may
    both emit stale reads on Solid; document or fix in `lower_state_update`.

## Non-goals

- Shipping all five targets (v1 = React refactor + Preact proof + one signals).
- Per-component / mixed targets in one app.
- Non-JS targets (native, etc.).
- Changing `.cl.jac` author-facing syntax - only the lowering becomes pluggable.
- `lower_view` / `Memo` / `EventHandler` / `Effect.is_cleanup` in PR 3 -
  these are speculative; add only when a backend actually needs them.

---

## Pointers (verified paths)

- Pass: `jac/jaclang/compiler/passes/ecmascript/esast_gen_pass.jac` (+
  `impl/esast_gen_pass.impl.jac`)
- Shared IR/printer: `estree.jac`, `es_unparse.jac`
- Runtime-source seam: `jac/jaclang/runtimelib/client_surface.jac`,
  `jac/jaclang/runtimelib/client_runtime.cl.jac`
- Compile entry: `jac/jaclang/runtimelib/client/jac_to_js.jac` (+ impl)
- Schedule: `jac/jaclang/jac0core/compiler.jac:195` (`get_py_code_gen`)
- Config: `jac/jaclang/project/config.jac`
- Config-in-pass pattern: `jac/jaclang/compiler/passes/tool/impl/jac_auto_lint_pass.impl.jac`
- Tests/fixtures: `jac/tests/compiler/passes/ecmascript/`
- Prior art: TSRX (`Ripple-TS/ripple`) - one parser → `@tsrx/core` (shared transform factory) → per-framework descriptors (`react_platform`, `preact_platform`, `solid_platform`). React/Preact differ only in import sources; Solid uses hooks (`initialState`, `controlFlow`, `injectImports`) for model divergence.
