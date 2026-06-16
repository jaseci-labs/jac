# Implementation Guide: Issue 6490 - Framework-agnostic web codegen

## Goal

Make Jac's client codegen (`.cl.jac` / `cl {}` → JavaScript) framework-agnostic by extracting a `FrameworkBackend` seam from `EsastGenPass`. The pass currently hard-wires React semantics directly into the ESTree it emits. After this work, the pass emits a **framework-neutral reactive-intent vocabulary** and a pluggable backend lowers that intent to ESTree.

Preserving existing client syntax is non-negotiable. The implementation goal is
to keep `.cl.jac` authoring source-compatible while refactoring the internals so
framework-specific behavior is isolated behind production-ready seams.

---

## Current State (verified against tree)

All React-specific code lives inside `jac/jaclang/compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac`:

| Reactive form | Jac source | Current React lowering | Site in impl |
|---------------|-----------|------------------------|--------------|
| **State field** | `has count: int = 0;` | `const [count, setCount] = useState(0)` | `exit_arch_has` (~3960) |
| **Ref field** | `has r: Ref[T];` | `const r = useRef(null)` | `exit_arch_has` (~3903) |
| **State update** | `count = X` | `setCount(X)` | `exit_assignment` (~1885) |
| **Setter naming** | - | `count` → `setCount` | `_get_setter_name` (~3713) |
| **Effect** | `can with entry { ... }` | `useEffect(() => {...}, [deps])` | `_transform_to_useeffect` (~3776+) |
| **Async boundary** | `try { ...await... } awaiting {...}` | `<JacAwaiting>` + `<JacClientErrorBoundary>` | `_build_awaiting_wrapper` (~3070) |
| **View / JSX** | `<div>...</div>` | `__jacJsx(...)`, fragments | `exit_jsx_element` (~3700) |
| **Runtime imports** | (implicit) | `useState`/`useEffect`/`useRef`/`__jacJsx`/`JacAwaiting` injected | `_inject_runtime_import` (~3754) |

State on `EsastGenPass` (`esast_gen_pass.jac:191`):

- `reactive_vars: dict[str, str]` - `var_name -> setter_name`. **Tracking is structural**; **setter naming is React-specific**.
- `reactive_vars_stack` - save/restore per function boundary.
- `injected_imports: set[str]` - dedup for `_inject_runtime_import`.

Already-neutral layers (do not touch):

- `estree.jac` - ESTree AST definitions.
- `es_unparse.jac` - ESTree → JS printer.
- `primitives_es.jac` + `jac_runtime_js.jac` - Jac primitive `_jac.*` ops.
- `jac0core/passes/ast_gen/jsx_processor.jac` - JSX tag lowering (shared with server).

Runtime-source seam:

- `jac/jaclang/runtimelib/client_surface.jac` - maps emitted runtime symbols to their source (`@jac/runtime` vs raw `react`).
- `jac/jaclang/runtimelib/client_runtime.cl.jac` - the `@jac/runtime` virtual module, React-backed.

Config:

- `jac/jaclang/project/config.jac` - `JacConfig` with one `*Config` per `jac.toml` section. **No `[client]` section exists yet**.
- `JacAutoLintPass.postinit` in `jac/jaclang/compiler/passes/tool/impl/jac_auto_lint_pass.impl.jac` shows the `get_config()` pattern for reading config inside a pass.

---

## Workstreams

### PR 2 - Config: `[client] framework`

Add `ClientConfig` to `jac/jaclang/project/config.jac`:

```jac
obj ClientConfig {
    has framework: str = "react";
}
```

Add `client: ClientConfig = ClientConfig()` to `JacConfig.has`.

Wire `_parse_toml_data` in `impl/config.impl.jac` (mirror `serve` / `run` parsing exactly). Also wire:

- `apply_profile` section map
- `merge_from_toml_file` section map

Default is `"react"`; selection is read once.

Add unit test in the project-config test suite. No codegen behavior change yet.

### PR 3 - Seam + ReactBackend (refactor, ZERO output diff)

Architecture guardrail for this PR:

- `FrameworkBackend` should own AST lowering only.
- Runtime import/source decisions, runtime-file selection, bundler aliases or
  plugins, and entry bootstrap are framework-specific but should live behind an
  adjacent runtime/platform seam, not accrete onto the lowering backend.
- If sequencing forces temporary co-location, treat it as transitional and keep
  the intended split explicit in code/comments/review notes.

#### 1. Neutral reactive-intent vocabulary

New file `jac/jaclang/compiler/passes/ecmascript/reactive_intent.jac`:

```jac
obj StateField {
    has name: str,
        init: es.Expression;
}

obj RefField {
    has name: str,
        init: es.Expression;
}

obj StateUpdate {
    has name: str,
        value: es.Expression,
        aug_op: (str | None) = None;
}

obj Effect {
    has body: list[es.Statement],
        deps: list[es.Expression];
}

obj AsyncBoundary {
    has body: list[es.Statement],
        awaiting: (es.Expression | None),
        excepts: list[es.Expression];
}
```

Records hold structural facts only; nothing React-specific (`setCount`, `useState`, `<JacAwaiting>`) lives in them.

#### 2. Backend interface

New file `jac/jaclang/compiler/passes/ecmascript/framework_backend.jac`:

```jac
obj BackendCaps {
    has memo: bool = False,
        cleanup: bool = True,
        async_boundary: bool = True;
}

obj FrameworkBackend(ABC) {
    def name -> str;
    def capabilities -> BackendCaps;

    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;

    # read lowering (signals backends; no-op on React/Preact)
    def lower_state_read(name: str) -> es.Expression;   # #6677
    def lower_view_expr(expr: es.Expression) -> es.Expression;

    # JSX factory name for shared EsJsxProcessor (v1: all backends use __jacJsx)
    def jsx_factory_name -> str;
}
```

Keep this interface narrow. Do not treat "we must preserve source syntax" as a
reason to fold runtime/bundler/bootstrap policy into the same object.

#### 3. ReactBackend

New dir `jac/jaclang/compiler/passes/ecmascript/backends/`:

- `react.jac` (declaration) + `impl/react.impl.jac` (verbatim move from existing pass sites)
- `registry.jac` - maps `"react" -> ReactBackend`, raises `E5081` for unknown names

Move each table row above into `ReactBackend` **verbatim**:

- `_get_setter_name`, `useState`/`useRef` emission → `lower_state_field` / `lower_ref_field`
- `count = X → setCount(X)` (incl. aug-assign) → `lower_state_update`
- `_transform_to_useeffect` body → `lower_effect`
- `_build_awaiting_wrapper` → `lower_async_boundary`

**Incremental verification**: extract and diff after each form (state, then effects,
then async boundaries), not at the end. This catches output drift immediately.

#### 4. EsastGenPass refactor

Add to pass header:

```jac
has backend: (FrameworkBackend | None) = None;
```

Change `reactive_vars`:

```jac
# Before: dict[str, str]  (var_name -> setter_name)
# After:  set[str]         (which vars are reactive)
reactive_vars: set[str] = set(),
reactive_vars_stack: list[set[str]] = [],
```

In `before_pass` (~6750):

```jac
import from jaclang.project.config { get_config }
cfg = get_config();
fw = cfg.client.framework if (cfg and cfg.client) else "react";
self.backend = resolve_framework_backend(fw);
```

In `exit_arch_has`: build `StateField` / `RefField` intent, append `self.backend.lower_*(...)`.

In `exit_assignment`: if target in `self.reactive_vars`, build `StateUpdate`, emit `self.backend.lower_state_update(...)` as `ExpressionStatement`.

In `_transform_to_useeffect`: build `Effect` intent, call `self.backend.lower_effect`.

In `_build_awaiting_wrapper`: build `AsyncBoundary` intent, call `self.backend.lower_async_boundary`.

#### 5. Runtime-import consumers

`client_surface.jac` should become framework-driven without turning
`FrameworkBackend` into a general platform object. Introduce or preserve a
dedicated runtime/platform resolver for:

- symbol-source mapping
- prepended runtime globals
- runtime `.cl.jac` source selection
- bundler aliases/plugins
- entry bootstrap generation

Consumers:

- `esast_gen_pass.impl.jac`
- `jac_to_js.impl.jac`
- `eject.impl.jac`
- `hmr.impl.jac`
- `cl_test_runner.impl.jac`

Possible shape:

```jac
def with_runtime_globals(js_code: str, framework: str = "react") -> str;
```

Compile-path callers pass or resolve the framework name from config; legacy
callers use the default to avoid breaking non-compile paths.

#### Acceptance

`jac/tests/compiler/passes/ecmascript/` golden tests pass byte-for-byte.

### PR 4 - Preact backend

`backends/preact.jac` - differs only in `import_source` (returns `"preact/compat"` instead of `"react"` for `useRef`, etc.) and `runtime_module`.

Parametrize existing ecmascript fixtures to also run under `framework = "preact"`; assert they compile and differ only in imports.

### PR 5a - `lower_state_read` ([#6677](https://github.com/jaseci-labs/jaseci/issues/6677))

Add to `framework_backend.jac` - **literal issue signature, do not rename:**

```jac
def lower_state_read(name: str) -> es.Expression;
```

React/Preact (`backends/impl/react.impl.jac`):

```jac
impl ReactBackend.lower_state_read(name: str) -> es.Expression {
    return es.Identifier(name=name);
}
```

`exit_name` (~221 in `esast_gen_pass.impl.jac`):

```jac
if nd.sym_name in self.reactive_vars {
    self._ensure_backend();
    nd.gen.es_ast = self.sync_loc(
        self.backend.lower_state_read(nd.sym_name), jac_node=nd
    );
    return;
}
```

**Mostly safe without `NameRole`:** assignment targets (`_convert_assignment_target`
~2411), member properties (`exit_atom_trailer` ~908), and reactive assignment
dispatch (`exit_assignment` ~2207) do not consume the target Name's `gen.es_ast`.
Audit genuine consumers (dict literal values, default param RHS) per
`_planning/reactivity-contract.md` §4.1.1.

Acceptance: fixture + test with Solid stub emits `count()` not `count`; React
golden tests unchanged.

### PR 5b - `lower_view_expr` + shared JSX processor

Add to `FrameworkBackend`:

```jac
def lower_view_expr(expr: es.Expression) -> es.Expression;
```

React/Preact: return `expr` unchanged.

Wire in `jac/jaclang/jac0core/passes/ast_gen/impl/jsx_processor.impl.jac`:

- `expression()` (~244) - wrap dynamic JSX children on ECMAScript path only.
- `normal_attribute()` (~191) - wrap dynamic attr values; **skip** attrs matching
  `on[A-Z]…` (event handler heuristic).

`EsJsxProcessor` is shared with `PyJsxProcessor` - guard so Python AST gen is
untouched. See `_planning/reactivity-contract.md` §4.2.

### PR 5c - Signals backend

`backends/solid.jac` - requires 5a + 5b. Fine-grained reactivity via `solid-js/h`;
best-effort subset, not full `dom-expressions` parity.

Compile representative subset. Document v1 gaps: **refs deferred**, **block
shadowing** (`reactive_vars` per-ability only), **functional-updater asymmetry**
(aug vs plain assign), event-attr heuristic fragility.

---

## Acceptance Criteria

- `EsastGenPass` contains **no direct React primitive emission**; every table row routes through `FrameworkBackend`.
- React backend output is **identical to today** (golden tests green).
- A `framework = "preact"` build compiles the existing example apps.
- A signals backend compiles the representative subset.

---

## Risks & Open Questions

1. **Golden-test churn** - Mitigation: move logic verbatim; diff fixtures after each extracted form, not at the end.
2. **`reactive_vars` ownership** - `set` split is safe for the pass itself, but
   child passes or non-assignment sites may read the setter string.
   **Action: grep audit all `reactive_vars` references before editing.**
3. **`_inject_runtime_import` dedup** - Currently keyed on `name`. Within one
   compilation there's only one backend, so this is fine. Document the limitation
   for future per-component backends.
4. **Element factory (`__jacJsx`)** - Shared via `EsJsxProcessor`. For v1 keep
   `__jacJsx` as the neutral factory; add `jsx_factory_name` to the backend
   interface when a signals backend actually needs a different factory (PR 5).
5. **`with_runtime_globals` callers** - eject, HMR, cl test runner call it
   without a pass instance. **Mitigation**: add optional `framework` parameter
   (default `"react"`); compile-path callers pass `get_config().client.framework`.
6. **`_build_awaiting_wrapper` entanglement** - Calls pass-internal slot
   accumulator (`_build_view_iife`, `_view_push_stmt`). **Fix**: pass builds
   IIFEs and `AsyncBoundary` intent; backend only assembles wrapper expression;
   pass handles `_view_push_stmt`.
7. **New diagnostic** - Add `E5081` in `jac0core/diagnostics.jac` for unknown
   framework names.
8. **Block shadowing** - `enter_ability`/`exit_ability` push/pop `reactive_vars`
   per function, not per block. Shadowing fixture #5 fails on Solid until
   block-scoped tracking or symbol-aware reads land.
9. **Shared JSX processor** - `lower_view_expr` changes `jsx_processor.impl.jac`
   (Python + ECMAScript); not pass-local.
10. **`lower_state_read` contract** - Must stay `lower_state_read(name: str)` for
    #6677; renaming requires issue update first.

---

## Prior Art (TSRX)

`Ripple-TS/ripple` (`@tsrx/core`) validates the architecture: one shared
`createJsxTransform(platform)` factory with per-framework descriptors.
React/Preact differ only in `imports` sources; Solid uses hooks
(`initialState`, `controlFlow`, `injectImports`) for model divergence.

Jac differs in granularity: TSRX is JSX-template-centric (one shared walker),
while Jac's `EsastGenPass` is language-level imperative (many `exit_*` methods
on AST nodes). Our class-based `FrameworkBackend` with `lower_*` methods is
more natural for Jac's structure. We keep the TSRX insight that Preact is
import-only and signals needs capability flags + custom hooks.

---

## Verified Paths

- Pass: `jac/jaclang/compiler/passes/ecmascript/esast_gen_pass.jac` + `impl/esast_gen_pass.impl.jac`
- Shared IR/printer: `estree.jac`, `es_unparse.jac`
- Runtime-source seam: `jac/jaclang/runtimelib/client_surface.jac`, `jac/jaclang/runtimelib/client_runtime.cl.jac`
- Compile entry: `jac/jaclang/runtimelib/client/jac_to_js.jac` + impl
- Config: `jac/jaclang/project/config.jac` + `impl/config.impl.jac`
- Config-in-pass pattern: `jac/jaclang/compiler/passes/tool/impl/jac_auto_lint_pass.impl.jac`
- Tests/fixtures: `jac/tests/compiler/passes/ecmascript/`
