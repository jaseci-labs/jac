---
name: jac-cl-organization
description: Structuring a multi-component client app - file layout, component reuse, hook pattern, domain-meaningful naming. Load before adding a new component, when a page file is growing, or when several components share state/fetching logic. Pair with `jac-cl-components` (what goes inside each file).
---

Two disciplines beyond single-component authoring: **reuse before creating** (scan `components/` first), and **extract shared state into a hook** (`def:pub useXxx()` under `hooks/`).

## File layout

```
my-app/
├── components/
│   ├── Button.cl.jac          # reusable leaf - ONE component per file
│   ├── ItemCard.cl.jac
│   ├── ItemCard.style.css     # optional scoped styles - SAME basename
│   ├── ItemList.cl.jac        # composes ItemCard
│   └── Layout.cl.jac          # app shell
├── pages/                     # route targets - thin orchestrators
│   ├── index.jac              # with file-based routing these ARE the routes
│   └── RecipesPage.cl.jac     #   (see jac-cl-routing); else components/pages/
├── services/
│   ├── recipes.sv.jac         # server endpoints + types (see jac-sv-endpoints)
│   └── wsService.cl.jac       # client-side service module (WebSocket, API glue)
├── hooks/
│   └── useItems.cl.jac        # shared data + handlers, `use` prefix
└── lib/
    └── utils.cl.jac           # pure helper fns (cn, formatDate)
```

Service modules separate transport logic from UI: `.sv.jac` files under `services/` hold server endpoints; a `.cl.jac` service module (e.g. `wsService.cl.jac`) holds client-side WebSocket/API plumbing with `glob` module state (see `jac-cl-js-interop`). Components and hooks import from services - never the reverse.

## Hook pattern

A hook is a `def:pub` function that owns reactive state + handlers and returns a dict. Consumers destructure the result with `[key]`.

```jac
node Item {
    has name: str = "";
}

def:pub useItems() -> dict {
    has items: list[Item] = [];
    has loading: bool = True;

    async can with entry {
        loading = False;
    }

    def handle_add(new_item: Item) {
        items = items + [new_item];
    }

    return {
        "items": items,
        "loading": loading,
        "handleAdd": handle_add,
    };
}
```

In a real hook, replace the local `Item` declaration with `sv import from ..services.todo { Item, get_items, add_item }` (2 dots = up one folder from `hooks/` into `services/`) and call those in `async can with entry` / handlers. See `jac-fullstack-patterns`.

Consuming:

```
import from .hooks.useItems { useItems }

def:pub ItemList() -> JsxElement {
    data = useItems();
    items = data["items"] or [];
    if data["loading"] { return <p>Loading...</p>; }
    return <ul>{for i in items { if i is not None { <li key={jid(i)}>{i.name}</li> } }}</ul>;
}
```

## Global state: createContext / useContext

⚠ **A custom hook does NOT share state between two consumers.** Every `useItems()` call creates its OWN `useState` instances - two components calling the same hook see two independent copies. Hooks share *logic*, not *state*. For state that multiple components must see (current user, theme, cart), use a context:

```jac
import from react { createContext, useContext }

glob AppCtx = createContext(None);

# Provider owns the state - mount ONCE near the app root
def:pub AppProvider(children: any = None) -> JsxElement {
    has user: any = None;
    has theme: str = "light";
    value = {
        "user": user, "theme": theme,
        "setUser": lambda u: any -> None { user = u; },
        "setTheme": lambda t: str -> None { theme = t; },
    };
    return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

# Any descendant reads/writes the SAME state
def:pub ThemeToggle() -> JsxElement {
    ctx: any = useContext(AppCtx);
    return <button onClick={lambda -> None {
        ctx.setTheme("dark" if ctx.theme == "light" else "light");
    }}>Theme: {ctx.theme}</button>;
}
```

Wire it in the entry: `def:pub app() -> JsxElement { return <AppProvider><AppShell /></AppProvider>; }`. Annotate the consumer's `ctx: any` - a bare `ctx = useContext(...)` is Unknown-typed and `ctx.user` fails `jac check` with E1032. Reach for context only when ≥2 distant components need the same state; otherwise a hook (below) or plain props.

## jac-shadcn project layout

When the project has `components/ui/` (jac-shadcn primitives are pre-installed):

```
my-app/
├── components/
│   ├── ui/                        # ← primitives - import only, never edit
│   │   ├── button.cl.jac
│   │   ├── card.cl.jac
│   │   └── ...                    # 50+ components
│   ├── EventCard.cl.jac           # ← your composite components using primitives
│   ├── EventList.cl.jac
│   └── pages/
│       └── EventsPage.cl.jac
├── hooks/
│   └── useEvents.cl.jac
└── lib/
    └── utils.cl.jac               # cn() - always import from here
```

Load `jac-shadcn-components` for the import patterns and full component selection table.

## Rules

- **In jac-shadcn projects, scan `components/ui/` before building any UI element.** If a primitive exists (Button, Card, Input, Badge, Dialog, Table, etc.), import it - do not re-implement it. Load `jac-shadcn-components` for the import syntax and composition rules.
- **Never edit files in `components/ui/`.** These are managed by the jac-shadcn registry. Compose with them in `components/` files instead.
- **Reuse before creating.** Scan `components/` and `components/pages/` before writing a new file. Duplicate UI = default mistake.
- **One exported component per file**, basename matches export. `Button.cl.jac` → `Button`.
- **Scoped styles share the basename.** For plain component CSS, add `Button.style.css` beside `Button.cl.jac` -- classes auto-scope to that component, no import. See `jac-cl-styling`.
- **PascalCase** for components + files: `UserCard.cl.jac`. `snake_case` for variables, handlers, hooks.
- **Pages are thin orchestrators.** Read a hook, render a layout, pass data down. JSX > ~80 lines in a page = extract blocks into `components/`.
- **Domain-meaningful names, not structural.** `CalculatorApp`, not `App`. `recipes_data`, not `data`. `services/recipes.sv.jac`, not `services/api.sv.jac`. Generic `Layout`/`App` only for the single top-level wrapper.
- **Hook name = `use<DomainNoun>`** - `useRecipes`, `useAuth`. NOT `useData`, `useStuff`.
- **Hooks live under `hooks/`, components under `components/`.** Don't mix.
- **Hook return dicts use `[key]` access, not `.get()`** - see `jac-cl-components`.
- **Don't call a hook from a non-component `def`.** `has` fields only wire up inside `def:pub` that renders JSX or inside another `useXxx()`.
- **Extract to a hook when:** data involves async fetch, OR the same *logic* recurs in ≥2 components, OR there are 3+ related handlers on the same state. Otherwise keep state inline. If ≥2 components must see the same *live values*, a hook is NOT enough - use the context pattern above.

## See also

- `jac-cl-components` - single-component shape, state, events, JSX rules
- `jac-fullstack-patterns` - cl→sv import rules inside hooks
