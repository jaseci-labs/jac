---
name: jac-cl-organization
description: Structuring a multi-component client app - the stateful-shell architecture (one component owns state, prop-drilled sections, handler bodies in .impl.jac), file layout, component reuse, hook pattern, createContext, domain-meaningful naming. Load before adding a new component, when a page file is growing, or when several components share state/fetching logic. Pair with `jac-cl-components` (what goes inside each file).
---

**First-choice architecture for small/medium apps: the stateful shell.** One page-level component owns ALL of that page's reactive `has` fields and async handlers, and prop-drills data + `Callable` callbacks into stateless section components. Handler bodies live in the paired `.impl.jac` annex (see `jac-impl-files`). Real Jac apps with a dozen sections run entirely on this - zero hooks, zero contexts. Escalate only when it stops fitting: a **hook** when the same fetch+state unit must be reused by several components, a **context** when distant components must see the same live values.

Components need no annotation: a `def:pub` returning JSX in a plain `.jac` file is placed client by inference, and the helpers/`glob`s it references follow it into the bundle (see `jac-codespaces`). When inference must be overridden, pin the element in `jac.toml` via `[placement.pins]` - placement never appears in the source.

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

    <main>
        <HeroSection/>                    # static section - takes no props
        <FullstackSection
            entries={guestbook}
            name={gbName}
            onNameChange={lambda (v: str) { gbName = v; }}
            onSign={signGuestbook}
            signing={gbSigning}
        />
    </main>
}
```

Sections are stateless `def:pub` functions over typed props: data flows down, events flow up through `Callable[[str], None]` / `Callable[[], None]` callbacks (see `jac-cl-components`). A section MAY keep purely-local UI state (`has copied: bool` for a copy button, an open/closed toggle) - state belongs in the shell only when the shell or a sibling section needs it.

## File layout

**Never sort files by which codespace they run in.** A `components/` + `services/` split does exactly that: it sorts by which machine runs the code. Jac infers placement per-declaration (see `jac-codespaces`), so that boundary is not an architectural fact and the directory tree has no business encoding it. Sort by what the code is *about* instead - that does not change when the compiler decides placement.

Two layouts, and the trigger between them is how many features the app has.

### Small app: flat, no catch-all

Under ~3 features, folders cost more than they explain. Keep it flat:

```
my-app/
├── main.jac                    # entry - def:pub app (see jac-cl-routing)
├── pages/                      # route targets, if you use file-based routing
├── recipes.jac                 # server endpoints + types (jac-sv-endpoints)
├── RecipeList.jac              # component - basename matches the export
├── RecipeCard.jac
├── RecipeCard.style.css        # optional scoped styles - SAME basename
└── utils.jac                   # pure helper fns (cn, formatDate)
```

This is what `jac create` scaffolds and it is a fine terminal state for a small app. Note there is no bucket named `lib/` or `services/` for things to be dumped into by default.

### Multi-feature app: one folder per feature

At ~3+ real features, give each its own folder holding **both codespaces side by side**:

```
my-app/
├── main.jac
├── pages/                      # thin route targets that re-export from features
├── recipes/
│   ├── store.jac               # server: node/edge schema, walkers, def:pub endpoints
│   ├── store.test.jac          # tests live next to what they test
│   ├── RecipesShell.jac        # client shell (jac-cl-components)
│   ├── RecipesShell.impl.jac   # handler bodies (jac-impl-files)
│   └── RecipeCard.jac
├── billing/
│   ├── invoices.jac
│   └── InvoiceTable.jac
├── hooks/                      # only for REUSED fetch+state units - `use` prefix
└── shared/                     # PROMOTION destination - see the rule below
    ├── ui/                     # jac-shadcn primitives, if present
    ├── Button.jac
    └── utils.jac            # cn()
```

**`shared/` is a promotion destination, not a default one.** A module lives with the feature that owns it until a *second feature* needs it; only then does it move. That is the whole difference from a catch-all, and it keeps `shared/` small: a `Reveal` wrapper with nine consumers stays put if all nine are sections of the same feature.

**Features may depend on features.** A landing page embedding a source browser imports it directly. Only leaf utilities with no natural home get promoted.

`pages/` is fixed by the router - file-based routing scans that exact directory.

**jac-shadcn primitives follow your layout, not the other way round.** `jac install --shadcn` writes to `components/ui/` by default, but if you keep the primitives somewhere else (`shared/ui/`, a feature folder) it finds them, installs alongside, and rewrites each primitive's `cn` import to wherever your `utils` module actually lives. Pin it explicitly if you prefer:

```toml
[jac-shadcn]
components_dir = "shared/ui"      # where primitives live
utils_path = "shared/utils.jac" # where cn() lives
```

### Import forms - two rules, neither stylistic

- **Within a feature, use the sibling form.** A client shell reaches its own server module with `import from .store { Recipe, list_recipes }` - a plain import; the compiler sees the target is server-placed and generates the RPC stub (`jac-codespaces`). The entire cross-codespace call is one dot, because both halves live together. This is the layout's main payoff.
- **Across packages, server modules use the no-dot absolute form:** `import from shared.github { fetch }`, never `..shared.github`. A `..` that climbs out of a feature folder resolves under `jac start` but fails `jac test <file>` with `attempted relative import beyond top-level package`, because the test runner roots the package at the target file's own directory. Client modules keep the dotted form (`..shared.utils`) - that is what the bundler resolves.

⚠ **A file move is a schema migration.** Archetype identity includes the module path, so moving a module that declares `node`/`edge` types orphans every persisted instance: the nodes stay in the store under the old path and graph queries in the moved module quietly match nothing. No error, no warning. Reorganize before a graph has data in it, or plan a re-ingest.

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

In a real hook, replace the local `Item` declaration with `import from ..todos.store { Item, get_items, add_item }` (2 dots = up one folder from `hooks/`, then into the feature) and call those in `async can with entry` / handlers. Consume as `data = useItems(); items = data["items"] or [];` - `[key]` access, not `.get()`. See `jac-fullstack-patterns`.

## Global state: createContext / useContext

⚠ **A custom hook does NOT share state between two consumers.** Every `useItems()` call creates its OWN `useState` instances - hooks share *logic*, not *state*. When components too far apart to prop-drill (current user, theme, cart) must see the same live values, use a context:

```jac
import from "react" { createContext, useContext }

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
    <AppCtx.Provider value={value}>{children}</AppCtx.Provider>
}

# Any descendant reads/writes the SAME state
def:pub ThemeToggle() -> JsxElement {
    ctx: any = useContext(AppCtx);
    <button onClick={lambda {
        ctx.setTheme("dark" if ctx.theme == "light" else "light");
    }}>Theme: {ctx.theme}</button>
}
```

Wire it in the entry: `def:pub app() -> JsxElement { <AppProvider><AppShell /></AppProvider> }`. (That no-argument shape is the manual/single-page entry. With file-based routing `app` instead takes `children` and must render it, so wrap `{children}` rather than a shell - see `jac-cl-routing`.) Annotate the consumer's `ctx: any` - a bare `ctx = useContext(...)` is Unknown-typed and `ctx.user` fails `jac check` with E1032. In a shell-architected app the provider is rarely needed - the shell already sees everything; reach for context only when ≥2 *distant* consumers exist.

## jac-shadcn project layout

When the project has a `ui/` folder (jac-shadcn primitives are pre-installed - `components/ui/` by default, or wherever you put it): it holds the managed primitives (`button.jac`, `card.jac`, ...) - **import only, never edit**; your composite components and shells sit with the feature that uses them, exactly as in the layout above. Load `jac-shadcn-components` for import patterns and the component selection table, `jac-shadcn-blocks` for multi-component composition patterns.

## Rules

- **Default to the shell.** Page state and handlers live in ONE stateful component per page; sections receive props + callbacks. Don't pre-extract hooks/contexts for state only one page uses.
- **One file per page/section, basename matches the main export** (`Button.jac` → `Button`). File-local `def:pub` helpers are fine - a section file exporting both `MicroservicesSection` and its small `ProcBox` building block is good practice; move a helper to `shared/` only when a second *feature* needs it.
- **In jac-shadcn projects, scan the `ui/` folder before building any UI element.** If a primitive exists (Button, Card, Input, Badge, Dialog, Table, ...), import it - do not re-implement it. Never edit files in it (registry-managed); compose with them in your own files.
- **Reuse before creating.** Scan the feature folder and `shared/` before writing a new file. Duplicate UI = default mistake.
- **Promote, don't default.** A module moves to `shared/` when a *second feature* imports it, never because it "looks like a utility".
- **Scoped styles share the basename.** `Button.style.css` beside the component file (`Button.jac`) auto-scopes, no import. See `jac-cl-styling`.
- **PascalCase** for components + files: `UserCard.jac`. `snake_case` for variables and handlers.
- **Pages are thin orchestrators of sections.** JSX > ~80 lines in a shell's return = extract blocks into section components (props down, callbacks up); handler bodies > a screenful = move to the `.impl.jac`.
- **Domain-meaningful names, not structural.** `CalculatorApp`, not `App`. `recipes_data`, not `data`. `recipes/store.jac`, not `recipes/api.jac` - the folder already says which feature, so the filename has to say what the module *is*. Generic `Layout`/`App` only for the single top-level wrapper.
- **Hook name = `use<DomainNoun>`** (`useRecipes`, NOT `useData`); hooks live under `hooks/`, return dicts consumed with `[key]`. Don't call a hook from a non-component `def` - `has` fields only wire up inside `def:pub` that renders JSX or inside another `useXxx()`.
- **Extract to a hook when** the same fetch+state *logic* recurs in ≥2 components. If ≥2 components must see the same *live values*, a hook is NOT enough - use the context pattern above.

## See also

- `jac-impl-files` - the `.impl.jac` handler annex the shell pattern relies on
- `jac-cl-components` - single-component shape, props/`Callable` typing, state, events
- `jac-fullstack-patterns` - client-to-server import rules inside shells and hooks
- `jac-shadcn-blocks` - composition patterns for auth cards, app shells, data tables, and more
