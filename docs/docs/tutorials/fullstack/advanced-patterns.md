# Advanced Patterns & JS Interop

When building real applications, you'll encounter patterns that go beyond basic components and state. This tutorial covers WebSocket communication, JavaScript interop gotchas, module-level state, and debugging strategies for Jac client code.

These patterns are drawn from [JacBuilder](https://github.com/jaseci-labs/jacBuilder), a production Jac application with 150+ client-side `.cl.jac` files.

> **Prerequisites**
>
> - Completed: [NPM Packages & UI Libraries](npm-and-libraries.md)
> - Time: ~30 minutes

!!! note "Browser globals and `jac check`"
    Most snippets on this page reference browser globals (`Reflect`, `WebSocket`, `console`, `JSON`, `URL`, `String`, `Date`, `window`, `document`, `setTimeout`, `requestAnimationFrame`, `Promise`, etc.). These are provided by the JS runtime when the file is bundled with `jac start`, but the static checker does not yet ship typed stubs for them, so isolated `jac check` runs flag those names as Unknown. The patterns work as written at runtime; typed stubs land with the browser-globals story tracked as a separate type-checker improvement.

---

## WebSocket Client

### Creating a WebSocket

In Jac client code, use the `new(...)` ambient builtin to instantiate browser built-in objects like `WebSocket`. (The compiler lowers the call to `Reflect.construct(WebSocket, [url])` in the emitted JS; you do not need to write that out by hand.)

```jac
glob _ws: any = None;

def connectWebSocket(url: str) -> None {
    _ws = new(WebSocket, url);

    _ws.onopen = lambda {
        console.log("WebSocket connected");
    };

    _ws.onmessage = lambda(event: any) {
        try {
            msg = JSON.parse(event.data);
            handleMessage(msg);
        } except Exception as e {
            console.error("WS message error:", e);
        }
    };

    _ws.onerror = lambda(e: any) {
        console.warn("WS error:", e);
    };

    _ws.onclose = lambda {
        console.log("WebSocket closed");
    };
}
```

### Sending Messages

```jac
def sendMessage(action: str, data: any) -> None {
    if not _ws or _ws.readyState != 1 {
        console.warn("WebSocket not connected");
        return;
    }

    msg = {
        "action": action,
        "data": data
    };

    try {
        _ws.send(JSON.stringify(msg));
    } except Exception as e {
        console.warn("WS send failed:", e);
    }
}
```

### Request/Response Pattern with Callbacks

For WebSocket protocols that use request IDs:

```jac
glob _nextReqId: int = 1;
glob _pendingCallbacks: any = {};

def wsRequest(method: str, params: any, callback: any) -> None {
    reqId = _nextReqId;
    _nextReqId = _nextReqId + 1;

    msg = {
        "id": reqId,
        "method": method,
        "params": params
    };

    _pendingCallbacks[String(reqId)] = callback;
    _ws.send(JSON.stringify(msg));
}

def handleResponse(msg: any) -> None {
    if msg and msg.id != undefined and _pendingCallbacks[String(msg.id)] {
        cb = _pendingCallbacks[String(msg.id)];
        _pendingCallbacks[String(msg.id)] = undefined;
        cb.call(None, msg);
    }
}
```

### Constructing WebSocket URLs

```jac
def buildWsUrl(basePath: str, token: str) -> str {
    wsUrl = new(URL, String(window.location.origin));
    wsUrl.protocol = ("wss:" if window.location.protocol == "https:" else "ws:");
    wsUrl.pathname = basePath;
    wsUrl.search = "?token=" + encodeURIComponent(token);
    return wsUrl.toString();
}
```

---

## JavaScript Interop Gotchas

Jac compiles to JavaScript, and there are several patterns where you need to work with the compiled output in mind.

!!! tip "Lambda, closure, IIFE, and factory analogs from JS"
    For a side-by-side mapping of common JS function idioms (`x => x + 1`, IIFEs, closure factories) to their Jac equivalents, see [§8 IIFE & Anonymous Factories](../../reference/language/functions-objects.md#8-iife-anonymous-factories) in the language reference.

### The `new(...)` Builtin for JS Constructors

Jac does not have a JavaScript-style `new` keyword. Instead, the ambient `new(Cls, ...args)` builtin is the portable spelling; in `cl` blocks the compiler lowers it to `Reflect.construct(Cls, [args])` in the generated JavaScript, which is the standard JS reflection API equivalent to `new Cls(...)`. The same call also works on the server, where it is a thin alias for `Cls(*args)`.

<!-- jac-skip -->
```jac
# WebSocket
ws = new(WebSocket, url);

# URL
url = new(URL, String(base));

# Date
now = new(Date);

# Promise
promise = new(Promise, lambda(resolve: any, reject: any) {
    # ... async work ...
    resolve.call(None, result);
});

# CustomEvent
evt = new(CustomEvent, "my-event", {"detail": {"key": "value"}});
window.dispatchEvent(evt);

# Map
map = new(Map);

# xterm.js Terminal
terminal = new(XTerminal, termConfig);
```

### Callback Invocations with .call()

When passing callbacks that will be invoked later, use `.call(None, ...)` to avoid issues with how Jac compiles function calls:

<!-- jac-skip -->
```jac
# Assign callback to local variable, then use .call()
msgHandler = onMessage;
ws.onmessage = lambda(e: any) {
    msg = JSON.parse(e.data);
    msgHandler.call(None, msg);
};

# Promise resolve/reject
new(Promise, lambda(resolve: any, reject: any) {
    resolveFn = resolve;
    rejectFn = reject;

    doAsyncWork(
        lambda(result: any) { resolveFn.call(None, result); },
        lambda(err: any) { rejectFn.call(None, err); }
    );
});
```

### String Concatenation vs F-Strings

F-strings in Jac client code can have issues with certain characters. When building strings with quotes or special characters, prefer concatenation:

<!-- jac-skip -->
```jac
# Prefer concatenation for strings with quotes
cmd = "[ -f \"" + path + "\" ]";

# F-strings work fine for simple cases
label = f"Count: {count}";
```

### Newline Constants

Literal `"\n"` may not work as expected in compiled JavaScript. Use `String.fromCharCode()`:

<!-- jac-skip -->
```jac
glob _NL: str = String.fromCharCode(10);

# Usage
lines = text.split(_NL);
output = lines.join(_NL);
```

### Module-Level State with `glob`

Use `glob` for state that persists across component renders and is shared across the module:

```jac
# Module-level state (like JavaScript module variables)
glob monacoInitialized: bool = False;
glob cachedConfig: any = None;
glob initPromise: any = None;

async def:pub initializeOnce() -> any {
    if monacoInitialized {
        return cachedConfig;
    }
    if initPromise {
        return await initPromise;
    }
    initPromise = performInit();
    return await initPromise;
}
```

### globalThis and Browser APIs

Access browser globals through `globalThis` or directly:

<!-- jac-skip -->
```jac
# localStorage
localStorage.getItem("auth_token");
localStorage.setItem("auth_token", token);
localStorage.removeItem("auth_token");

# Build-time injected constants (from [plugins.client.vite.define])
version = globalThis.__APP_VERSION__;
apiBase = globalThis.__API_BASE_URL__;

# Browser APIs
window.addEventListener("resize", lambda(e: any) { handleResize(); });
document.querySelector(".my-element");
```

### Custom Events (Cross-Component Communication)

```jac
glob _THEME_EVENT: str = "theme-change";

# Dispatch
def dispatchThemeChange(theme: str) -> None {
    evt = new(
        CustomEvent,
        _THEME_EVENT,
        {"detail": {"theme": theme}}
    );
    window.dispatchEvent(evt);
}

# Listen
import from react { useEffect }

def:pub ThemeListener() -> JsxElement {
    has theme: str = "light";

    useEffect(lambda -> None {
        handler = lambda(e: any) {
            theme = e.detail.theme;
        };
        window.addEventListener(_THEME_EVENT, handler);
        return lambda -> None {
            window.removeEventListener(_THEME_EVENT, handler);
        };
    }, []);

    return <div className={theme}>Content</div>;
}
```

---

## Async Patterns

### Async File Reading with Promises

```jac
def readAllEntries(reader: any) -> any {
    return new(Promise, lambda(resolve: any, reject: any) {
        allEntries: list = [];
        resolveFn = resolve;
        rejectFn = reject;

        def readBatch() -> None {
            reader.readEntries(
                lambda(entries: any) {
                    if not entries or entries.length == 0 {
                        resolveFn.call(None, allEntries);
                    } else {
                        for e in entries {
                            allEntries.push(e);
                        }
                        readBatch();
                    }
                },
                lambda(err: any) { rejectFn.call(None, err); }
            );
        }
        readBatch();
    });
}
```

### Debounced Auto-Save

```jac
import from react { useRef }

def:pub useAutoSave() -> any {
    timerRef = useRef(None);

    def save(path: str, content: str) -> None {
        # Clear previous timer
        if timerRef.current {
            clearTimeout(timerRef.current);
        }
        # Set new 2-second debounce
        timerRef.current = setTimeout(lambda {
            timerRef.current = None;
            writeFile(path, content);
        }, 2000);
    }

    def flush() -> None {
        if timerRef.current {
            clearTimeout(timerRef.current);
            timerRef.current = None;
        }
    }

    return {"save": save, "flush": flush};
}
```

### requestAnimationFrame for Smooth UI

```jac
import from react { useRef }

def:pub useDrag() -> any {
    isDraggingRef = useRef(False);
    rafRef = useRef(None);
    lastXRef = useRef(0);

    def onMouseMove(e: any) -> None {
        if not isDraggingRef.current { return; }
        lastXRef.current = e.clientX;

        # Batch DOM updates with RAF
        if rafRef.current { return; }
        rafRef.current = requestAnimationFrame(lambda {
            rafRef.current = None;
            applyPosition(lastXRef.current);
        });
    }

    return {"onMouseMove": onMouseMove};
}
```

---

## Debugging Client Code

### Console Logging with Context Prefixes

Use prefixed log messages to trace issues across components and services:

<!-- jac-skip -->
```jac
# Good - prefixed for easy filtering
console.log("[useAuth] Login attempt for:", username);
console.warn("[WebSocket] Connection lost, reconnecting...");
console.error("[DataLoader] Failed to fetch:", err);

# In browser DevTools, filter by prefix: "[useAuth]"
```

### Error Recovery with Retry Limits

```jac

glob _errorCount: int = 0;
glob _maxRetries: int = 10;

def handleError(context: str, err: any) -> None {
    _errorCount = _errorCount + 1;
    console.error(f"[{context}] Error #{_errorCount}:", err);

    if _errorCount >= _maxRetries {
        console.warn(f"[{context}] Max retries reached, stopping.");
        return;
    }

    # Retry with backoff
    delay = 500 * _errorCount;
    setTimeout(lambda { retry(); }, delay);
}
```

### Preventing Duplicate Operations

```jac
import from react { useRef }

def:pub useSafeSubmit() -> any {
    sendingRef = useRef(False);

    async def submit(data: any) -> any {
        if sendingRef.current {
            console.warn("[submit] Already in progress, skipping");
            return None;
        }
        sendingRef.current = True;
        try {
            result = await doSubmit(data);
            return result;
        } except Exception as e {
            console.error("[submit] Failed:", e);
            return None;
        } finally {
            sendingRef.current = False;
        }
    }

    return submit;
}
```

### Build Error Diagnostics

When client builds fail, Jac provides structured error messages:

| Code | Issue | Fix |
|------|-------|-----|
| `JAC_CLIENT_001` | Missing npm dependency | `jac add --npm <package>` |
| `JAC_CLIENT_003` | Syntax error in client code | Check the source snippet in the error |
| `JAC_CLIENT_004` | Unresolved import | Verify import path and package name |

Enable debug mode for raw Vite output:

```toml
# jac.toml
[plugins.client]
debug = true
```

Or via environment variable:

```bash
JAC_DEBUG=1 jac start
```

### Inspecting Generated JavaScript

The compiled JavaScript lives in `.jac/client/`. When debugging tricky issues, inspect the generated code:

```
.jac/
└── client/
    ├── compiled/     # Generated JS from your .cl.jac files
    ├── dist/         # Production build output
    ├── configs/      # Generated config files (vite, tailwind, etc.)
    └── node_modules/ # Installed npm dependencies
```

Browser DevTools source maps should point back to your original `.jac` files when available.

---

## Common Patterns from Production Apps

### Service Layer Pattern

Organize API calls and WebSocket logic into service modules separate from UI components:

```
myapp/
├── services/
│   ├── apiService.cl.jac      # REST API calls
│   └── wsService.cl.jac       # WebSocket management
├── hooks/
│   ├── useAuth.cl.jac         # Auth state hook
│   └── useData.cl.jac         # Data fetching hook
├── components/
│   └── ui/                    # Reusable UI components
├── pages/                     # Route pages
└── lib/
    └── utils.cl.jac           # cn() and other utilities
```

### Custom Hook Pattern

Extract reusable stateful logic into custom hooks (functions starting with `use`):

```jac

# hooks/usePolling.cl.jac
import from react { useRef, useEffect }

def:pub usePolling(callback: any, intervalMs: int, enabled: bool) -> None {
    timerRef = useRef(None);
    callbackRef = useRef(callback);
    callbackRef.current = callback;

    useEffect(lambda -> None {
        if not enabled { return lambda -> None {}; }

        def tick() -> None {
            callbackRef.current.call(None);
            timerRef.current = setTimeout(tick, intervalMs);
        }
        tick();

        return lambda -> None {
            if timerRef.current {
                clearTimeout(timerRef.current);
            }
        };
    }, [intervalMs, enabled]);
}
```

### IFrame Pointer-Events Workaround

When dragging near iframes (common in editors/previews), the iframe steals mouse events:

```jac
def:pub PreviewPanel() -> JsxElement {
    has isDragging: bool = False;

    return <div>
        <div
            onMouseDown={lambda -> None { isDragging = True; }}
            onMouseUp={lambda -> None { isDragging = False; }}
        />
        <iframe
            src={previewUrl}
            style={{"pointerEvents": ("none" if isDragging else "auto")}}
        />
    </div>;
}
```

---

## Key Takeaways

| Pattern | Jac Approach |
|---------|-------------|
| Instantiate browser objects | `new(ClassName, ...args)` |
| Invoke callbacks | `callback.call(None, arg)` |
| Module-level state | `glob varname: Type = value;` |
| Browser globals | `globalThis.X`, `window.X`, `localStorage` |
| Newline character | `String.fromCharCode(10)` |
| Debug logging | `console.log("[prefix]", data)` |
| WebSocket | `new(WebSocket, url)` |

---

## Next Steps

- [Backend Integration](backend.md) - Connect UI to server walkers
- [Authentication](auth.md) - Add user login
- [Routing](routing.md) - Navigate between pages
