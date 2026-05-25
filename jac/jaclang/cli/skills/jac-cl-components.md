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

Components declare props as typed function params; callers pass as JSX attributes. Type callback props with `Callable[([ArgTypes], ReturnType)]` - `Callable` is ambient, so no import - which catches a mistyped call (wrong arity, wrong arg type, bogus `.member`) at compile time. The escape-hatch `any` disables that checking and earns a `W1037` warning; keep it for genuine interop boundaries only. Wrap incoming callbacks in a local handler so parent-side data (like a row's id) is closed over when the event fires.

```jac
def:pub BookCard(bookId: str, title: str, onDelete: Callable[([str], None)]) -> JsxElement {
    def handle_delete(e: MouseEvent) {
        onDelete(bookId);
    }
    return <div>{title} <button onClick={handle_delete}>X</button></div>;
}
```

Call site: `<BookCard bookId={b["id"]} title={b["title"]} onDelete={remove} />`. For an optional callback, type it `Callable[([str], None)] | None` and guard the call: `if onDelete { onDelete(bookId); }`.

**`{name}` shorthand:** when an attribute's value is a bare variable of the same name, `<BookCard {title} {onDelete} />` expands to `title={title} onDelete={onDelete}`. Pure sugar - the type-checker validates it per-attribute exactly like the explicit form. Distinct from the spread, which forwards a whole object: use `{**props}` (the canonical Jac form) - the JS-idiomatic `{...props}` also works but earns a `W0063` warning ("prefer `{**expr}`").

## Event types (ambient, no import)

| Handler | Type | Access |
|---|---|---|
| `onClick`, `onMouseDown`, `onDoubleClick` | `MouseEvent` | `e.clientX`, `e.button` |
| `onChange` | `ChangeEvent` | `e.target.value` |
| `onInput` | `InputEvent` | `e.target.value` |
| `onKeyDown`, `onKeyUp`, `onKeyPress` | `KeyboardEvent` | `e.key`, `e.code` |
| `onSubmit`, `onReset` | `FormEvent` | `e.preventDefault()` |
| `onFocus`, `onBlur` | `FocusEvent` | `e.target` |

Use the matching type even when you don't read `e`; for an event not in the table, fall back to the base `Event` type.

## Built-in in `.cl.jac` - NEVER import these

`JsxElement` (the component return type) and all DOM event types (`MouseEvent`, `ChangeEvent`, `FormEvent`, `KeyboardEvent`, `InputEvent`, `FocusEvent`, base `Event`) are Jac built-ins in client context; `Callable` is ambient as well. None need an import - `import from "@jac/runtime" { JsxElement }` or `import from typing { Callable }` is wrong and can fail the Vite build.

## Imports from `@jac/runtime` (complete list)

- **Routing components:** `Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`
- **Routing hooks:** `useNavigate`, `useLocation`, `useParams`, `useRouter` (NO `useSearchParams`)
- **Auth:** `jacLogin`, `jacSignup`, `jacLogout`, `jacIsLoggedIn`
- **Validation / error boundary:** `JacSchema`, `JacClientErrorBoundary`
- **DO NOT use:** `useState`, `useEffect` (aliases exist but `has` + `async can with entry` are idiomatic)

## Statement slots: control flow inside JSX

Every `{...}` in JSX child position is a **slot**. The compiler picks the shape from the body's first token:

- **Expression slot** - `{name}`, `{user.email}`, `{<Badge />}`, `{"hi" if cond else "bye"}` - renders one value.
- **Statement slot** - body starts with `for` / `if` / `while` / `match` / `switch` / `with` / `try` - each JSX statement inside pushes a child into the enclosing element. This is the primary tool for dynamic children: iteration, conditional rendering, empty-state guards, and any combination of them.

```jac
def:pub ItemList(items: list[Item]) -> JsxElement {
    return <ul class="items">
        {if len(items) == 0 {
            <p class="empty">Nothing yet.</p>
            skip;                          # skip; ends the slot early
        }}
        <h2>Items</h2>
        {for (i, it) in enumerate(items) {
            <li key={str(i)} class={"done" if it.done else "todo"}>{it.label}</li>
        }}
    </ul>;
}
```

**Use a statement slot when** the body has control flow, the row has multiple JSX elements, you need an empty-state guard, you want `enumerate` with destructuring, or you'd otherwise reach for a nested ternary / `cond and <X />` chain. **Use an expression slot / list comprehension when** it's a single value or a one-line `[<li>...</li> for i in items]`.

Caveats specific to slot bodies:

- `skip;` inside a slot is the slot early-exit - it ends the current slot's accumulator (rest of *this* slot stops), **not** the enclosing function. Useful for "show empty state, stop here." Bare `return;` inside a slot is rejected (E2020) because it reads like a function-exit but only exits the slot; the value form `return expr;` is also rejected (E2019).
- Inside a slot body, don't wrap inner control flow with another `{...}` - the body is already in slot mode. Write `if cond { <X/> }` directly, not `{if cond { <X/> }}` (E2023). The `{...}` wrapping is only needed when descending from a JSX element's children into slot mode.
- Slot iteration that yields keyless JSX siblings earns a warning - `W2019` for a `while` loop, `W2021` for a `for` loop - add `key={...}` on the inner element so siblings keep their identity across re-renders.
- A `has`-field inside a slot body is rejected (E2024). The slot body is a statement template that re-runs every render, so a `has` there would compile to a conditional `useState` and break React's rules of hooks. Declare reactive state at the component scope (the enclosing `def -> JsxElement` body), never inside a `{...}` slot.
- `try { ... } awaiting { ... }` in a slot lowers to a `<JacAwaiting fallback={...}>{...}</JacAwaiting>` Suspense wrapper (cl only). The `awaiting` body shows during the dispatched-but-not-joined window of any Suspense-aware primitive inside the `try` body; today Jac's `flow`/`wait` don't suspend, so the fallback only fires when the `try` body opts into something Suspense-shaped (e.g. a fetcher that throws a promise). On `sv` / `na` the `awaiting` body is dropped with `W2020`. `finally` with `awaiting` is rejected (`E2022`).
- Add an `except` arm (`try { ... } awaiting { ... } except Exception { ... }`) to name the error state. On cl this synthesizes a `<JacClientErrorBoundary fallback={...}>` (auto-imported from `@jac/runtime`) that **wraps** the `<JacAwaiting>`, so a throw in the resolved `try` body renders the `except` body. The JS boundary catches all errors regardless of type, so per-type dispatch and `except ... as <name>` bindings aren't modeled; multiple except bodies concatenate in source order into the one fallback.

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
- **Type `has` state with the imported `sv` types - `list[any]` loses the element type.** Store data from `sv import` calls in fields typed with the actual node/obj. Without it, attribute access in loops fails `E1032: Type is Unknown`.

```
sv import from ..services.linkedin { Post };   # 2 dots: this file is at components/X.cl.jac; `..` walks up to project root, then into services/

# FRAGILE
has posts: list[any] = [];           # E1032 on p.title in any loop

# CORRECT
has posts: list[Post] = [];          # `p` in `for p in posts` is typed Post
```

- **Call server endpoints POSITIONAL, not kwargs.** `save(a, b)` works; `save(a=a, b=b)` sends empty body → 422. Also: the caller's variable names become the JSON keys - they must match the server parameter names exactly. See `jac-fullstack-patterns`.
- **JSX ternary is Python-style:** `{X if cond else Y}`. NOT `{cond ? X : Y}` (parse error even inside JSX). Short-circuit also works: `{cond and <X />}`.
- **Iterate with statement slots (`{for x in xs { <li>...</li> }}`), NOT `.map()`.** `items.map(...)` on a Jac list fails E1030. A `{...}` slot whose body starts with `for`/`if`/`while`/`match`/`switch`/`with`/`try`/`skip` is a **statement slot**: each JSX statement inside pushes a child into the parent. It handles `enumerate` cleanly (`for (i, x) in enumerate(items)` - parens required; bare `i, x` parse-fails E0001), composes multi-element rows naturally, and supports an empty-state guard via `skip;` (see "Statement slots" below). Inline `[<li>...</li> for i in items]` still works for one-line element-per-item lists.
- **Dict / hook access (`useParams()[k]`, `useLocation()[k]`, generic `[key]`) returns `any` and yields JS `undefined` for missing keys.** Since `undefined !== null` in JS, both `x is None` and `x is not None` MISS undefined - `params["id"] is not None` returns True even when `:id` isn't in the route, and `str(undefined)` produces the literal string `"undefined"`. **Use a truthy check (`if x` / `if not x`) for hook/dict values - it catches both `None` and `undefined`.** The narrowing-friendly `is not None` form is still correct for typed Optionals (`T | None` from `sv import`-ed functions, function params, etc.) where `undefined` can't appear. (Also: `params.get("id")` runtime-fails in the browser since `useParams` returns a plain JS object - always use `[key]`.)
- **`unsafe_html(x)` opts out of escaping for raw HTML.** Ambient builtin (no import). `{unsafe_html(c.html_blob)}` renders the string as raw HTML via `dangerouslySetInnerHTML` (React) or `innerHTML` (bare-serve). Use ONLY with trusted content - the `unsafe_` prefix is the security-review marker at the call site; never wrap user input or anything that crossed an unsanitized boundary.
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

- **Event params are typed - `MouseEvent`/`ChangeEvent`/etc.** Annotate every handler that reads `e` with the real event type, so `e.target` / `e.key` resolve. When you genuinely don't read `e`, use the base `Event` type - not `any`, which earns a `W1037` warning (and capital `Any` is not the keyword, warning `W2001` "Name 'Any' may be undefined").
- **`style` prop takes a `dict[str, object]`, not a CSS string.** `<div style="color: red">` fails E1103. Use inline dict `<div style={{"color": "red"}}>`, or move styling to `className` + a same-basename `.style.css` annex (auto-scoped -- see `jac-cl-styling`).
- **JSX uses `className`, curly-brace interpolation `{expr}`, camelCase events** (`onClick`, `onChange`).
- **No `to cl:` / `cl def:pub` / `cl { }` wrapper in `.cl.jac` files.** The extension already sets the client context.
- **Top-level component name is `def:pub app()`** - lowercase. Runtime mounts the literal name.

## See also

- `jac-cl-routing` - `Router`/`Route`/`Navigate`/`useNavigate` patterns
- `jac-cl-auth` - `jacLogin`/`jacSignup`/`jacLogout`, signup→login→def:priv chain
- `jac-cl-organization` - file layout, component reuse, hook pattern
- `jac-cl-styling` - Tailwind/`cn()`, semantic tokens, scoped `.style.css` annexes
- `jac-core-cheatsheet` - imports, lambda, ternary, error handling
