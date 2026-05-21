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
│   ├── ItemList.cl.jac        # composes ItemCard
│   ├── Layout.cl.jac          # app shell
│   └── pages/
│       ├── AuthPage.cl.jac    # top-level route targets - thin orchestrators
│       └── RecipesPage.cl.jac
├── hooks/
│   └── useItems.cl.jac        # shared data + handlers, `use` prefix
└── lib/
    └── utils.cl.jac           # pure helper fns (cn, formatDate)
```

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
- **PascalCase** for components + files: `UserCard.cl.jac`. `snake_case` for variables, handlers, hooks.
- **Pages are thin orchestrators.** Read a hook, render a layout, pass data down. JSX > ~80 lines in a page = extract blocks into `components/`.
- **Domain-meaningful names, not structural.** `CalculatorApp`, not `App`. `recipes_data`, not `data`. `services/recipes.sv.jac`, not `services/api.sv.jac`. Generic `Layout`/`App` only for the single top-level wrapper.
- **Hook name = `use<DomainNoun>`** - `useRecipes`, `useAuth`. NOT `useData`, `useStuff`.
- **Hooks live under `hooks/`, components under `components/`.** Don't mix.
- **Hook return dicts use `[key]` access, not `.get()`** - see `jac-cl-components`.
- **Don't call a hook from a non-component `def`.** `has` fields only wire up inside `def:pub` that renders JSX or inside another `useXxx()`.
- **Extract to a hook when:** data involves async fetch, OR it's shared across ≥2 components, OR there are 3+ related handlers on the same state. Otherwise keep state inline in the component.

## See also

- `jac-cl-components` - single-component shape, state, events, JSX rules
- `jac-fullstack-patterns` - cl→sv import rules inside hooks
