---
name: jac-cl-components
description: Writing a client-side UI component - shape, reactive state, mount effects, rendering, event handlers. Load when creating or editing any `.cl.jac` file. Pair with `jac-cl-routing` (multi-page apps), `jac-cl-organization` (file layout & hooks), `jac-cl-auth` (protected pages).
---

`.cl.jac` files are client-side Jac. A component is a `def:pub` function returning `JsxElement`. State = `has` fields, which compile 1:1 to React `useState` - assign directly (`x = x + 1` re-renders; no `setX(...)` call) but all `useState` semantics apply: writes are async, the closure stays stale until the next render. Mount effects = `async can with entry` (compiles to `useEffect`). Event handlers = `def` methods typed with ambient DOM events (`MouseEvent`, `ChangeEvent`, `FormEvent`, `KeyboardEvent`). No `to cl:` header - the extension sets client context.

```jac
def:pub Counter() -> JsxElement {
    has count: int = 0;
    has label: str = "";

    async can with entry {
        count = 0;                               # mount effect - runs once
    }

    def handle_click(e: MouseEvent) {
        count = count + 1;
    }

    def handle_input(e: ChangeEvent) {
        label = e.target.value;                  # .target.value is typed via ChangeEvent
    }

    return <section className="p-4">
        <input value={label} onChange={handle_input} />
        <h1 className="text-xl">
            {"Clicks: " + str(count) if count > 0 else "Start clicking!"}
        </h1>
        <button onClick={handle_click}>+</button>
    </section>;
}
```

## Props

Components declare props as typed function params; callers pass as JSX attributes. Callback props are typed `Any`. Wrap incoming callbacks in a local handler so parent-side data (like a row's id) is closed over when the event fires.

```jac
def:pub BookCard(bookId: str, title: str, onDelete: Any) -> JsxElement {
    def handle_delete(e: MouseEvent) {
        if onDelete { onDelete(bookId); }
    }
    return <div>{title} <button onClick={handle_delete}>X</button></div>;
}
```

Call site: `<BookCard bookId={b["id"]} title={b["title"]} onDelete={remove} />`.

## Event types (ambient, no import)

| Handler | Type | Access |
|---|---|---|
| `onClick`, `onMouseDown`, `onDoubleClick` | `MouseEvent` | `e.clientX`, `e.button` |
| `onChange` | `ChangeEvent` | `e.target.value` |
| `onInput` | `InputEvent` | `e.target.value` |
| `onKeyDown`, `onKeyUp`, `onKeyPress` | `KeyboardEvent` | `e.key`, `e.code` |
| `onSubmit`, `onReset` | `FormEvent` | `e.preventDefault()` |
| `onFocus`, `onBlur` | `FocusEvent` | `e.target` |

Fall back to `Any` (capital, built-in) only when you don't read `e`.

## Built-in in `.cl.jac` - NEVER import these

`JsxElement` (the component return type), `Any`, and all DOM event types (`MouseEvent`, `ChangeEvent`, `FormEvent`, `KeyboardEvent`, `InputEvent`, `FocusEvent`) are Jac built-ins in client context. Trying `import from "@jac/runtime" { JsxElement }` is wrong and can fail the Vite build.

## Imports from `@jac/runtime` (complete list)

- **Routing components:** `Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`
- **Routing hooks:** `useNavigate`, `useLocation`, `useParams`, `useRouter` (NO `useSearchParams`)
- **Auth:** `jacLogin`, `jacSignup`, `jacLogout`, `jacIsLoggedIn`
- **Validation / error boundary:** `JacSchema`, `JacClientErrorBoundary`
- **DO NOT use:** `useState`, `useEffect` (aliases exist but `has` + `async can with entry` are idiomatic)

## Pitfalls

The first two bullets below are **silent runtime bugs** (⚠) - no compile error, no obvious failure mode at runtime. Read them every time.

- ⚠ **Hooks + `has` BEFORE any conditional return.** React hooks must fire in the same order every render. `if not jacIsLoggedIn() { return <Navigate />; } has x: int = 0;` → white screen, no compile error.
- ⚠ **Mount effects (`async can with entry`) fire even when the component returns `<Navigate>`.** Guard the EFFECT body with `if jacIsLoggedIn() { ... }`, not just the render - otherwise `def:priv` calls fire and return 401 silently.

- **`has` fields are reactive state - assign directly.** `count = count + 1` re-renders. No `setCount`. Non-default fields come before defaulted ones (E2004 - see `jac-has-fields`).
- **Derived values are locals, not `has` fields.** Anything computable from props/params/hook results gets recomputed every render - so it's a local. Putting it in `has` forces a top-level write to keep it in sync, which can cascade to React error #301. Rule: `has` is only for event-driven or async values (user input, fetch results, server data).

```
# FRAGILE - derived flag stored as state, written from render body
has has_filter: bool = False;
if useParams()["category"] { has_filter = True; }

# CORRECT - derived flag is a plain local
has_filter: bool = bool(useParams()["category"]);
```

- **Server RPC import uses `sv import from ..services.X { fn, Types }`** (prefix required). Dot count = how many folders up from THIS file to reach `services/` - for a `components/X.cl.jac` it's 2 dots, for `components/pages/X.cl.jac` it's 3 dots (see `jac-core-cheatsheet` for dot semantics). Plain `import from` to a `.sv.jac` breaks the Vite build. Include obj/node types too - they're needed to type your `has` state (next rule). See `jac-fullstack-patterns`.
- **Type `has` state with the imported `sv` types - `list[Any]` loses the element type.** Store data from `sv import` calls in fields typed with the actual node/obj. Without it, attribute access in loops fails `E1032: Type is Unknown`.

```
sv import from ..services.linkedin { Post };   # 2 dots: this file is at components/X.cl.jac; `..` walks up to project root, then into services/

# FRAGILE
has posts: list[Any] = [];           # E1032 on p.title in any loop

# CORRECT
has posts: list[Post] = [];          # `p` in `for p in posts` is typed Post
```

- **Call server endpoints POSITIONAL, not kwargs.** `save(a, b)` works; `save(a=a, b=b)` sends empty body → 422. Also: the caller's variable names become the JSON keys - they must match the server parameter names exactly. See `jac-fullstack-patterns`.
- **JSX ternary is Python-style:** `{X if cond else Y}`. NOT `{cond ? X : Y}` (parse error even inside JSX). Short-circuit also works: `{cond and <X />}`.
- **Iterate with comprehensions, NOT `.map()`.** `items.map(...)` on a Jac list fails E1030. Use `[<li>...</li> for i in items]` inside JSX. `for i, x in enumerate(items)` parse-fails E0001 - use a single loop var, or `range(len(items))` with index access: `[<li key={str(i)}>{items[i]}</li> for i in range(len(items))]`.
- **Dict / hook access (`useParams()[k]`, `useLocation()[k]`, generic `[key]`) returns `Any` and yields JS `undefined` for missing keys.** Since `undefined !== null` in JS, both `x is None` and `x is not None` MISS undefined - `params["id"] is not None` returns True even when `:id` isn't in the route, and `str(undefined)` produces the literal string `"undefined"`. **Use a truthy check (`if x` / `if not x`) for hook/dict values - it catches both `None` and `undefined`.** The narrowing-friendly `is not None` form is still correct for typed Optionals (`T | None` from `sv import`-ed functions, function params, etc.) where `undefined` can't appear. (Also: `params.get("id")` runtime-fails in the browser since `useParams` returns a plain JS object - always use `[key]`.)
- **`T | None` narrowing doesn't reach inside JSX list comprehensions / short-circuits.** After `if x is None { return ...; }`, direct `x.attr` works in the function body - but `{[<li>{x.attr}</li> for i in range(len(x.attr))]}` inside JSX fails E1099 because the comprehension is its own scope. **Workaround:** pull each used attribute into a typed local *before* the JSX block (e.g. `title: str = x.title; parts: list[str] = x.parts;`), then reference the locals from JSX. See `jac-types` for the full BROKEN/CORRECT pair.
- **Guard None/null/undefined when iterating or dotting into server data.** Runtime-only failure (`Cannot read properties of null/undefined`), nothing at compile. Four hot spots - single-level access is the most common:

```
# FRAGILE - crashes if the value is None/null
total = result.total_posts;                            # result is None → crash (SINGLE-LEVEL)
status = result.recipe.status;                         # result.recipe is None → crash (NESTED)
rows = [<Card title={s["title"]} /> for s in songs];  # any s is None in list → crash
first = songs[0]["title"];                             # empty list → crash

# SAFE - narrow, filter, or length-check first
if result is not None { total = result.total_posts; }
if result.recipe is not None { status = result.recipe.status; }
rows = [<Card ... /> for s in songs if s is not None];
if len(songs) > 0 { first = songs[0]["title"]; }
```

Also works: short-circuit in JSX - `{result and <X total={result.total_posts} />}`.

**For server response objects (dicts/lists from `sv import` calls), prefer truthy checks (`if result {`) over `!= None`.** The `!=` operator uses deep equality which calls `Object.keys()` - crashes with `"Cannot convert undefined or null to object"` if the value is `null`/`undefined`. `!= None` is safe for primitives (strings, ints, bools) but not for complex objects returned from server calls.

- **Event params are typed - `MouseEvent`/`ChangeEvent`/etc.** `e: any` (lowercase) is the Python `any()` builtin, fails E1103. Use capital `Any` (no import) for untyped.
- **`style` prop takes a `dict[str, object]`, not a CSS string.** `<div style="color: red">` fails E1103. Use inline dict `<div style={{"color": "red"}}>` or move styling to `className` + a CSS file.
- **JSX uses `className`, curly-brace interpolation `{expr}`, camelCase events** (`onClick`, `onChange`).
- **No `to cl:` / `cl def:pub` / `cl { }` in `.cl.jac` files.** Extension already sets context. Braced blocks are deprecated (W0064).
- **Top-level component name is `def:pub app()`** - lowercase. Runtime mounts the literal name.

## See also

- `jac-cl-routing` - `Router`/`Route`/`Navigate`/`useNavigate` patterns
- `jac-cl-auth` - `jacLogin`/`jacSignup`/`jacLogout`, signup→login→def:priv chain
- `jac-cl-organization` - file layout, component reuse, hook pattern
- `jac-core-cheatsheet` - imports, lambda, ternary, error handling
