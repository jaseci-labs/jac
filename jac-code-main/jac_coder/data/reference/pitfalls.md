# Runtime Gotchas — Passes Compilation, Crashes at Runtime

## JS Constructors Need Reflect.construct

In .cl.jac, `ClassName()` without `new` returns wrong type or throws. Jac has no `new` keyword.

```jac
# WRONG — Date() returns string, not Date object
year = Date().getFullYear();          # CRASH

# RIGHT
year = Reflect.construct(Date, []).getFullYear();
ws = Reflect.construct(WebSocket, ["ws://localhost"]);
```

**Safe statics (no Reflect needed):** `Date.now()`, `JSON.parse()`, `JSON.stringify()`, `Math.random()`, `Math.floor()`

**Always need Reflect.construct:** Date, WebSocket, TextDecoder, TextEncoder, URL, URLSearchParams, FormData, AbortController, RegExp, Error, Worker, Headers, Request, Response, Uint8Array, ArrayBuffer, Blob, File, FileReader, MutationObserver, ResizeObserver, IntersectionObserver

## Browser Global Name Conflicts

Do NOT define functions with names that shadow browser globals:

```jac
# WRONG — shadows window.open
def open(url: str) -> None { ... }

# RIGHT
def handleOpen(url: str) -> None { ... }
```

**Avoid as function names:** open, close, print, focus, blur, scroll, fetch, stop, find, alert, confirm, prompt

## Callback-in-Lambda Bug

Jac compiles `callback(arg)` inside a lambda as `new callback(arg)`. Crashes silently.

```jac
# WRONG — lambda compiles to new onMessage(msg), crashes
ws.onmessage = lambda(e: any) -> None { onMessage(e.data); };

# RIGHT — named handler with .call()
msgHandler = onMessage;
def handle_ws_message(e: any) -> None {
    msgHandler.call(None, e.data);
}
ws.onmessage = handle_ws_message;
```

## Undefined Property Access Crashes

The #1 runtime crash in .cl.jac. Happens when accessing property on `undefined`.

```jac
# WRONG — crashes if parent doesn't pass "items" prop
items = props.items;              # undefined!
return <div>{[... for item in items]}</div>;  # CRASH

# RIGHT — always default props
items = props.items or [];
title = props.title or "";

# WRONG — chaining on undefined
data = result.reports[0].items;   # CRASH if reports empty

# RIGHT — guard each level
if result and result.reports and len(result.reports) > 0 {
    data = result.reports[0].items or [];
}
```

## Dynamic Dict Values as JSX Children Render Blank

Accessing dict/object properties dynamically and using them as JSX text children renders blank. This includes loop variables from list comprehension over dicts.

```jac
# WRONG — k["label"] renders blank inside the element
keys = [{"label": "7", "onClick": h7}, {"label": "8", "onClick": h8}];
{[<Button key={k["label"]} onClick={k["onClick"]}>{k["label"]}</Button> for k in keys]}

# WRONG — same problem with dot access
{[<Button>{k.label}</Button> for k in keys]}

# RIGHT — use explicit literal JSX for each element
<Button onClick={h7}><span>7</span></Button>
<Button onClick={h8}><span>8</span></Button>

# RIGHT — if you must loop, pass data as a prop to a child component
{[<KeyButton key={k["label"]} label={k["label"]} onClick={k["onClick"]} /> for k in keys]}
# Where KeyButton renders: <button onClick={props.onClick}><span>{str(props.label)}</span></button>
```

**Rule:** When rendering a list of elements with text content, either:
1. Write each element explicitly with literal text (best for small fixed sets like calculator keys)
2. Create a child component that receives data as props and renders the text via `str()`

## Number and Boolean Display in JSX

Jac doesn't auto-convert to strings in JSX.

```jac
# WRONG — may render nothing
<span>{count}</span>

# RIGHT
<span>{str(count)}</span>
<p>{str(item["price"])}</p>
```

## sv import kwargs Are Broken

In .cl.jac, kwargs compile to a single dict argument. Server gets wrong data.

```jac
# WRONG — server receives {"a": {"a":2, "b":4, "op":"add"}}
resp = await calc(a=2, b=4, op="add");

# RIGHT — positional, order matches def:pub signature
resp = await calc(2, 4, "add");
```

## No Type Annotations in For Loops

Jac does NOT support type annotations on for-loop variables. The filter `[?:Type]` already handles typing.

```jac
# WRONG — type annotation in for loop causes syntax error
for p: Product in [root()-->][?:Product] {
    ...
}

# RIGHT — no annotation, the [?:Product] filter ensures type
for p in [root()-->][?:Product] {
    ...
}
```

## State List Mutation Doesn't Re-render

`.append()` mutates in place — React won't detect the change.

```jac
# WRONG — no re-render
items.append(newItem);

# RIGHT — new reference triggers re-render
items = items + [newItem];
```

## Comments Inside JSX Break Rendering

```jac
# WRONG — all of these crash
return <div>
    {# comment}
    <!-- comment -->
    {/* comment */}
</div>;

# RIGHT — comments above JSX only
# Render the list
return <div>...</div>;
```

## .impl.jac Parse Error Breaks Entire File

A single syntax error in an `.impl.jac` file causes ALL implementations in that file to have 0 body items. The compiler won't report which implementation failed — they all silently become empty. Always double-check syntax in impl files.

## @-scoped npm Imports Use / Not Dots

Jac uses dots for local file imports, but npm-scoped packages starting with `@` MUST keep the `/` separator with quotes.

```jac
# WRONG — dots break npm resolution
import from @jac.runtime { Link }
import from @mantine.core { Button }

# RIGHT — quoted path with / separator
# In .cl.jac files (no cl prefix needed):
import from "@jac/runtime" { Link }
import from "@mantine/core" { Button }

# In .jac files (need cl prefix for client context):
cl import from "@jac/runtime" { Link }
```

**Rule:** Any import path starting with `@` is an npm package — use quotes and `/` separators. Dots are ONLY for local Jac file paths (e.g. `import from ..components.Header`).

## Missing :pub on Exports

- Components in `.cl.jac` need `def:pub` to be importable
- Walkers need `walker :pub` for REST API
- `app()` in main.jac MUST be `def:pub`
- Hooks need `def:pub` to be importable

```jac
# WRONG — not importable
def Header() -> JsxElement { ... }

# RIGHT
def:pub Header() -> JsxElement { ... }
```
