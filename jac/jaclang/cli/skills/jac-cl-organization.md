---
name: jac-cl-organization
description: Structuring a multi-component client app - the stateful-shell architecture (one component owns state, prop-drilled sections, handler bodies in .impl.jac), file layout, component reuse, hook pattern, createContext, domain-meaningful naming. Load before adding a new component, when a page file is growing, or when several components share state/fetching logic. Pair with `jac-cl-components` (what goes inside each file).
---

**First-choice architecture for small/medium apps: the stateful shell.** One page-level component owns ALL of that page's reactive `has` fields and async handlers, and prop-drills data + `Callable` callbacks into stateless section components. Handler bodies live in the paired `.impl.jac` annex (see `jac-impl-files`). Real Jac apps with a dozen sections run entirely on this - zero hooks, zero contexts. Escalate only when it stops fitting: a **hook** when the same fetch+state unit must be reused by several components, a **context** when distant components must see the same live values.

Components need no marker: a `def:pub` returning JSX in a plain `.jac` file is placed client by inference, and the helpers/`glob`s it references follow it into the bundle (see `jac-codespaces`). The `.cl.jac` extension used in the layouts below is the optional explicit convention - good for making the boundary visible in a large tree - not a requirement.

## The stateful shell

The shell declares the state in one `has` block (14 fields is normal, not a smell), handler stubs, and a render that wires the sections:

```
def:pub Showcase -> JsxElement {
    has guestbook: list[GuestEntry] = [],
        gbName: str = "",
        gbMessage: str = "",
        gbSigning: bool = False;          # ... one block, all page state

    can with entry { loadInitial(); }

    async def loadInitial -> None;        # bodies in <thisfile>.impl.jac
    async def signGuestbook -> None;

    return <main>
        <HeroSection/>                    # static section - takes no props
        <FullstackSection
            entries={guestbook}
            name={gbName}
            onNameChange={lambda (v: str) { gbName = v; }}
            onSign={signGuestbook}
            signing={gbSigning}
        />
    </main>;
}
```

Sections are stateless `def:pub` functions over typed props: data flows down, events flow up through `Callable[[str], None]` / `Callable[[], None]` callbacks (see `jac-cl-components`). A section MAY keep purely-local UI state (`has copied: bool` for a copy button, an open/closed toggle) - state belongs in the shell only when the shell or a sibling section needs it.

## File layout

```
my-app/
├── main.jac                    # entry - def:pub app; its shape depends on the
│                               #   routing system you picked (jac-cl-routing)
├── pages/                      # route targets - each page is a stateful shell
│   ├── index.jac               # with file-based routing these ARE the routes
│   ├── RecipesPage.cl.jac      #   (see jac-cl-routing); else components/pages/
│   └── RecipesPage.impl.jac    # that page's handler bodies (jac-impl-files)
├── components/
│   ├── Button.cl.jac           # reusable leaf
│   ├── ItemCard.cl.jac
│   ├── ItemCard.style.css      # optional scoped styles - SAME basename
│   └── ItemList.cl.jac         # composes ItemCard
├── services/
│   ├── recipes.sv.jac          # server endpoints + types (see jac-sv-endpoints)
│   └── wsService.cl.jac        # client-side service module (WebSocket, API glue)
├── hooks/
│   └── useItems.cl.jac         # only for REUSED fetch+state units - `use` prefix
└── lib/
    └── utils.cl.jac            # pure helper fns (cn, formatDate)
```

The extensions in this tree are the explicit style - every one of these files also works as plain `.jac` with placement inferred; keep whichever convention the project already uses. Service modules separate transport logic from UI: server endpoint modules live under `services/` (plain `.jac` is equally idiomatic - server is the default; `.sv.jac` is the explicit pin); a client service module (e.g. `wsService.cl.jac`) holds client-side WebSocket/API plumbing with `glob` module state (see `jac-cl-js-interop`). Components and hooks import from services - never the reverse.

## Hook pattern - reusable fetch+state units

A hook is a `def:pub` function that owns reactive state + handlers and returns a dict; consumers destructure with `[key]`. Reach for one when the same async-fetch + handler logic recurs in ≥2 components - not as the default home for page state (that's the shell).

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

In a real hook, replace the local `Item` declaration with `sv import from ..services.todo { Item, get_items, add_item }` (2 dots = up one folder from `hooks/` into `services/`) and call those in `async can with entry` / handlers. Consume as `data = useItems(); items = data["items"] or [];` - `[key]` access, not `.get()`. See `jac-fullstack-patterns`.

## Global state: createContext / useContext

⚠ **A custom hook does NOT share state between two consumers.** Every `useItems()` call creates its OWN `useState` instances - hooks share *logic*, not *state*. When components too far apart to prop-drill (current user, theme, cart) must see the same live values, use a context:

```jac
import from react { createContext, useContext }

glob AppCtx = createContext(None);

# Provider owns the state - mount ONCE near the app root
def:pub AppProvider(children: any = None) -> JsxElement {
    has user: any = None;
    has theme: str = "light";
    value = {
        "user": user, "theme": theme,
        "setUser": lambda (u: any) -> None { user = u; },
        "setTheme": lambda (t: str) -> None { theme = t; },
    };
    return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

# Any descendant reads/writes the SAME state
def:pub ThemeToggle() -> JsxElement {
    ctx: any = useContext(AppCtx);
    return <button onClick={lambda {
        ctx.setTheme("dark" if ctx.theme == "light" else "light");
    }}>Theme: {ctx.theme}</button>;
}
```

Wire it in the entry: `def:pub app() -> JsxElement { return <AppProvider><AppShell /></AppProvider>; }`. (That no-argument shape is the manual/single-page entry. With file-based routing `app` instead takes `children` and must render it, so wrap `{children}` rather than a shell - see `jac-cl-routing`.) Annotate the consumer's `ctx: any` - a bare `ctx = useContext(...)` is Unknown-typed and `ctx.user` fails `jac check` with E1032. In a shell-architected app the provider is rarely needed - the shell already sees everything; reach for context only when ≥2 *distant* consumers exist.

## jac-shadcn project layout

When the project has `components/ui/` (jac-shadcn primitives are pre-installed): `components/ui/` holds the managed primitives (`button.cl.jac`, `card.cl.jac`, ...) - **import only, never edit**; your composite components and shells sit above them in `components/` and `pages/` exactly as in the layout above. Load `jac-shadcn-components` for import patterns and the component selection table, `jac-shadcn-blocks` for multi-component composition patterns.

## Rules

- **Default to the shell.** Page state and handlers live in ONE stateful component per page; sections receive props + callbacks. Don't pre-extract hooks/contexts for state only one page uses.
- **One file per page/section, basename matches the main export** (`Button.jac` or `Button.cl.jac` → `Button`). File-local `def:pub` helpers are fine - a section file exporting both `MicroservicesSection` and its small `ProcBox` building block is good practice; move a helper to `components/` only when a second file needs it.
- **In jac-shadcn projects, scan `components/ui/` before building any UI element.** If a primitive exists (Button, Card, Input, Badge, Dialog, Table, ...), import it - do not re-implement it. Never edit files in `components/ui/` (registry-managed); compose with them in your own files.
- **Reuse before creating.** Scan `components/` and `pages/` before writing a new file. Duplicate UI = default mistake.
- **Scoped styles share the basename.** `Button.style.css` beside the component file (`Button.cl.jac` or `Button.jac`) auto-scopes, no import. See `jac-cl-styling`.
- **PascalCase** for components + files: `UserCard.jac` / `UserCard.cl.jac`. `snake_case` for variables and handlers.
- **Pages are thin orchestrators of sections.** JSX > ~80 lines in a shell's return = extract blocks into section components (props down, callbacks up); handler bodies > a screenful = move to the `.impl.jac`.
- **Domain-meaningful names, not structural.** `CalculatorApp`, not `App`. `recipes_data`, not `data`. `services/recipes.sv.jac`, not `services/api.sv.jac`. Generic `Layout`/`App` only for the single top-level wrapper.
- **Hook name = `use<DomainNoun>`** (`useRecipes`, NOT `useData`); hooks live under `hooks/`, return dicts consumed with `[key]`. Don't call a hook from a non-component `def` - `has` fields only wire up inside `def:pub` that renders JSX or inside another `useXxx()`.
- **Extract to a hook when** the same fetch+state *logic* recurs in ≥2 components. If ≥2 components must see the same *live values*, a hook is NOT enough - use the context pattern above.

## See also

- `jac-impl-files` - the `.impl.jac` handler annex the shell pattern relies on
- `jac-cl-components` - single-component shape, props/`Callable` typing, state, events
- `jac-fullstack-patterns` - cl→sv import rules inside shells and hooks
- `jac-shadcn-blocks` - composition patterns for auth cards, app shells, data tables, and more
