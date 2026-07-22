---
name: jac-cl-js-interop
description: JavaScript interop in client Jac - the `new()` builtin for browser constructors (WebSocket, URL, Date, CustomEvent), `.call(None, ...)` for callbacks, `glob` module state, browser globals (localStorage, window, document), polling/debounce/RAF recipes, jac2js gotchas (chr(10) newlines, let-scoping/TDZ), and debugging compiled output. Load when client code needs a browser API that isn't a React pattern.
---

Client Jac compiles to JavaScript, so the whole browser API surface is reachable - but a few idioms differ from both Python and JS. The three you cannot guess: `new(Cls, ...)`, `.call(None, ...)`, and `glob` module state. (All of it applies to any client code - plain `.jac` inferred client from JSX/npm imports; markers are optional overrides. See `jac-codespaces`.)

> **`jac check` vs runtime:** isolated `jac check` has no typed stubs for browser globals yet, so it flags these patterns - `W2001` ("Name 'WebSocket' may be undefined"), `E1053`/`E1030`/`E1031` on `new()` args, `window.*`, `JSON.parse` - plus `W6002` portability nags. **They are correct at runtime and `jac build` succeeds.** Don't "fix" them into broken shapes; suppress per line with `# jac:ignore[CODE]` if you need a clean check.

## `new(Cls, ...)` - JS constructors (NOT the `new` keyword)

Jac has no JS-style `new` keyword - `ws = new WebSocket(url);` is a **parse error**. The ambient `new(Cls, ...args)` builtin is the spelling; it lowers to `Reflect.construct(Cls, [args])` (and on the server is a thin `Cls(*args)` alias):

```
ws = new(WebSocket, url);
parsed = new(URL, String(window.location.origin));
now = new(Date);
evt = new(CustomEvent, "my-event", {"detail": {"key": "value"}});
params = new(URLSearchParams, window.location.search);
m = new(Map);
promise = new(Promise, lambda (resolve: any, reject: any) {
    resolve.call(None, result);
});
```

## `.call(None, ...)` - invoking stored callbacks

A callback held in a variable/dict and invoked later must be called with `.call(None, args...)` - direct `cb(args)` can miscompile for stored JS functions:

```
msgHandler = onMessage;                      # assign to a local first
ws.onmessage = lambda (e: any) {
    msgHandler.call(None, JSON.parse(e.data));
};
```

Same for Promise `resolve`/`reject` and anything stashed in `_pendingCallbacks[id]`.

## `glob` - module-level state

`glob` in a client module is a JS module variable: shared across all components importing the module, survives re-renders, NOT reactive. Use for connections, caches, init-once flags:

```jac
glob _ws: any = None;
glob _initialized: bool = False;
```

## WebSocket recipe

```
glob _ws: any = None;

def:pub connectWs(url: str) {
    _ws = new(WebSocket, url);
    _ws.onopen = lambda { console.log("[ws] connected"); };
    _ws.onmessage = lambda (event: any) {
        try { handleMessage(JSON.parse(event.data)); }
        except Exception as e { console.error("[ws] message error:", e); }
    };
    _ws.onclose = lambda { console.log("[ws] closed"); };
}

def:pub sendWs(action: str, data: any) {
    if not _ws or _ws.readyState != 1 { return; }     # 1 = OPEN
    _ws.send(JSON.stringify({"action": action, "data": data}));
}
```

URL building: `wss:` when `window.location.protocol == "https:"`, else `ws:`; append tokens with `encodeURIComponent`.

Consuming a server-sent-event stream (raw `fetch` + `resp.body.getReader()` against a streaming `def:pub`) is covered in `jac-sv-streaming`.

## CustomEvent - cross-component bus

Dispatch: `window.dispatchEvent(new(CustomEvent, "theme-change", {"detail": {"theme": t}}));`. Listen in a single manual `useEffect` (so add/remove share the handler closure - see the entry/exit split warning in `jac-cl-components`):

```
useEffect(lambda {
    handler = lambda (e: any) { theme = e.detail.theme; };
    window.addEventListener("theme-change", handler);
    return lambda { window.removeEventListener("theme-change", handler); };
}, []);
```

## Browser globals

`localStorage.getItem/setItem/removeItem`, `window.addEventListener`, `document.querySelector`, `setTimeout`/`setInterval`/`clearInterval`, `requestAnimationFrame`, `JSON.parse/stringify`, `encodeURIComponent`, `globalThis.*` (including `[client.vite.define]` build-time constants) - all available directly, no import. `URLSearchParams` is available too, but it's a constructor - build it with `new(URLSearchParams, ...)`, not a bare call (see above). See the `jac check` note above.

## Timing patterns (all use `Ref` value fields - see `jac-npm-packages`)

- **Polling:** single `useEffect` returning cleanup - `interval = setInterval(lambda { fetch_data(); }, 5000); return lambda { clearInterval(interval); };`. Outer lambda must NOT be `-> None`.
- **Debounce:** `has timerRef: Ref[any] = Ref(None);` - on each call `if timerRef.current { clearTimeout(timerRef.current); } timerRef.current = setTimeout(lambda { doSave(); }, 2000);`.
- **RAF batching:** `if rafRef.current { return; } rafRef.current = requestAnimationFrame(lambda { rafRef.current = None; applyPosition(lastX.current); });`.
- **Duplicate-submit guard:** `has sendingRef: Ref[bool] = Ref(False);` - check/set around the awaited call in a `try`/`finally`.

## String gotchas

- **Newlines:** jac2js emits a literal `"\n"` as a backslash-n in cl code - declare `glob _NL: str = chr(10);` once and use `text.split(_NL)` / `lines.join(_NL)` (blank-line separator: `_NL + _NL`). `String.fromCharCode(10)` works too; `chr(10)` is the standard spelling.
- **Quotes in f-strings:** f-strings with embedded quotes can miscompile - prefer concatenation: `cmd = "[ -f \"" + path + "\" ]";`. F-strings are fine for simple `f"Count: {count}"`.

## jac2js `let` scoping - assign before you branch

A variable whose FIRST assignment sits inside an `if`/`else` body compiles to a block-scoped `let` inside that branch, so any use after the branch is a silent runtime crash (TDZ `ReferenceError`) - nothing at compile time. Give the variable its first assignment BEFORE the branch:

```
# FRAGILE - first assignment inside the branches emits a block-scoped `let`
if triple { j = i + 3; }
else { j = i + 1; }
chunk = src[i:j];                  # ReferenceError: j is not defined

# CORRECT - first assignment before/instead of the branch
j = i + 3 if triple else i + 1;
chunk = src[i:j];
```

## Debugging compiled output

Generated JS lives in `.jac/client/` - `compiled/` (per-module JS from your client modules, readable), `dist/` (production bundle), `configs/` (generated vite/tailwind configs). When an interop pattern misbehaves, read `compiled/<module>.js` to see exactly what was emitted. Prefix `console.log("[useAuth] ...")` messages for DevTools filtering. Build failures: `JAC_DEBUG=1 jac start` for raw Vite output (see `jac-fullstack-patterns`).

## See also

- `jac-cl-components` - component shape, effects, the entry/exit closure split
- `jac-npm-packages` - `Ref[T]` value refs used by the timing patterns
- `jac-cl-organization` - where service modules with `glob` state live
