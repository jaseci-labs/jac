# Compiler IR: upstream main vs jac-svelte

Reference for PR review. Compares the client codegen pipeline at merge-base
`origin/main` with this branch.

**Last updated:** 2026-06-19 (View IR Branch 5 + dom-expressions path landed).

---

## Pipeline overview

On **main**, Jac AST fed a single React-shaped ESTree emitter. This branch
inserts **reactive_intent** and **view_ir** as framework-neutral middle layers;
`FrameworkBackend` lowers the same IR to `__jacJsx` (React/Preact) or JSX
estree with native `<For>` / `<Show>` (Solid).

```mermaid
flowchart TB
    subgraph MAIN["Upstream main"]
        JA1["Jac AST<br/>(uni.*)"]
        EP1["EsastGenPass<br/>(monolithic)"]
        JXP1["EsJsxProcessor"]
        EST1["ESTree<br/>expressions + statements only"]
        OUT1["JS output<br/>__jacJsx + useState/useEffect"]

        JA1 --> EP1
        JA1 --> JXP1
        JXP1 -->|"direct emit"| EST1
        EP1 -->|"inline React hooks"| EST1
        EST1 --> OUT1
    end

    subgraph BRANCH["This PR (jac-svelte)"]
        JA2["Jac AST<br/>(uni.* - unchanged)"]
        EP2["EsastGenPass"]
        JXP2["EsJsxProcessor<br/>(producer)"]
        RI["reactive_intent<br/>StateField · RefField · StateUpdate<br/>Effect · AsyncBoundary"]
        VI["view_ir<br/>ViewElement tree<br/>HostTag · EventAttr · RefAttr<br/>IfChild · EachChild · …"]
        FB["FrameworkBackend<br/>react · preact · solid"]
        EST2["ESTree<br/>+ JSX node types (Solid)"]
        OUT_R["React/Preact<br/>__jacJsx + hooks"]
        OUT_S["Solid<br/>JSX estree + For/Show<br/>+ createSignal thunks"]

        JA2 --> EP2
        JA2 --> JXP2
        EP2 --> RI
        JXP2 --> VI
        RI --> FB
        VI --> FB
        FB --> EST2
        EST2 --> OUT_R
        EST2 --> OUT_S
    end
```

---

## View IR: same tree, different backends

`EsJsxProcessor` builds one `ViewElement` tree. Classification (host vs
component, event vs ref vs dynamic, control-flow lifts) runs **once** in the
producer. Backends consume the same IR differently.

```mermaid
flowchart LR
    subgraph INPUT["Author writes"]
        SRC["{ labels.map … }<br/>{ p if show else p }<br/>ref={r} onClick={fn}"]
    end

    subgraph PRODUCER["EsJsxProcessor (once)"]
        VE["ViewElement"]
        SRC --> VE
    end

    subgraph REACT["ReactBackend.lower_view"]
        R1["IfChild/EachChild → js_fallback<br/>(?: and .map - unchanged)"]
        R2["DynamicChild → expr as-is"]
        R3["RefAttr / EventAttr → never thunked"]
        R4["→ __jacJsx(tag, props, children)"]
        VE --> R1 & R2 & R3 --> R4
    end

    subgraph SOLID["SolidBackend.lower_view"]
        S1["IfChild → Show"]
        S2["EachChild → For"]
        S3["DynamicChild/Attr → expr (dom-expressions tracks)"]
        S4["RefAttr / EventAttr → never thunked"]
        S5["→ JsxElement estree<br/>(babel-preset-solid)"]
        VE --> S1 & S2 & S3 & S4 --> S5
    end
```

### View IR node set (`view_ir.jac`)

| Node | Role |
|------|------|
| `ViewElement` | Root: tag + attrs + children |
| `HostTag` / `ComponentTag` / `FragmentTag` / `DynamicTag` | Tag resolved once |
| `StaticAttr` / `DynamicAttr` / `EventAttr` / `RefAttr` / `SpreadAttr` | Attr classified once |
| `TextChild` / `DynamicChild` / `ElementChild` | Children |
| `SlotChild` | `{ stmt; … }` (prebuilt IIFE; Svelte debt) |
| `IfChild` / `EachChild` | Lifted control flow (Branch 4) + `js_fallback` for JS family |

**Invariant:** dynamic values in View IR are neutral `es.Expression`s. Solid
thunks in `lower_view`; React passes through. `ref` and event handlers are
never thunked.

---

## Reactive IR (`reactive_intent.jac`)

Main inlined `useState` / `useEffect` inside `EsastGenPass`. This branch emits
neutral records; the backend lowers them.

```mermaid
flowchart LR
    HAS["has count: int = 0"]
    CAN["can { … }"]

    HAS --> SF["StateField<br/>{ name, init_expr }"]
    CAN --> EF["Effect<br/>{ body, deps }"]

    SF --> RB["FrameworkBackend"]
    EF --> RB

    RB --> R["React: useState / useEffect"]
    RB --> S["Solid: createSignal / createEffect<br/>+ lower_state_read → count()"]
```

---

## What stayed the same

- Jac AST (`uni.*`) and `.cl.jac` syntax
- React emitted JS for non-lifted paths (pinning tests green)
- Most non-JSX lowering still Jac AST → ESTree in `EsastGenPass`

## Known IR debt

- `SlotChild` carries a JS-family IIFE, not template-neutral facts
- `js_fallback` on `IfChild`/`EachChild` is a React-shaped escape hatch
- `&&` short-circuit not lifted (`DynamicChild` only)
- `unsafe_html` has no structured `innerHTML` marker yet

## Related docs

- `docs/framework-view-ir-plan.md` - full View IR plan
- `docs/solid-dom-expressions-plan.md` - Solid JSX / dom-expressions path
- `docs/tanstack-form-migration-gaps.md` - TanStack Form migration (complete)
- `docs/remaining-work.md` - open follow-ups
