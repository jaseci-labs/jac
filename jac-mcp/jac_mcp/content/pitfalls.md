# Jac Pitfalls for AI Models

Common mistakes AI models make when generating Jac code. Each entry shows the WRONG pattern and the correct Jac syntax.

## Syntax Differences from Python

### 1. Semicolons are required on ALL statements

WRONG:

```
x = 5
print(x)
```

RIGHT:

```jac
x = 5;
print(x);
```

### 2. Braces for blocks, not indentation

WRONG:

```
if x > 5:
    print(x)
```

RIGHT:

```jac
if x > 5 {
    print(x);
}
```

### 3. Import syntax is different

WRONG (Python style):

```
from os import path
from typing import Any
```

WRONG (deprecated Jac v1 syntax -- do NOT use):

```
import:py from os { path }
import:py typing;
```

RIGHT:

```jac
import from os { path }
import from typing { Any }
```

The `import:py` prefix is **removed** from modern Jac. All imports use plain `import` -- Python modules are imported the same way as Jac modules. Never generate `import:py`, `include:jac`, or any colon-tagged import variant.

### 4. Prefer `obj` over Python-style `class`

Jac supports both `obj` (dataclass-like, auto-generates `__init__`, `__eq__`, `__repr__`) and `class` (standard Python class behavior). **Prefer `obj`** unless you specifically need Python class semantics.

WRONG (Python syntax):

```
class Foo:
    pass
```

RIGHT (idiomatic Jac):

```jac
obj Foo {
    has x: int = 5;
}
```

ALSO VALID (when you need Python class behavior):

```jac
class Foo {
    def init(name: str) {
        self.name = name;
    }
}
```

For graph programming, use `node`, `edge`, and `walker` archetypes instead.

### 5. `def` for regular methods, `can` ONLY for event-driven abilities

Use `def` for regular methods in archetypes. The `can` keyword is ONLY for data-spatial abilities that respond to walker entry/exit events --the compiler enforces this with: *"Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"*

WRONG:

```
def my_method(self, x: int) -> int:
    return x + 1
```

RIGHT --regular method:

```jac
obj Foo {
    has x: int = 0;
    def my_method(val: int) -> int {
        return val + 1;
    }
}
```

RIGHT --event-driven ability (uses `can` with `with` clause):

```jac
walker MyWalker {
    can process with MyNode entry {
        report here.value;
        visit [-->];
    }
}
```

For declaration/implementation separation:

```jac
# In .jac file: declare method signature
obj Foo {
    has x: int = 0;
    def my_method(val: int) -> int;
}
```

```jac
# In .impl.jac file: implement it
impl Foo.my_method(val: int) -> int {
    return val + 1;
}
```

### 5b. `self` is implicit in `obj` method signatures

In `obj` (and `node`, `edge`, `walker`) methods, `self` is automatically available -- do NOT include it as a parameter. Adding `self` explicitly will cause errors.

WRONG:

```
obj Foo {
    has x: int = 0;
    def get_x(self) -> int {
        return self.x;
    }
}
```

RIGHT:

```jac
obj Foo {
    has x: int = 0;
    def get_x() -> int {
        return self.x;
    }
}
```

Note: `self` is still used *inside* the method body to access instance members -- it's just not declared in the parameter list.

### 6. Constructor is `def init`, not `def __init__`

WRONG:

```
def __init__(self, x: int):
    self.x = x
```

RIGHT:

```jac
obj Foo {
    has x: int;
    def init(x: int) {
        super.init();
        self.x = x;
    }
}
```

NOTE: You must explicitly call `super.init()` in the init body. Without a `def init`, the compiled class gets an empty `__init__`.

### 7. `enumerate()` requires tuple unpacking with parentheses

`enumerate()` works in Jac, but you MUST wrap the loop variables in parentheses for tuple unpacking.

WRONG:

```
for i, x in enumerate(items) {
    print(i, x);
}
```

RIGHT:

```jac
for (i, x) in enumerate(items) {
    print(i, x);
}
```

### 8. Backtick escaping for keywords used as identifiers

Jac keywords are reserved. To use one as a regular identifier (e.g., a variable or field name), prefix it with a backtick:

```jac
has `type: str;   # "type" is a keyword, backtick lets you use it as a field name
`edge = 5;        # "edge" is a keyword, backtick lets you use it as a variable
```

**However, special variable references do NOT need backtick escaping.** These are built-in references used directly as intended --they are not identifiers that happen to share a keyword name:

- `self` -- current instance
- `super` -- parent class
- `root` -- root node of the graph
- `here` -- current node (in walker abilities)
- `visitor` -- visiting walker (in node/edge abilities)
- `init` -- constructor method name
- `postinit` -- post-constructor method name

WRONG:

```
`self.name = "Alice";
`root ++> node;
def `init() { }
```

RIGHT:

```jac
self.name = "Alice";
root ++> node;
def init() { }
```

Keywords that commonly need backtick escaping when used as identifiers: `type`, `edge`, `node`, `obj`, `test`, `default`, `case`, `visit`, `spawn`, `root`, `entry`, `exit`.

### 9. Mutable objects are passed by reference automatically

In Jac (like Python), mutable objects (lists, dicts) are passed by reference by default. You don't need any special syntax:

```jac
def modify(data: list) -> None {
    data.append(42);
}
```

### 10. Instance variables use `has`, not `self`

WRONG:

```
obj Foo {
    def init(self) {
        self.x = 5;
    }
}
```

RIGHT:

```jac
obj Foo {
    has x: int = 5;
}
```

### 11. Static methods use `static def`

WRONG:

```
obj Foo {
    def bar(self) -> int {
        return 42;
    }
}
```

RIGHT --static method:

```jac
obj Foo {
    static def bar() -> int {
        return 42;
    }
}
```

Or as a standalone module-level function:

```jac
def bar() -> int {
    return 42;
}
```

### 12. String formatting

Jac supports f-strings with the same syntax as Python:

```jac
name = "world";
print(f"Hello, {name}!");
```

### 13. Type annotations are important

Always declare types on `has` declarations:

```jac
has x: int = 5;
has name: str = "";
has items: list[str] = [];
has mapping: dict[str, int] = {};
```

### 14. Boolean literals

Use Python-style `True`/`False`/`None`:

```jac
has active: bool = True;
has data: dict | None = None;
```

### 15. List/Dict comprehensions

```jac
squares = [x ** 2 for x in range(10)];
even = {k: v for (k, v) in items.items() if v % 2 == 0};
```

### 16. Exception handling

```jac
try {
    risky_operation();
} except ValueError as e {
    print(f"Error: {e}");
} finally {
    cleanup();
}
```

## Data-Spatial Gotchas

### 17. Walker definition and visit syntax

WRONG:

```
walker MyWalker {
    visit node.children;
}
```

RIGHT:

```jac
walker MyWalker {
    can visit_node with Node entry {
        visit [-->];
    }
}
```

### 18. Edge definitions

```jac
edge MyEdge {
    has weight: float = 1.0;
}
```

### 19. Graph construction with spawn

```jac
node A {
    has value: int = 0;
}
node B {
    has label: str = "";
}

with entry {
    a = A(value=1);
    b = B(label="hello");
    a ++> b;  # Connect a to b with default edge
}
```

### 20. Node connections and traversal

```jac
# Connect nodes
a ++> b;                    # default edge
a +>:MyEdge(weight=2.0):+> b;  # typed edge

# Traverse
visit [-->];           # visit all connected nodes
visit [-->](`?B);      # visit only B-type nodes
```

### 21. Walker spawn syntax

```jac
root spawn MyWalker();
```

## File Organization

### 22. Interface/Implementation separation

- `.jac` files contain declarations - method signatures end with `;`
- `.impl.jac` files (in `impl/` subdirectory) contain implementations

Declaration file (`module.jac`):

```jac
obj Calculator {
    has result: float = 0.0;
    def add(x: float) -> float;
    def reset() -> None;
}
```

Implementation file (`impl/module.impl.jac`):

```jac
impl Calculator.add(x: float) -> float {
    self.result += x;
    return self.result;
}

impl Calculator.reset -> None {
    self.result = 0.0;
}
```

### 23. A parse error in .impl.jac breaks the ENTIRE file

A single syntax error in an impl file causes all implementations in that file to produce 0 body items. Always check syntax carefully.

### 24. Module entry point

Use `with entry { }` for code that runs when the module is executed:

```jac
with entry {
    print("Hello, World!");
}
```

### 25. Global variables

Use `glob` for module-level variables:

```jac
glob MAX_SIZE = 100;
glob config: dict = {};
```

## Client-Side & Full-Stack Gotchas

### 26. Client components use `def:pub` inside `cl {}` blocks

Client-side components must be inside `cl { }` blocks (or in `.cl.jac` files). They return `JsxElement`, not Python objects.

WRONG (Python/React style):

```
function Greeting(props) {
    return <h1>Hello, {props.name}!</h1>;
}
```

WRONG (missing `cl` block -- this creates a SERVER function, not a client component):

```
def:pub Greeting(props: dict) -> JsxElement {
    return <h1>Hello, {props.name}!</h1>;
}
```

RIGHT:

```jac
cl {
    def:pub Greeting(props: dict) -> JsxElement {
        return <h1>Hello, {props.name}!</h1>;
    }
}
```

In `.cl.jac` files, the `cl { }` wrapper is not needed -- the entire file is already in client mode:

```jac
# In a .cl.jac file:
def:pub Greeting(props: dict) -> JsxElement {
    return <h1>Hello, {props.name}!</h1>;
}
```

### 27. Reactive state uses `has` inside component functions (NOT `useState`)

In client components, `has` compiles to React's `useState`. Do NOT import or call `useState` directly.

WRONG (React style):

```
import from react { useState }

cl {
    def:pub Counter() -> JsxElement {
        (count, setCount) = useState(0);
        return <button onClick={lambda -> None { setCount(count + 1); }}>
            {count}
        </button>;
    }
}
```

RIGHT:

```jac
cl {
    def:pub Counter() -> JsxElement {
        has count: int = 0;

        return <button onClick={lambda -> None { count = count + 1; }}>
            {count}
        </button>;
    }
}
```

Assignment to a `has` variable (`count = count + 1;`) automatically triggers re-render.

### 28. Lists and dicts MUST be replaced immutably to trigger re-render

Mutating a list or dict in place (e.g., `.append()`, `.pop()`, `dict[key] = val`) will NOT trigger a re-render. You must create a new reference.

WRONG (mutation -- UI will not update):

```
cl {
    def:pub TodoApp() -> JsxElement {
        has todos: list = [];

        def add_todo() -> None {
            todos.append({"text": "new item"});  # WRONG: mutates in place, no re-render
        }
    }
}
```

RIGHT (immutable update -- creates new list):

```jac
cl {
    def:pub TodoApp() -> JsxElement {
        has todos: list = [];

        def add_todo() -> None {
            todos = todos + [{"text": "new item"}];  # New list reference triggers re-render
        }

        def remove_todo(id: int) -> None {
            todos = [t for t in todos if t["id"] != id];  # Filter to new list
        }
    }
}
```

### 29. Dict spread uses `{**dict}`, NOT JavaScript `{...dict}`

Jac uses Python-style double-star unpacking for dict spread, not JavaScript's triple-dot syntax.

WRONG (JavaScript spread):

```
state = {...state, "field": new_value};
merged = {...dict1, ...dict2};
```

RIGHT:

```jac
state = {**state, "field": new_value};
merged = {**dict1, **dict2};
```

### 30. Event handlers REQUIRE type annotations on lambda parameters

Lambda event handlers must have type annotations. Omitting the type on the event parameter causes compilation errors.

WRONG (missing type annotation):

```
<input onChange={lambda e { name = e.target.value; }} />
```

WRONG (missing return type):

```
<input onChange={lambda e: any { name = e.target.value; }} />
```

RIGHT:

```jac
<input onChange={lambda e: any -> None { name = e.target.value; }} />
```

For click handlers with no event parameter:

```jac
<button onClick={lambda -> None { handle_click(); }}>Click</button>
```

### 31. Prefer `can with entry/exit` over manual `useEffect`

Jac has built-in syntax for React lifecycle effects. Prefer `can with entry` (mount) and `can with exit` (cleanup) over importing `useEffect` manually. Manual `useEffect` from React IS valid but not idiomatic Jac.

NOT IDIOMATIC (manual useEffect -- valid but not preferred):

```jac
cl {
    import from react { useEffect }

    def:pub DataLoader() -> JsxElement {
        has data: list = [];

        useEffect(lambda -> None {
            fetch_data();
        }, []);

        return <div>...</div>;
    }
}
```

PREFERRED (on mount -- empty dependency array):

```jac
cl {
    def:pub DataLoader() -> JsxElement {
        has data: list = [];
        has loading: bool = True;

        async can with entry {
            result = await fetch_data();
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
}
```

RIGHT (with dependency array -- runs when `query` changes):

```jac
cl {
    def:pub SearchResults() -> JsxElement {
        has query: str = "";
        has results: list = [];

        async can with [query] entry {
            if query {
                results = await search_api(query);
            }
        }

        return <div>
            <input
                value={query}
                onChange={lambda e: any -> None { query = e.target.value; }}
            />
        </div>;
    }
}
```

RIGHT (cleanup on unmount):

```jac
cl {
    def:pub Timer() -> JsxElement {
        has seconds: int = 0;

        can with entry {
            intervalId = setInterval(lambda -> None {
                seconds = seconds + 1;
            }, 1000);
        }

        can with exit {
            clearInterval(intervalId);
        }

        return <p>Seconds: {seconds}</p>;
    }
}
```

### 32. Use `className`, not `class`, for CSS classes in JSX

Like React, Jac JSX uses `className` instead of the HTML `class` attribute.

WRONG:

```
<div class="container">Hello</div>
```

RIGHT:

```jac
<div className="container">Hello</div>
```

### 33. List rendering needs `key` prop and comprehension syntax

WRONG (React `.map()` style):

```
{items.map(item => <Item key={item.id} item={item} />)}
```

RIGHT (Jac list comprehension):

```jac
{[<Item key={item.id} item={item} /> for item in items]}
```

## Server-Client Communication Gotchas

### 34. Importing server code into client uses `sv import`

To call server-side walkers or functions from client code, you must use `sv import`. Regular `import` will not work across the server-client boundary.

WRONG (regular import):

```
import from ..main { get_tasks }
```

RIGHT:

```jac
sv import from ...main { get_tasks, add_task }
```

The `sv` prefix tells the compiler this is a server-side import to be called over HTTP.

### 35. Calling walkers from client uses `root spawn`, NOT `await func()`

Server walkers are called by spawning them on `root`. The result contains `.reports` with the walker's reported values.

WRONG (function-call style):

```
cl {
    async can with entry {
        tasks = await get_tasks();
    }
}
```

RIGHT:

```jac
sv import from ...main { get_tasks }

cl {
    def:pub TaskList() -> JsxElement {
        has tasks: list = [];

        async can with entry {
            result = root spawn get_tasks();
            if result.reports and result.reports.length > 0 {
                tasks = result.reports[0];
            }
        }

        return <ul>
            {[<li key={task.id}>{task.title}</li> for task in tasks]}
        </ul>;
    }
}
```

Walker `has` fields become the request body:

```jac
sv import from ...main { add_task }

cl {
    async def handle_add() -> None {
        result = root spawn add_task(title="New task");
        if result.reports and result.reports.length > 0 {
            new_task = result.reports[0];
            tasks = tasks + [new_task];
        }
    }
}
```

### 36. Walker reports are in `result.reports[0]`, NOT `result.data`

The response from `root spawn` has a `.reports` array containing values from the walker's `report` statements. The first report is at index `[0]`.

WRONG:

```
result = root spawn get_tasks();
tasks = result.data;          # WRONG: no .data property
tasks = result;               # WRONG: result is a response object, not the data
tasks = result.reports;       # PARTIAL: this is the full array, usually you want [0]
```

RIGHT:

```jac
result = root spawn get_tasks();
if result.reports and result.reports.length > 0 {
    tasks = result.reports[0];
}
```

## API Endpoint & Auth Gotchas

### 37. Public endpoints use `walker:pub` or `def:pub`, private use `:priv`

To expose a walker or function as an HTTP endpoint, use the `:pub` (public, no auth) or `:priv` (private, JWT auth required) access modifier. Without these modifiers, walkers and functions are internal only.

WRONG (no access modifier -- not exposed as endpoint):

```
walker get_tasks {
    can fetch with Root entry {
        report [-->][?:Task];
    }
}
```

RIGHT (public endpoint, no auth required):

```jac
walker:pub get_tasks {
    can fetch with Root entry {
        report [-->][?:Task];
    }
}
```

RIGHT (private endpoint, JWT auth required, per-user data isolation):

```jac
walker:priv create_task {
    has title: str;

    can create with Root entry {
        new_task = here ++> Task(title=self.title);
        report new_task;
    }
}
```

The same applies to functions:

```jac
def:pub get_status() -> dict {
    return {"status": "ok"};
}

def:priv get_user_data() -> dict {
    # Each user sees their own data automatically
    return {"user": "data"};
}
```

### 38. Walker `has` fields = request body, `report` = response body

When a walker is exposed as an endpoint, its `has` fields automatically become the HTTP request body, and its `report` values become the response body. Do NOT try to manually parse request/response.

WRONG (manual request handling):

```
walker:pub create_task {
    can create with Root entry {
        body = parse_request_body();  # WRONG: not how Jac works
        title = body["title"];
    }
}
```

RIGHT:

```jac
walker:pub create_task {
    has title: str;  # Automatically populated from request body

    can create with Root entry {
        new_task = here ++> Task(title=self.title);
        report new_task;  # Automatically becomes response body
    }
}
```

### 39. `:priv` gives per-user data isolation automatically

With `walker:priv` or `def:priv`, each authenticated user gets their own isolated graph `root`. You do NOT need to filter data by user ID -- the runtime handles isolation.

WRONG (manual user filtering):

```
walker:priv get_my_tasks {
    has user_id: str;

    can fetch with Root entry {
        all_tasks = [-->][?:Task];
        report [t for t in all_tasks if t.owner == self.user_id];  # Unnecessary
    }
}
```

RIGHT (isolation is automatic):

```jac
walker:priv get_my_tasks {
    can fetch with Root entry {
        report [-->][?:Task];  # Only returns THIS user's tasks automatically
    }
}
```

### 40. Auth functions are imported from `@jac/runtime`

Do NOT try to implement login/signup manually. Jac provides built-in auth functions.

WRONG (manual auth):

```
cl {
    async def login(user: str, pass: str) -> None {
        response = await fetch("/api/login", ...);  # WRONG
    }
}
```

RIGHT:

```jac
cl import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, useNavigate }

cl {
    def:pub LoginPage() -> JsxElement {
        has username: str = "";
        has password: str = "";
        has error: str = "";

        navigate = useNavigate();

        async def handleLogin() -> None {
            success = await jacLogin(username, password);
            if success {
                navigate("/");
            } else {
                error = "Invalid credentials";
            }
        }

        return <form>
            <input
                value={username}
                onChange={lambda e: any -> None { username = e.target.value; }}
                placeholder="Username"
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { password = e.target.value; }}
                placeholder="Password"
            />
            <button type="button" onClick={lambda -> None { handleLogin(); }}>
                Login
            </button>
            {error and <p style={{"color": "red"}}>{error}</p>}
        </form>;
    }
}
```

### 41. Routing uses file-based conventions or `@jac/runtime` components

WRONG (React Router npm import):

```
import from "react-router-dom" { BrowserRouter, Routes, Route }
```

RIGHT (file-based routing -- recommended):

```
pages/
├── layout.jac            # Root layout wrapping all pages
├── index.jac             # / (home)
├── about.jac             # /about
├── users/
│   └── [id].jac          # /users/:id (dynamic)
├── (public)/             # Route group (no auth)
│   └── login.jac         # /login
└── (auth)/               # Route group (auth required)
    └── dashboard.jac     # /dashboard
```

Each page file exports a `page` function:

```jac
# pages/about.jac
cl {
    def:pub page() -> JsxElement {
        return <div>
            <h1>About Us</h1>
        </div>;
    }
}
```

RIGHT (manual routing from `@jac/runtime`):

```jac
cl import from "@jac/runtime" { Router, Routes, Route, Link, useNavigate, useParams }
```

### 42. Dynamic route parameters use `useParams()` from `@jac/runtime`

WRONG (accessing params directly):

```
# pages/users/[id].jac
cl {
    def:pub page(id: str) -> JsxElement {  # WRONG: params are not function args
        return <h1>User {id}</h1>;
    }
}
```

RIGHT:

```jac
# pages/users/[id].jac
cl import from "@jac/runtime" { useParams }

cl {
    def:pub page() -> JsxElement {
        params = useParams();
        userId = params.id;

        return <h1>User {userId}</h1>;
    }
}
```

### 43. Layout files use `Outlet` for child page rendering

WRONG (trying to pass children manually):

```
cl {
    def:pub layout(props: dict) -> JsxElement {
        return <div>
            <nav>...</nav>
            {props.children}
        </div>;
    }
}
```

RIGHT:

```jac
cl import from "@jac/runtime" { Outlet }

cl {
    def:pub layout() -> JsxElement {
        return <div>
            <nav>...</nav>
            <Outlet />
        </div>;
    }
}
```
