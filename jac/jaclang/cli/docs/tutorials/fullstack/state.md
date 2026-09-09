# State Management

Interactive applications need to track and respond to changing data -- a counter incrementing, a list of items growing, a form being filled out. In Jac's client-side code, state management uses the `has` keyword inside component functions to declare reactive variables. When a `has` variable changes, the component automatically re-renders to reflect the new value, just like React's `useState` hook.

This tutorial covers declaring reactive state, handling user input, sharing state between components, and managing complex state with effects and derived values.

> **Prerequisites**
>
> - Completed: [React-Style Components](components.md)
> - Time: ~30 minutes

!!! note "Reactive state, hooks, and `jac check`"
    Some blocks below mix reactive `has` state with React-flavored helpers (`createContext`, `useContext`, async effect blocks). Jac's bundler wires all of this up at build time, but the static checker has not yet shipped typed stubs for every React import, so isolated `jac check` runs flag the corresponding accesses as Unknown. The patterns work as written under `jac run`.

---

## Reactive State with `has`

Inside client-placed code, `has` creates reactive state (like React's `useState`). Declaring `has count: int = 0;` inside a component function creates a stateful variable that persists across re-renders and triggers a UI update whenever its value changes:

```jac
def:pub Counter() -> JsxElement {
    has count: int = 0;  # Reactive state

        <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>
    }
```

**How it works:**

- `has count: int = 0` compiles to `const [count, setCount] = useState(0)`
- Assignments like `count = count + 1` become `setCount(count + 1)`
- The component re-renders when state changes

---

## Multiple State Variables

```jac
def:pub Form() -> JsxElement {
    has name: str = "";
    has email: str = "";
    has submitted: bool = False;

    def handle_submit() -> None {
        print(f"Submitting: {name}, {email}");
        submitted = True;
    }

    if submitted {
        return <p>Thanks, {name}!</p>;
    }

    return <form>
        <input
            value={name}
            onChange={lambda (e: ChangeEvent) { name = e.target.value; }}
            placeholder="Name"
        />
        <input
            value={email}
            onChange={lambda (e: ChangeEvent) { email = e.target.value; }}
            placeholder="Email"
        />
        <button
            type="button"
            onClick={lambda -> None { handle_submit(); }}
        >
            Submit
        </button>
    </form>;
}
```

---

## Complex State (Objects/Lists)

```jac
def:pub TodoApp() -> JsxElement {
    has todos: list = [];
    has input_text: str = "";

    def add_todo() -> None {
        if input_text {
            todos = todos + [{"id": len(todos), "text": input_text}];
            input_text = "";
        }
    }

    def remove_todo(id: int) -> None {
        todos = [t for t in todos if t["id"] != id];
    }

    return <div>
        <input
            value={input_text}
            onChange={lambda (e: ChangeEvent) { input_text = e.target.value; }}
        />
        <button onClick={lambda -> None { add_todo(); }}>Add</button>

        <ul>
            {[
                <li key={todo["id"]}>
                    {todo["text"]}
                    <button onClick={lambda -> None { remove_todo(todo["id"]); }}>
                        X
                    </button>
                </li>
                for todo in todos
            ]}
        </ul>
    </div>;
}
```

**Important:** For lists and objects, create new references:

- `todos = [...todos, newItem]` (spread to new list)
- `todos = [t for t in todos if condition]` (filter to new list)

---

## useEffect - Side Effects

### Automatic Effects with `can with entry/exit`

Similar to how `has` automatically generates `useState`, you can use `can with entry` and `can with exit` to automatically generate `useEffect` hooks:

```jac
def:pub DataFetcher() -> JsxElement {
    has data: list = [];
    has loading: bool = True;

    # Run once on mount - async effects are wrapped in IIFE automatically
    async can with entry {
        result = await some_async_operation();
        data = result;
        loading = False;
    }

    if loading {
        return <p>Loading...</p>;
    }

    return <ul>
        {[<li key={item.id}>{item.name}</li> for item in data]}
    </ul>;
}
```

### Effect Dependencies

Use list syntax `[dep1, dep2]` to specify dependencies (similar to React's dependency arrays):

```jac
def:pub SearchResults() -> JsxElement {
    has query: str = "";
    has results: list = [];

    # Run when query changes
    async can with [query] entry {
        if query {
            results = await search_api(query);
        }
    }

    return <div>
        <input
            value={query}
            onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
        />
        <ul>
            {[<li>{r}</li> for r in results]}
        </ul>
    </div>;
}
```

### Cleanup Effects

`can with exit` generates a standalone cleanup `useEffect` -- use it for teardown that does **not** depend on a handle created at mount:

```jac
def:pub Subscriber() -> JsxElement {
    has events: list = [];

    can with entry {
        subscribe_to_events();
    }

    # Cleanup on unmount
    can with exit {
        cleanup_subscriptions();
    }

    return <p>{len(events)} events</p>;
}
```

### Setup with a Local Cleanup Handle

Return a cleanup function from a **synchronous** `can with entry` block when
setup creates a timer, observer, or subscription. Setup and cleanup share the
same closure, so cleanup releases exactly the resource that setup created:

```jac
def:pub Timer() -> JsxElement {
    has seconds: int = 0;

    can with entry {
        intervalId = setInterval(lambda { seconds += 1; }, 1000);
        return lambda { clearInterval(intervalId); };
    }

    return <p>Seconds: {seconds}</p>;
}
```

On React and Preact, cleanup runs before setup runs again when a listed
dependency changes, and on unmount. For example, `can with [channel] entry`
can subscribe to a channel and return a function that unsubscribes from that
same subscription. Solid registers the returned function with `onCleanup`;
its effects track reactive reads automatically.

Separate `can with entry` and `can with exit` blocks have separate closures.
Use a returned cleanup when teardown needs setup-local variables. An exit
block is useful for teardown that reads a component-level `Ref` instead.
Return either a cleanup function or no value from a synchronous entry block.

Async entry blocks run inside an async task. Their return values **do not**
register cleanup. When async work needs cancellation, start it inside a
synchronous entry block and return cancellation from that outer block:

```jac
can with [url] entry {
    controller = new(AbortController);
    async def load {
        try {
            response = await fetch(url, {"signal": controller.signal});
            result = await response.json();
            if not controller.signal.aborted {
                data = result;
            }
        } except Exception {
            if not controller.signal.aborted {
                error = "Could not load data";
            }
        }
    }
    _ = load();
    return lambda { controller.abort(); };
}
```

Here `url`, `data`, and `error` are component state. Returning a value from an
async entry or an exit block produces W2014 because that value is ignored.

### Manual useEffect

The lifecycle syntax above is the idiomatic approach, including effects that use refs or return cleanup. Explicit `useEffect` remains available for React library interoperability:

```jac
import from react { useEffect }

def:pub DataFetcher() -> JsxElement {
    has data: list = [];

    useEffect(lambda -> None {
        fetch_data();
    }, []);

    return <div>...</div>;
}
```

---

## Refs with `Ref[T]`

Just as `has` declares reactive state (`useState`) and `can with entry` declares effects (`useEffect`), a `has`-field typed `Ref[T]` declares a **ref** -- a mutable container that persists across renders but, unlike state, does **not** trigger a re-render when its `.current` changes. It compiles to React's `useRef`:

```jac
def:pub FocusableInput() -> JsxElement {
    has inputRef: Ref[HTMLInputElement] = Ref();  # -> const inputRef = useRef(null)

    def focus() -> None {
        if inputRef.current { inputRef.current.focus(); }
    }

    return <div>
        <input ref={inputRef} type="text" />
        <button onClick={lambda -> None { focus(); }}>Focus</button>
    </div>;
}
```

- `has r: Ref[T] = Ref()` compiles to `const r = useRef(null)` -- an empty DOM ref. Wire it to an element with `ref={r}`; React fills in `r.current` on mount.
- `has r: Ref[T] = Ref(initial)` compiles to `const r = useRef(initial)` -- a value ref seeded with `initial`, for mutable values that should survive re-renders without causing one.
- `useRef` is auto-imported from React; you do not import it yourself.

The field must be constructed (`= Ref()` / `= Ref(initial)`); a bare `has r: Ref[T];` is rejected ([E2025](../../reference/diagnostics.md)) because, like every other `has`-field, it needs a value. `.current` is typed `T | None`, so null-check it before use.

### Forwarding a ref into your component

The example above uses a ref *inside* a component. The other direction -- letting a **parent** attach a ref to a component *you* wrote -- comes down to one rule: **`ref` is an ordinary prop.** The client runtime is React 19, where a function component receives `ref` in its props like any other prop.

The compiler never threads it onto an element for you. A ref reaches a DOM node only where **you** write `ref=`, or where you spread a props bundle that still carries it. Which shape that takes depends on how the component declares its props.

**A props-bundle component already receives it.** `props["ref"]` is set, so any spread of the bundle -- or of a rest copy that does not exclude `ref` -- lands it on the host element:

```jac
# jac:ignore[W5015]
def:pub FancyInput(props: any) -> JsxElement {
    <input className="fancy" {**props} />
}
```

That is the whole mechanism behind every installed `components/ui/` primitive, and it is why they work as radix `asChild` anchors with no ref plumbing of their own.

A props bundle costs per-attribute call-site validation, so [components](components.md#forwarding-the-props-bundle-advanced) tells you to default to named parameters and the compiler emits **W5015** on every single-`props` definition. Being a ref target is precisely the intentional forwarding that warning leaves room for: keep the bundle here and silence it with `# jac:ignore[W5015]`, and keep named parameters everywhere else.

**A named-param component does not**, because named params destructure only what they declare and `ref` is not among them. Declare a trailing parameter typed `Ref` to receive it; that lowers to React's `forwardRef((props, ref) => ...)` render signature:

```jac
def:pub FancyLabel(text: str, ref: Ref[HTMLElement]) -> JsxElement {
    <span ref={ref} className="fancy">{text}</span>
}
```

Either way, a parent points its own ref at the component and reaches the underlying host node:

```jac
def:pub ParentForm() -> JsxElement {
    has inputRef: Ref[HTMLInputElement] = Ref();
    <FancyInput ref={inputRef} placeholder="Type here" />
}
```

- For the trailing-param form, only the **last** parameter qualifies, and it must be typed `Ref` (or `Ref[T]`). Named props before it destructure as usual; `ref` stays the trailing positional argument and is never folded into the props bundle. `forwardRef` is auto-imported from React; you do not import it yourself.
- A component that neither spreads its props onto a host node nor declares a `ref` parameter simply drops the ref. Nothing warns about it, so if a popover will not position, that is the first thing to check.

This is what makes a component usable as a [radix](npm-and-libraries.md) `asChild` trigger -- `DropdownMenuTrigger`, `Tooltip.Trigger`, `Popover.Trigger`, and friends attach a ref to their child to use as a positioning anchor. A child that never lands the ref on an element leaves that anchor null, and the popper positions at the viewport origin instead of at the trigger.

---

## useContext - Global State

### Creating Context

```jac
import from react { createContext, useContext }

# Create context
glob AppContext = createContext(None);

# Provider component -- `children` is the nested JSX passed between its tags
def:pub AppProvider(children: any = None) -> JsxElement {
    has user: any = None;
    has theme: str = "light";

    value = {
        "user": user,
        "theme": theme,
        "setUser": lambda (u: any) -> None { user = u; },
        "setTheme": lambda (t: str) -> None { theme = t; }
    };

    <AppContext.Provider value={value}>
        {children}
    </AppContext.Provider>
}

def:pub ThemeToggle() -> JsxElement {
    ctx = useContext(AppContext);

    return <button onClick={lambda -> None {
        ctx.setTheme("dark" if ctx.theme == "light" else "light");
    }}>
        Toggle Theme ({ctx.theme})
    </button>;
}

def:pub app() -> JsxElement {
    return <AppProvider>
        <UserDisplay />
        <ThemeToggle />
    </AppProvider>;
}
```

---

## Custom Hooks

Create reusable state logic:

```jac
import from react { useEffect }

# Custom hook
def use_local_storage(key: str, initial_value: any) -> tuple {
    has value: any = initial_value;

    # Load from localStorage on mount
    useEffect(lambda -> None {
        stored = localStorage.getItem(key);
        if stored {
            value = JSON.parse(stored);
        }
    }, []);

    # Save to localStorage when value changes
    useEffect(lambda -> None {
        localStorage.setItem(key, JSON.stringify(value));
    }, [value]);

    return (value, lambda (v: any) -> None { value = v; });
}

def:pub Settings() -> JsxElement {
    (theme, set_theme) = use_local_storage("theme", "light");

        <div>
            <p>Current theme: {theme}</p>
            <button onClick={lambda -> None { set_theme("dark"); }}>
                Dark
            </button>
            <button onClick={lambda -> None { set_theme("light"); }}>
                Light
            </button>
        </div>
    }
```

---

## State Patterns

### Loading State Pattern

```jac
def:pub DataComponent() -> JsxElement {
    has data: any = None;
    has loading: bool = True;
    has error: str = "";

    # ... fetch data ...

    if loading {
        return <div className="spinner">Loading...</div>;
    }

    if error {
        return <div className="error">{error}</div>;
    }

    return <div>{data}</div>;
}
```

### Form State Pattern

```jac
def:pub ContactForm() -> JsxElement {
    has form_data: dict = {
        "name": "",
        "email": "",
        "message": ""
    };
    has errors: dict = {};
    has submitting: bool = False;

    def update_field(field: str, value: str) -> None {
        form_data = {**form_data, field: value};
    }

    def validate() -> bool {
        new_errors = {};
        if not form_data["name"] {
            new_errors["name"] = "Name is required";
        }
        if "@" not in form_data["email"] {
            new_errors["email"] = "Invalid email";
        }
        errors = new_errors;
        return len(new_errors) == 0;
    }

    def handle_submit() -> None {
        if validate() {
            submitting = True;
            # ... submit form ...
        }
    }

    return <form>
        <input
            value={form_data["name"]}
            onChange={lambda (e: ChangeEvent) { update_field("name", e.target.value); }}
        />
        {errors.get("name") and <span className="error">{errors["name"]}</span>}
    </form>;
}
```

---

## Key Takeaways

| Concept | Jac Syntax | React Equivalent |
|---------|------------|------------------|
| State variable | `has count: int = 0` | `useState(0)` |
| Update state | `count = count + 1` | `setCount(count + 1)` |
| Effect on mount | `can with entry { ... }` | `useEffect(fn, [])` |
| Effect with deps | `can with [dep] entry { ... }` | `useEffect(fn, [dep])` |
| Cleanup on unmount | `can with exit { ... }` | `useEffect(() => cleanup, [])` |
| Global state | `useContext(Ctx)` | Same |

---

## Next Steps

- [Backend Integration](backend.md) - Fetch data from walkers
- [Authentication](auth.md) - Add user login
