---
name: jac-cl-components
description: Writing a client-side UI component - shape, reactive state, mount effects, props and Callable callbacks, JSX rendering, event handlers. Load when creating or editing any `.cl.jac` file. Pair with `jac-cl-routing` (multi-page apps), `jac-cl-organization` (architecture & file layout), `jac-cl-auth` (protected pages).
---

`.cl.jac` files are client-side Jac. A component is a `def:pub` function returning `JsxElement`. State = `has` fields, which compile 1:1 to React `useState` - assign directly (`x = x + 1` re-renders; no `setX(...)` call) but all `useState` semantics apply: writes are async, the closure stays stale until the next render. Mount effects = `async can with entry` (compiles to `useEffect`). Event handlers = `def` methods typed with ambient DOM events (`MouseEvent`, `ChangeEvent`, `FormEvent`, `KeyboardEvent`). No `to cl:` header - the extension sets client context.

## This is Jac, not React or JavaScript

A `.cl.jac` component *compiles to* React, but you **write Jac** - Python-with-braces, not JSX/JS. This is the single most common mistake: do not reach for React/JS syntax. Translate every React habit to its Jac form:

| React / JavaScript (WRONG in a `.jac` file) | Jac (correct) |
|---|---|
| `function App() { ... }` / `const App = () => ...` | `def:pub app() -> JsxElement { ... }` |
| `class X extends Component { render() {...} }` | `def:pub X() -> JsxElement { ... }` (no classes, no `render`, no `constructor`) |
| `const [n, setN] = useState(0)` ; `setN(n+1)` | `has n: int = 0;` then `n = n + 1;` (direct assign re-renders) |
| `useEffect(() => {...}, [])` | `async can with entry { ... }` |
| `onClick={() => doThing()}` | `onClick={handle}` with `def handle(e: MouseEvent) { doThing(); }` |
| `this.props.x` / `props.x` | `x` - props are plain function parameters |
| `import React from 'react'` | nothing - `JsxElement` and DOM events are built-in (never import them) |
| `const`, `let`, `var x = 1` | `x: int = 1;` (typed assignment) |
| `=== / !==` ; `null` / `undefined` ; `cond ? a : b` | `== / !=` ; `None` ; `a if cond else b` |
| `items.map(x => <li>{x}</li>)` | `{for x in items { <li>{x}</li> }}` (statement slot) |
| writing a NEW `.js` / `.jsx` / `.tsx` file | a `.cl.jac` file. (Pre-existing `.tsx` components CAN be imported - `import from "./components/Button" { Button }` - but never author new ones.) |

If you find yourself writing `function`, `=>`, `this.`, `export`, `import React`, or a `.js` file, stop - that is JavaScript. Write the Jac form from the table above.

```jac
def:pub Counter() -> JsxElement {
    has count: int = 0;
    has label: str = "";

    async can with entry {
        count = 0;                               # mount effect - runs once
    }

    def handle_click(e: MouseEvent) { count = count + 1; }
    def handle_input(e: ChangeEvent) { label = e.target.value; }   # typed via ChangeEvent

    return <section className="p-4">
        <input value={label} onChange={handle_input} />
        <h1>{"Clicks: " + str(count) if count > 0 else "Start clicking!"}</h1>
        <button onClick={handle_click}>+</button>
    </section>;
}
```

## Props

Components declare props as typed function params; callers pass as JSX attributes. Type callback props with `Callable[[ArgTypes], ReturnType]` - `Callable[[str], None]` for a one-string callback, `Callable[[], None]` for a no-arg one. `Callable` is ambient (no import), and the typing catches a mistyped call (wrong arity, wrong arg type, bogus `.member`) at compile time. (The parenthesized spelling `Callable[([str], None)]` also parses; prefer the Python form.) The escape-hatch `any` disables that checking and earns a `W1037` warning; keep it for genuine interop boundaries only. Wrap incoming callbacks in a local handler so parent-side data (like a row's id) is closed over when the event fires.

```jac
def:pub BookCard(bookId: str, title: str, onDelete: Callable[[str], None]) -> JsxElement {
    def handle_delete(e: MouseEvent) {
        onDelete(bookId);
    }
    return <div>{title} <button onClick={handle_delete}>X</button></div>;
}
```

Call site: `<BookCard bookId={b["id"]} title={b["title"]} onDelete={remove} />`. For an optional callback, type it `Callable[[str], None] | None` and guard the call: `if onDelete { onDelete(bookId); }`.

**`children` needs a default.** A component that accepts nested JSX declares `children: any = None`. Nested content does NOT count as a passed attribute, so a `children` param **without a default is a required prop** - every call site that passes any other attribute fails `E1102: Component 'Card' requires prop 'children'`. (`any` is the honest type: children can be an element, string, number, or list.)

```jac
def:pub Card(title: str, children: any = None) -> JsxElement {
    return <div className="card"><h2>{title}</h2>{children}</div>;
}
```

**Props bundle (`props: dict`):** a single parameter literally named `props` receives the whole call-site object un-destructured - for HOCs/wrappers that just `<Inner {**props} />`. The cost: per-attribute call-site validation is impossible, so the compiler emits **W5015** on the definition; suppress with `# jac:ignore[W5015]` only when forwarding is intentional. Default to named params.

**`children` parameter:** always declare it `children: any = None` with `= None` default. Omitting the default makes `children` a required prop - every call site that passes no nested content fails with `error[E1102]`. Use `{children}` in the JSX body to render it.

**`props: Any` bundle:** `def:pub Comp(props: Any)` is allowed but emits `W5015` and disables per-prop type checking. Prefer named typed parameters.

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

- **Routing components:** `Router`, `Routes`, `Route`, `Link`, `Navigate`, `Outlet`, `AuthGuard`
- **Routing hooks/fns:** `useNavigate`, `useLocation`, `useParams`, `useRouter`, `navigate` (NO `useSearchParams` - parse `useLocation().search`)
- **Auth:** `jacLogin`, `jacSignup`, `jacLogout`, `jacIsLoggedIn`, `jacSsoLogin`, `jacSetToken`
- **Forms / validation:** `useJacForm`, `JacForm`, `JacSchema`
- **Error / suspense:** `JacClientErrorBoundary`, `JacAwaiting`, `ErrorFallback`
- **Walker calls:** `jacSpawn` (prefer the `root spawn walker(...)` syntax - see `jac-fullstack-patterns`)
- **DO NOT use:** `useState`, `useEffect` (aliases exist but `has` + `can with entry` are idiomatic)

## Effects: dependency arrays, cleanup, and the entry/exit closure split

| Jac | React |
|---|---|
| `can with entry { ... }` | `useEffect(fn, [])` - once on mount |
| `async can with entry { ... }` | same, body wrapped in an async IIFE |
| `can with [dep] entry { ... }` | `useEffect(fn, [dep])` - re-runs when `dep` changes |
| `can with (a, b) entry { ... }` | `useEffect(fn, [a, b])` |
| `can with exit { ... }` | `useEffect(() => () => { ... }, [])` - cleanup on unmount |

Multiple `can with entry` blocks in one component are fine and good for separating concerns - each compiles to its own `useEffect`, and dep-array effects (`can with [darkMode] entry`) sit alongside the mount effects.

⚠ **`entry` and `exit` compile to SEPARATE `useEffect` closures.** A handle created in `can with entry` (interval id, WebSocket, listener) is **invisible** in `can with exit` - the cleanup silently no-ops. For acquire-then-release pairs, use a single manual `useEffect` whose body returns the cleanup - and the outer lambda must NOT be annotated `-> None` (it returns a function):

```jac
import from react { useEffect }

def fetch_data();

cl def:pub Poller() -> JsxElement {
    useEffect(lambda {
        interval = setInterval(lambda { fetch_data(); }, 5000);
        return lambda { clearInterval(interval); };
    }, []);
    return <p>polling</p>;
}
```

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

**Statement slot when:** control flow, multi-element rows, empty-state guards, `enumerate` destructuring. **Expression slot / comprehension when:** a single value or one-line `[<li>...</li> for i in items]`.

Caveats specific to slot bodies:

- `skip;` inside a slot is the slot early-exit - it ends the current slot's accumulator (rest of *this* slot stops), **not** the enclosing function. Useful for "show empty state, stop here." Bare `return;` inside a slot is rejected (E2020) because it reads like a function-exit but only exits the slot; the value form `return expr;` is also rejected (E2019).
- Inside a slot body, don't wrap inner control flow with another `{...}` - the body is already in slot mode. Write `if cond { <X/> }` directly, not `{if cond { <X/> }}` (E2023). The `{...}` wrapping is only needed when descending from a JSX element's children into slot mode.
- Slot iteration that yields keyless JSX siblings earns a warning - `W2019` for a `while` loop, `W2021` for a `for` loop - add `key={...}` on the inner element so siblings keep their identity across re-renders.
- A `has`-field inside a slot body is rejected (E2024). The slot body is a statement template that re-runs every render, so a `has` there would compile to a conditional `useState` and break React's rules of hooks. Declare reactive state at the component scope (the enclosing `def -> JsxElement` body), never inside a `{...}` slot.
- `try { ... } awaiting { ... }` in a slot lowers to a `<JacAwaiting>` Suspense wrapper (cl only; the `awaiting` body is the fallback). On `sv`/`na` the `awaiting` body is dropped with `W2020`; `finally` with `awaiting` is rejected (`E2022`). An added `except Exception { ... }` arm synthesizes a `<JacClientErrorBoundary fallback={...}>` around it - the JS boundary catches ALL error types, so per-type dispatch and `as <name>` bindings aren't modeled.
- **Dynamic tags:** `<@as_ className="box">{children}</@as_>` picks the element tag from an expression (`as_: str` prop, dotted access, or `<@{expr}>`). Use the param name `as_` - `as` is reserved.

## Pitfalls

The first four bullets below are **silent runtime bugs** (⚠) - no compile error, no obvious failure mode at runtime. Read them every time.

- ⚠ **In-place mutation does NOT re-render - rebind instead.** `has` state compiles to `useState`; React only re-renders on a *new* value assignment. `todos.append(x)`, `todos[0] = y`, `d["k"] = v`, `.sort()` all mutate the existing object - the UI silently never updates. This is the #1 Python-habit bug. Rebind a fresh value: `todos = todos + [x];`, `todos = [t for t in todos if jid(t) != tid];`, `d = {**d, "k": v};`.
- ⚠ **Hooks + `has` BEFORE any conditional return.** React hooks must fire in the same order every render. `if not jacIsLoggedIn() { return <Navigate />; } has x: int = 0;` → white screen, no compile error.
- ⚠ **Mount effects (`async can with entry`) fire even when the component returns `<Navigate>`.** Guard the EFFECT body with `if jacIsLoggedIn() { ... }`, not just the render - otherwise `def:priv` calls fire and return 401 silently.
- ⚠ **Long-running async code reads a STALE snapshot of `has` state.** After an `await`, reading a reactive field back gives the render-time value, not the latest write - so `story = story + frame;` inside a streaming/polling loop re-appends to the same old string every iteration. Accumulate into a LOCAL and assign the whole value each step:

```
# FRAGILE - each read of reactive `story` inside the loop sees the render-time snapshot
while feeding {
    frame = await next_frame();
    story = story + frame;      # appends to the SAME stale value every time
}

# CORRECT - local accumulator; assign the full value each iteration (each write re-renders)
acc = "";
while feeding {
    frame = await next_frame();
    acc = acc + frame;
    story = acc;
}
```

- **`has` fields are reactive state - assign directly.** `count = count + 1` re-renders. No `setCount`. Non-default fields come before defaulted ones (E2004 - see `jac-has-fields`).
- **Derived values are locals, not `has` fields.** Anything computable from props/params/hook results gets recomputed every render - so it's a local. Putting it in `has` forces a top-level write to keep it in sync, which can cascade to React error #301. Rule: `has` is only for event-driven or async values (user input, fetch results, server data).

```
has has_filter: bool = False;                        # FRAGILE - derived flag as state
if useParams()["category"] { has_filter = True; }    #   written from render body
has_filter: bool = bool(useParams()["category"]);    # CORRECT - plain local
```

- **Server RPC import uses `sv import from ..services.X { fn, Types }`** (prefix required). Dot count = how many folders up from THIS file to reach `services/` - for a `components/X.cl.jac` it's 2 dots, for `components/pages/X.cl.jac` it's 3 dots (see `jac-core-cheatsheet` for dot semantics). Plain `import from` to a `.sv.jac` breaks the Vite build. Include obj/node types too - they're needed to type your `has` state (next rule). See `jac-fullstack-patterns`.
- **Always `await` `sv import` calls.** Stubs are `async` functions -- `todos = list_todos()` assigns a `Promise`, not the data → `TypeError: todos is not iterable` at runtime. Two valid async contexts:

```
# 1. fetch on mount
async can with entry {
    todos = await list_todos();
}

# 2. handler that calls sv import -- use `async def` (no event param; uses `has` field closures)
async def handle_add -> None {
    todo = await create_todo(input_text);   # input_text is a `has` field
    todos = [todo] + todos;
}
# bind as: onClick={handle_add}
# if you need to pass a param: onClick={lambda -> None { handle_toggle(item.id); }}
```

Plain `def handle(e: MouseEvent)` is sync -- `await` inside it emits invalid JS.

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
- **Iterate with statement slots, NOT `.map()`.** `items.map(...)` on a Jac list fails E1030 - use `{for x in xs { <li>...</li> }}` (see "Statement slots" above; `enumerate` destructuring needs parens: `for (i, x) in enumerate(items)`). Inline `[<li>...</li> for i in items]` still works for one-liners.
- **Dict / hook access (`useParams()[k]`, `useLocation()[k]`, generic `[key]`) returns `any` and yields JS `undefined` for missing keys.** Since `undefined !== null` in JS, both `x is None` and `x is not None` MISS undefined - `params["id"] is not None` returns True even when `:id` isn't in the route, and `str(undefined)` produces the literal string `"undefined"`. **Use a truthy check (`if x` / `if not x`) for hook/dict values - it catches both `None` and `undefined`.** The narrowing-friendly `is not None` form is still correct for typed Optionals (`T | None` from `sv import`-ed functions, function params, etc.) where `undefined` can't appear. (Also: `params.get("id")` runtime-fails in the browser since `useParams` returns a plain JS object - always use `[key]`.)
- **`unsafe_html(x)` opts out of escaping for raw HTML.** Ambient builtin (no import). `{unsafe_html(c.html_blob)}` renders the string as raw HTML via `dangerouslySetInnerHTML` (React) or `innerHTML` (bare-serve). Use ONLY with trusted content - the `unsafe_` prefix is the security-review marker at the call site; never wrap user input or anything that crossed an unsanitized boundary.
- **Guard None/null/undefined when iterating or dotting into server data.** Runtime-only failure (`Cannot read properties of null/undefined`), nothing at compile. Single-level access is the most common crash (`total = result.total_posts;` when `result` is None), then nested access, then `songs[0]["title"]` on an empty list. Narrow (`if result is not None { ... }`), filter (`[<Card .../> for s in songs if s is not None]`), or length-check (`if len(songs) > 0`) first; short-circuit in JSX also works - `{result and <X total={result.total_posts} />}`. For dicts/lists from `sv` calls, prefer truthy checks (`if result {`) over `!= None` - `!=` is deep equality (calls `Object.keys()`) and itself crashes on `null`/`undefined`; `!= None` is safe only for primitives.
- **Event params are typed - `MouseEvent`/`ChangeEvent`/etc.** Annotate every handler that reads `e` with the real event type, so `e.target` / `e.key` resolve. When you genuinely don't read `e`, use the base `Event` type - not `any`, which earns a `W1037` warning (and capital `Any` is not the keyword, warning `W2001` "Name 'Any' may be undefined").
- **Inline anonymous functions in JSX use `lambda`, NOT `def`.** `onClick={lambda (e: MouseEvent) { count = count + 1; }}` works; anonymous `def (...)` is a parse error regardless of return type - `def` requires a name. Prefer named `def` methods; inline `lambda` only for trivial one-liners.

- **`style` prop takes a `dict[str, object]`, not a CSS string.** `<div style="color: red">` fails E1103. Use inline dict `<div style={{"color": "red"}}>`, or move styling to `className` + a same-basename `.style.css` annex (auto-scoped -- see `jac-cl-styling`).
- **JSX uses `className`, curly-brace interpolation `{expr}`, camelCase events** (`onClick`, `onChange`).
- **No `to cl:` / `cl def:pub` / `cl { }` wrapper in `.cl.jac` files.** The extension already sets the client context.
- **Top-level component name is `def:pub app()`** - lowercase. Runtime mounts the literal name.
- **JSX comments use `{#* ... *#}`.** This is only valid **inside JSX element children** (between any opening and closing tag) - anywhere outside JSX is a parse error (E0001). The JS-style `{/* ... */}` is also a parse error in Jac JSX. `{}` (empty slot) is also a parse error - use `{#* note *#}` for a no-op placeholder. A `#` outside an expression slot is treated as **literal HTML text**, not a comment.
- **Module `glob`s can hold rich data - including JSX.** `glob _BUILDS: list[dict] = [{"name": "CLI", "icon": <Terminal size={15}/>}];` is a fine home for render-constant tables; iterate them in slots or comprehensions. `glob` is NOT reactive - anything that changes belongs in `has`.
- **`jac format` can drop significant JSX whitespace** when reflowing mixed text + inline elements. Keep spacing that matters as explicit string children - `{" "}` between an element and text, `{" · "}` separators - those survive reformatting.

## See also

- `jac-cl-routing` - `Router`/`Route`/`Navigate`/`useNavigate` patterns
- `jac-cl-auth` - `jacLogin`/`jacSignup`/`jacLogout`, signup→login→def:priv chain
- `jac-cl-organization` - file layout, component reuse, hook pattern
- `jac-cl-styling` - Tailwind/`cn()`, semantic tokens, scoped `.style.css` annexes
- `jac-cl-js-interop` - `new()` for browser objects, WebSocket, localStorage, polling
- `jac-npm-packages` - `Ref[T]` fields, ref forwarding, npm imports
- `jac-core-cheatsheet` - imports, lambda, ternary, error handling
