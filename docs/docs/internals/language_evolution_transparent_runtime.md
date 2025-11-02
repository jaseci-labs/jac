# Jac Language Evolution: Transparent Runtime Plumbing

## Executive Summary

This document proposes language-level features that enable Jac to abstract away rendering mode concerns (CSR/SSR/SPA/MPA) and runtime plumbing from user programs. The goal is to allow developers to write natural, declarative code while the compiler and runtime handle the complexity of state management, routing, and server-client coordination.

**Current State**: Users explicitly import and manage `createRouter`, `Route`, `Link`, `navigate`, `createState`, etc.

**Proposed State**: These primitives become implicit language features, automatically emitted by the compiler/runtime based on code patterns and build configuration.

## Table of Contents

1. [Current Plumbing Analysis](#current-plumbing-analysis)
2. [Vision: Natural Jac Code](#vision-natural-jac-code)
3. [Language Evolution Proposals](#language-evolution-proposals)
4. [Compiler/Runtime Architecture](#compilerruntime-architecture)
5. [Build-Time Configuration](#build-time-configuration)
6. [Migration Path](#migration-path)
7. [Implementation Phases](#implementation-phases)

---

## Current Plumbing Analysis

### What Users Must Explicitly Manage Today

#### 1. **Routing Plumbing**
```jac
// Current: Explicit imports and manual router setup
cl import from jac:client_runtime {
    createRouter,
    Route,
    Link,
    navigate,
}

cl def App() {
    login_route = {"path": "/login", "component": lambda -> any { return LoginForm(); }, "guard": None};
    home_route = {"path": "/home", "component": lambda -> any { return HomeView(); }, "guard": jacIsLoggedIn};

    routes = [login_route, home_route];
    router = createRouter(routes, "/login");

    return <div>
        {router.render()}
    </div>;
}

// Navigation requires explicit Link components or navigate() calls
<Link href="/home">Home</Link>
navigate("/profile");
```

#### 2. **State Management Plumbing**
```jac
// Current: Explicit state creation and management
cl import from jac:client_runtime { createState, createSignal }

cl def TodoList() {
    [state, setState] = createState({"todos": [], "filter": "all"});

    def addTodo(text: str) {
        todos = state().todos;
        todos.push({"text": text, "done": False});
        setState({"todos": todos});  // Manual state updates
    }

    return <div>{[<li>{todo.text}</li> for todo in state().todos]}</div>;
}
```

#### 3. **Authentication Plumbing**
```jac
// Current: Explicit auth function imports and calls
cl import from jac:client_runtime { jacLogin, jacLogout, jacSignup, jacIsLoggedIn }

cl async def handle_login(event: any) {
    event.preventDefault();
    username = document.getElementById("username").value;
    password = document.getElementById("password").value;
    success = await jacLogin(username, password);
    if success {
        navigate("/home");
    }
}
```

#### 4. **Server Communication Plumbing**
```jac
// Current: Users must understand walker spawning vs function calls
cl async def like_tweet_action(tweet_id: str) {
    try {
        result = await like_tweet(tweet_id);  // Compiler transforms to __jacCallFunction
        window.location.reload();  // Manual refresh
    } except Exception as e {
        print("Error liking tweet:", e);
    }
}
```

### Why This Is Problematic

1. **Cognitive Overhead**: Users must understand the distinction between CSR/SSR, client/server boundaries, and routing mechanisms
2. **Boilerplate**: Repetitive imports, state setup, and router configuration in every app
3. **Portability**: Switching from SPA to MPA or CSR to SSR requires significant code changes
4. **Abstraction Leakage**: Implementation details (hash routing, signal-based reactivity) exposed to users
5. **Learning Curve**: New users must learn runtime APIs before writing their first app

---

## Vision: Natural Jac Code

### What Users Should Write

#### 1. **Natural Routing with Page Functions**

```jac
// Vision: Functions become routes automatically
// No imports, no router setup, no explicit routing config

page def Home() {
    return <div>
        <h1>Welcome Home</h1>
        <a href="/profile">Go to Profile</a>  // Just use <a> tags naturally
    </div>;
}

page def Profile() {
    return <div>
        <h1>Your Profile</h1>
    </div>;
}

// Compiler automatically:
// 1. Generates routes from 'page' functions
// 2. Handles navigation (SPA or MPA depending on build config)
// 3. Injects router without user code changes
```

#### 2. **Reactive Variables Without Explicit State Management**

```jac
// Vision: Variables are automatically reactive
page def TodoList() {
    var todos = [];  // Automatically reactive
    var inputValue = "";

    def addTodo() {
        todos.append({"text": inputValue, "done": False});
        inputValue = "";  // Auto-updates UI
    }

    return <div>
        <input value={inputValue} oninput={e => inputValue = e.target.value} />
        <button onclick={addTodo}>Add</button>
        <ul>
            {[<li>{todo.text}</li> for todo in todos]}
        </ul>
    </div>;
}

// Compiler automatically:
// 1. Detects 'var' keyword in page/component functions
// 2. Wraps in createSignal/createState under the hood
// 3. Generates reactive getters/setters
```

#### 3. **Declarative Route Guards**

```jac
// Vision: Guards are declarative attributes
page(auth=required) def Dashboard() {
    return <div>Welcome to your dashboard</div>;
}

page(auth=guest) def Login() {
    return <form>...</form>;
}

// Compiler automatically:
// 1. Generates guard functions
// 2. Handles redirects
// 3. No manual jacIsLoggedIn checks
```

#### 4. **Transparent Server Calls**

```jac
// Server-side walker
walker GetUserProfile {
    has user_id: str;

    can fetch with `root entry {
        user = [-->(`?User(id==self.user_id))][0];
        report user;
    }
}

// Client-side page
page def Profile() {
    // Vision: Just call the walker naturally
    user = await GetUserProfile(user_id="123");

    return <div>
        <h1>{user.name}</h1>
    </div>;
}

// Compiler automatically:
// 1. Detects cross-boundary call
// 2. Generates __jacSpawn or __jacCallFunction
// 3. Handles async/await transparently
```

#### 5. **Form Handling Without Event Plumbing**

```jac
// Vision: Forms submit to walkers naturally
walker HandleLogin {
    has username: str;
    has password: str;

    can process with `root entry {
        // Authenticate user
        if authenticate(self.username, self.password) {
            report {"success": True};
        } else {
            report {"success": False, "error": "Invalid credentials"};
        }
    }
}

page def Login() {
    // Form automatically binds to walker
    return <form action={HandleLogin} method="post">
        <input name="username" type="text" />
        <input name="password" type="password" />
        <button type="submit">Login</button>
    </form>;
}

// Compiler automatically:
// 1. Generates form handler
// 2. Serializes form data
// 3. Spawns walker with form fields
// 4. Handles response (redirect or error display)
```

---

## Language Evolution Proposals

### 1. New Keywords and Modifiers

#### `page` Keyword
Declares a function as a routable page. Replaces manual `Route()` configuration.

```jac
page def Home() { ... }
page(path="/custom-path") def CustomPage() { ... }
page(auth=required) def Dashboard() { ... }
page(auth=guest) def Login() { ... }
page(layout=AdminLayout) def AdminPanel() { ... }
```

**Compiler Behavior**:
- Extracts function name as default route path (`/Home` → `/home`)
- Allows explicit `path` parameter to override
- Generates route guards from `auth` parameter
- Wraps in layout component if specified
- Collects all `page` functions into a route manifest at compile time

#### `component` Keyword
Declares reusable UI components (optional, for clarity).

```jac
component def Button(label: str, onclick: any) {
    return <button onclick={onclick}>{label}</button>;
}

// Equivalent to just 'cl def', but more semantic
```

#### `var` Keyword for Reactive Variables
Automatically reactive variables within `page` or `component` functions.

```jac
page def Counter() {
    var count = 0;  // Automatically becomes createSignal(0)

    return <button onclick={() => count += 1}>
        Clicked {count} times
    </button>;
}
```

**Compiler Behavior**:
- Detects `var` declarations inside `page`/`component` functions
- Transforms to `createSignal` for primitives
- Transforms to `createState` for objects/arrays
- Rewrites assignments (`count += 1`) to setter calls (`setCount(count() + 1)`)
- Rewrites reads to getter calls where reactive tracking needed

#### `server` Keyword (Explicit Server-Only Code)
Marks code that should never be sent to client (opposite of `cl`).

```jac
server def get_api_key() -> str {
    return os.getenv("SECRET_API_KEY");
}

// Compiler ensures this NEVER appears in client bundle
// Client calls generate RPC automatically
```

### 2. Enhanced JSX Attributes

#### `href` Attribute Intelligence
Compiler detects internal vs external links automatically.

```jac
// Internal navigation (SPA transition)
<a href="/profile">Profile</a>

// External navigation (full page load)
<a href="https://example.com">External</a>

// Explicit control
<a href="/about" data-nav="full">Force full reload</a>
<a href="https://example.com" data-nav="spa">Treat as SPA route</a>
```

**Compiler Behavior**:
- Parses `href` values at compile time
- Internal paths (`/...`) → wraps in `Link` component or injects SPA navigation
- External URLs (`http://...`) → leaves as standard `<a>` tag
- Respects `data-nav` override if present

#### `action` Attribute for Forms
Forms can directly bind to walkers or server functions.

```jac
walker SubmitContactForm {
    has name: str;
    has email: str;
    has message: str;

    can process with `root entry {
        // Save to database
        report {"success": True};
    }
}

page def Contact() {
    return <form action={SubmitContactForm}>
        <input name="name" />
        <input name="email" />
        <textarea name="message" />
        <button type="submit">Send</button>
    </form>;
}
```

**Compiler Behavior**:
- Generates `onsubmit` handler
- Serializes `FormData` to walker fields
- Spawns walker asynchronously
- Handles response (success → redirect, error → display message)

### 3. Route Guards as Decorators

```jac
@auth(required=True)
page def Dashboard() {
    return <div>Protected content</div>;
}

@auth(required=False, redirect="/dashboard")
page def Login() {
    return <form>...</form>;
}

@role("admin")
page def AdminPanel() {
    return <div>Admin only</div>;
}
```

**Compiler Behavior**:
- Parses decorators and generates guard functions
- `@auth(required=True)` → `guard=jacIsLoggedIn`
- `@auth(required=False)` → `guard=lambda: not jacIsLoggedIn()`
- `@role("admin")` → `guard=lambda: jacHasRole("admin")`
- Injects redirect logic based on `redirect` parameter

### 4. Automatic Layouts

```jac
// Define layout component
layout def MainLayout(children: any) {
    return <div>
        <nav>
            <a href="/">Home</a>
            <a href="/about">About</a>
        </nav>
        <main>{children}</main>
        <footer>© 2024</footer>
    </div>;
}

// Apply to multiple pages
@layout(MainLayout)
page def Home() { return <h1>Home</h1>; }

@layout(MainLayout)
page def About() { return <h1>About</h1>; }

// Or set default layout for all pages in module
@default_layout(MainLayout)
module;
```

**Compiler Behavior**:
- Wraps page component in layout component
- Passes page result as `children` prop
- Allows per-page layout override

### 5. Data Loading Hooks

```jac
walker FetchTweets {
    can load with `root entry {
        tweets = [-->(`?Tweet)];
        report [tweet.serialize() for tweet in tweets];
    }
}

page def Feed() {
    // Vision: Automatic data loading
    var tweets = await load FetchTweets();

    return <div>
        {[<TweetCard tweet={tweet} /> for tweet in tweets]}
    </div>;
}
```

**Compiler Behavior**:
- Detects `load` keyword before walker name
- For SSR: Executes walker during server render, injects data into HTML
- For CSR: Executes walker on client mount, shows loading state
- Handles loading/error states automatically
- Re-executes on route params change

### 6. Computed Properties

```jac
page def TodoList() {
    var todos = [
        {"text": "Learn Jac", "done": True},
        {"text": "Build app", "done": False}
    ];

    // Automatically reactive computed value
    computed var completedCount = todos.filter(t => t.done).length;
    computed var remainingCount = todos.length - completedCount;

    return <div>
        <p>Completed: {completedCount}</p>
        <p>Remaining: {remainingCount}</p>
    </div>;
}
```

**Compiler Behavior**:
- Transforms `computed var` to `createSignal` with derived value
- Wraps expression in `createEffect` to update when dependencies change
- Automatically tracks reactive dependencies

---

## Compiler/Runtime Architecture

### Compilation Phases

#### Phase 1: Source Analysis
```
User Source (.jac)
    ↓
Parse Tree (AST)
    ↓
Semantic Analysis
    ├─ Detect 'page' functions → Add to route manifest
    ├─ Detect 'var' in pages → Mark for reactive transformation
    ├─ Detect 'server' functions → Mark for server-only
    ├─ Detect cross-boundary calls → Mark for RPC generation
    └─ Detect decorators → Extract metadata
```

#### Phase 2: Code Generation (Multi-Target)
```
Enhanced AST
    ├─ Server Target (Python)
    │   ├─ All server-side code
    │   ├─ Walker definitions
    │   ├─ Node/edge definitions
    │   └─ RPC endpoints for server functions
    │
    └─ Client Target (JavaScript)
        ├─ Page functions (with reactive transforms)
        ├─ Component functions (with reactive transforms)
        ├─ Auto-generated router setup
        ├─ Auto-generated state management
        └─ Auto-generated RPC calls
```

#### Phase 3: Runtime Injection
```
Client Bundle
    ├─ Core Runtime (always included)
    │   ├─ JSX renderer
    │   ├─ Reactive system (signals/effects)
    │   ├─ Router (if pages detected)
    │   ├─ Auth helpers (if auth decorators detected)
    │   └─ RPC client (if server calls detected)
    │
    ├─ Generated Code
    │   ├─ Route manifest
    │   ├─ Reactive variable setup
    │   └─ RPC call stubs
    │
    └─ User Code (transformed)
        ├─ Page components
        └─ UI components
```

### Reactive Variable Transformation

**User Code**:
```jac
page def Counter() {
    var count = 0;
    return <button onclick={() => count += 1}>{count}</button>;
}
```

**Compiler Output**:
```javascript
function Counter() {
    const [__count_getter, __count_setter] = createSignal(0);
    const count = () => __count_getter();

    return __jacJsx("button", {
        onclick: () => __count_setter(__count_getter() + 1)
    }, [count()]);
}
```

**Optimized Output (with smarter tracking)**:
```javascript
function Counter() {
    const [count, setCount] = createSignal(0);

    return __jacJsx("button", {
        onclick: () => setCount(count() + 1)
    }, [count()]);
}
```

### Route Manifest Generation

**User Code**:
```jac
page def Home() { return <h1>Home</h1>; }
page(auth=required) def Dashboard() { return <h1>Dashboard</h1>; }
page(path="/custom") def Special() { return <h1>Special</h1>; }
```

**Generated Route Manifest**:
```javascript
const __jacRouteManifest = [
    {
        path: "/home",
        component: Home,
        guard: null,
        meta: {}
    },
    {
        path: "/dashboard",
        component: Dashboard,
        guard: jacIsLoggedIn,
        meta: { auth: "required" }
    },
    {
        path: "/custom",
        component: Special,
        guard: null,
        meta: {}
    }
];

const __jacRouter = createRouter(__jacRouteManifest, "/home");
```

### Automatic RPC Generation

**User Code**:
```jac
server def getSecretData() -> dict {
    return {"secret": os.getenv("API_KEY")};
}

page def Dashboard() {
    var data = await getSecretData();
    return <div>{data.secret}</div>;
}
```

**Generated Server Code (Python)**:
```python
def getSecretData() -> dict:
    return {"secret": os.getenv("API_KEY")}

# Auto-registered RPC endpoint at /function/getSecretData
```

**Generated Client Code (JavaScript)**:
```javascript
async function getSecretData() {
    return await __jacCallFunction("getSecretData", []);
}

function Dashboard() {
    const [__data_getter, __data_setter] = createSignal(null);

    createEffect(async () => {
        const result = await getSecretData();
        __data_setter(result);
    });

    const data = () => __data_getter();

    return __jacJsx("div", {}, [data()?.secret]);
}
```

---

## Build-Time Configuration

### Rendering Mode Selection

Users should be able to switch rendering modes **without changing code**.

#### Configuration File: `jac.config.toml`
```toml
[build]
target = "web"
mode = "spa"  # Options: spa, mpa, ssr, ssg

[routing]
strategy = "hash"  # Options: hash, history, file
base_path = "/"
trailing_slash = "always"

[optimization]
bundle_splitting = true
lazy_routes = true
prerender_routes = ["/", "/about"]

[dev]
hot_reload = true
source_maps = true
```

#### Rendering Modes

| Mode | Description | Generated Output | Use Case |
|------|-------------|------------------|----------|
| **SPA** (Single Page App) | All routing on client, single HTML file | `index.html` + `client.js` | Interactive apps, dashboards |
| **MPA** (Multi Page App) | Each route is separate HTML file | `home.html`, `about.html`, ... | SEO-focused, simple sites |
| **SSR** (Server-Side Rendering) | HTML rendered on server per request | Server endpoint for each route | Dynamic content, SEO + interactivity |
| **SSG** (Static Site Generation) | Pre-render at build time | Static HTML files | Blogs, documentation |

#### Same Code, Different Builds

**User Code** (unchanged):
```jac
page def Home() {
    var count = 0;
    return <div>
        <h1>Home</h1>
        <button onclick={() => count += 1}>Clicked {count}</button>
    </div>;
}

page def About() {
    return <div><h1>About</h1></div>;
}
```

**SPA Build** (`jac build --mode spa`):
```
dist/
  index.html        # Shell with <div id="__jac_root"></div>
  client.js         # Full bundle with router
  # URL: /#/home, /#/about (hash routing)
```

**MPA Build** (`jac build --mode mpa`):
```
dist/
  home.html         # Standalone page with Home component
  about.html        # Standalone page with About component
  shared.js         # Common code (optional)
  # URL: /home.html, /about.html (separate files)
```

**SSR Build** (`jac build --mode ssr`):
```
dist/
  server.py         # Python server with render endpoints
  client.js         # Hydration bundle
  # URL: /home, /about (server renders HTML on each request)
```

**SSG Build** (`jac build --mode ssg`):
```
dist/
  home/index.html   # Pre-rendered with initial state
  about/index.html  # Pre-rendered
  client.js         # Hydration for interactivity
  # URL: /home/, /about/ (static files with hydration)
```

### Build Command Examples

```bash
# Development (SPA with hot reload)
jac serve app.jac

# Production SPA build
jac build app.jac --mode spa --output dist/

# Production SSR build
jac build app.jac --mode ssr --output dist/

# Static site generation
jac build app.jac --mode ssg --prerender all --output dist/

# MPA with specific routes
jac build app.jac --mode mpa --routes home,about,contact --output dist/
```

---

## Migration Path

### Backward Compatibility

Old code with explicit runtime imports should continue to work:

```jac
// Old style (still supported)
cl import from jac:client_runtime { createRouter, Route }

cl def App() {
    routes = [Route("/", HomePage)];
    router = createRouter(routes);
    return router.render();
}

// New style (preferred)
page def HomePage() {
    return <h1>Home</h1>;
}
```

**Migration Strategy**:
1. **Phase 1**: Introduce new keywords (`page`, `var`, `component`) alongside old APIs
2. **Phase 2**: Provide `jac migrate` tool to auto-convert old code
3. **Phase 3**: Deprecation warnings for manual runtime imports
4. **Phase 4**: Remove old APIs in major version bump (2.0)

### Auto-Migration Tool

```bash
# Analyze migration opportunities
jac migrate analyze app.jac

# Preview changes
jac migrate preview app.jac

# Apply automatic migration
jac migrate apply app.jac

# Output:
# ✓ Converted 3 'cl def' to 'page def'
# ✓ Removed manual router setup
# ✓ Converted 5 createState calls to 'var'
# ✓ Converted 2 navigate() calls to <a href>
```

**Migration Rules**:
- `cl def` functions returning JSX → `page def`
- `createState({...})` → `var ... = {...}`
- `createSignal(value)` → `var ... = value`
- Manual router setup → removed (auto-generated)
- `Link` components → `<a href>` tags
- `navigate()` calls → `window.location.href` or left as-is

---

## Implementation Phases

### Phase 1: Foundation (3-4 months)
**Goal**: Introduce `page` keyword and auto-routing

- [ ] Parser support for `page` keyword
- [ ] Route manifest generation from `page` functions
- [ ] Auto-inject router in client bundle
- [ ] Smart `<a href>` handling (internal vs external)
- [ ] Build config file support (`jac.config.toml`)
- [ ] Backward compatibility with manual routing

**Deliverable**: Users can write `page def Home()` and get automatic routing

### Phase 2: Reactive Variables (2-3 months)
**Goal**: Introduce `var` keyword for automatic reactivity

- [ ] Parser support for `var` keyword
- [ ] Detect `var` in `page`/`component` functions
- [ ] Transform to `createSignal`/`createState` automatically
- [ ] Rewrite assignments to setter calls
- [ ] Rewrite reads to getter calls
- [ ] Handle `computed var` for derived state

**Deliverable**: Users can write `var count = 0` and get reactivity

### Phase 3: Declarative Guards (1-2 months)
**Goal**: Route protection without manual code

- [ ] Parser support for `page(auth=...)` syntax
- [ ] Support `@auth()` decorator syntax
- [ ] Generate guard functions automatically
- [ ] Built-in guards: `required`, `guest`, `role(...)`
- [ ] Custom guard support

**Deliverable**: Users can write `page(auth=required) def Dashboard()`

### Phase 4: Server/Client Transparency (3-4 months)
**Goal**: Seamless RPC without manual spawning

- [ ] `server` keyword for server-only functions
- [ ] Auto-detect cross-boundary calls
- [ ] Generate RPC stubs automatically
- [ ] Form `action={Walker}` binding
- [ ] Data loading with `await load Walker()`
- [ ] Optimistic updates and caching

**Deliverable**: Users can call server functions naturally from client code

### Phase 5: Multi-Mode Builds (4-5 months)
**Goal**: Same code, multiple rendering modes

- [ ] SSR renderer (server-side React-style rendering)
- [ ] SSG pre-rendering at build time
- [ ] MPA multi-file generation
- [ ] Hydration for SSR/SSG
- [ ] Route-based code splitting
- [ ] Lazy loading for large apps

**Deliverable**: `jac build --mode ssr` generates SSR app from same code

### Phase 6: Developer Experience (2-3 months)
**Goal**: Tooling and migration support

- [ ] `jac migrate` tool for auto-conversion
- [ ] Enhanced error messages for common mistakes
- [ ] Development mode with better debugging
- [ ] Build analyzer for bundle optimization
- [ ] Documentation and examples

**Deliverable**: Smooth migration path and great DX

---

## Examples: Before and After

### Example 1: Simple Todo App

#### Before (Current Explicit Style)
```jac
cl import from jac:client_runtime {
    createState,
    createRouter,
    Route,
    Link,
    navigate,
}

cl obj Todo {
    has text: str;
    has done: bool = False;
}

cl def TodoApp() {
    [state, setState] = createState({
        "todos": [],
        "inputValue": ""
    });

    def addTodo() {
        todos = state().get("todos", []);
        input_val = state().get("inputValue", "");
        if input_val.strip() {
            todos.append({"text": input_val, "done": False});
            setState({"todos": todos, "inputValue": ""});
        }
    }

    def toggleTodo(index: int) {
        todos = state().get("todos", []);
        todos[index]["done"] = not todos[index]["done"];
        setState({"todos": todos});
    }

    return <div class="todo-app">
        <h1>My Todos</h1>
        <div>
            <input
                type="text"
                value={state().get("inputValue", "")}
                oninput={lambda e: setState({"inputValue": e.target.value})}
                placeholder="What needs to be done?"
            />
            <button onclick={addTodo}>Add</button>
        </div>
        <ul>
            {[
                <li
                    style={{"textDecoration": "line-through" if todo["done"] else "none"}}
                    onclick={lambda idx=i: toggleTodo(idx)}
                >
                    {todo["text"]}
                </li>
                for i, todo in enumerate(state().get("todos", []))
            ]}
        </ul>
    </div>;
}

cl def App() {
    routes = [
        {"path": "/", "component": TodoApp, "guard": None}
    ];
    router = createRouter(routes, "/");
    return router.render();
}
```

#### After (Proposed Natural Style)
```jac
obj Todo {
    has text: str;
    has done: bool = False;
}

page def TodoApp() {
    var todos = [];
    var inputValue = "";

    def addTodo() {
        if inputValue.strip() {
            todos.append(Todo(text=inputValue, done=False));
            inputValue = "";
        }
    }

    def toggleTodo(index: int) {
        todos[index].done = not todos[index].done;
    }

    return <div class="todo-app">
        <h1>My Todos</h1>
        <div>
            <input
                type="text"
                value={inputValue}
                oninput={e => inputValue = e.target.value}
                placeholder="What needs to be done?"
            />
            <button onclick={addTodo}>Add</button>
        </div>
        <ul>
            {[
                <li
                    style={{"textDecoration": "line-through" if todo.done else "none"}}
                    onclick={() => toggleTodo(i)}
                >
                    {todo.text}
                </li>
                for i, todo in enumerate(todos)
            ]}
        </ul>
    </div>;
}
```

**Key Improvements**:
- ❌ No imports needed
- ❌ No explicit state management
- ❌ No router setup
- ✅ Natural variable declarations
- ✅ Direct property access
- ✅ Automatic routing from `page` keyword
- **45% less code**

### Example 2: Multi-Page App with Auth

#### Before (Current Explicit Style)
```jac
cl import from jac:client_runtime {
    createRouter,
    Route,
    Link,
    navigate,
    jacLogin,
    jacLogout,
    jacIsLoggedIn,
}

cl async def handle_login(event: any) {
    event.preventDefault();
    username = document.getElementById("username").value;
    password = document.getElementById("password").value;
    success = await jacLogin(username, password);
    if success {
        navigate("/dashboard");
    } else {
        alert("Login failed");
    }
}

cl def LoginPage() {
    if jacIsLoggedIn() {
        navigate("/dashboard");
        return <div></div>;
    }

    return <div class="login">
        <h1>Login</h1>
        <form onsubmit={handle_login}>
            <input id="username" type="text" placeholder="Username" />
            <input id="password" type="password" placeholder="Password" />
            <button type="submit">Login</button>
        </form>
        <Link href="/signup">Don't have an account?</Link>
    </div>;
}

cl def Dashboard() {
    if not jacIsLoggedIn() {
        navigate("/login");
        return <div></div>;
    }

    return <div class="dashboard">
        <h1>Dashboard</h1>
        <p>Welcome back!</p>
        <button onclick={lambda: (jacLogout(), navigate("/login"))}>Logout</button>
    </div>;
}

cl def App() {
    routes = [
        {"path": "/login", "component": LoginPage, "guard": None},
        {"path": "/dashboard", "component": Dashboard, "guard": jacIsLoggedIn}
    ];
    router = createRouter(routes, "/login");
    return router.render();
}
```

#### After (Proposed Natural Style)
```jac
walker Authenticate {
    has username: str;
    has password: str;

    can process with `root entry {
        if authenticate(self.username, self.password) {
            report {"success": True};
        } else {
            report {"success": False, "error": "Invalid credentials"};
        }
    }
}

page(auth=guest, redirect="/dashboard") def Login() {
    return <div class="login">
        <h1>Login</h1>
        <form action={Authenticate} success="/dashboard">
            <input name="username" type="text" placeholder="Username" />
            <input name="password" type="password" placeholder="Password" />
            <button type="submit">Login</button>
        </form>
        <a href="/signup">Don't have an account?</a>
    </div>;
}

page(auth=required) def Dashboard() {
    return <div class="dashboard">
        <h1>Dashboard</h1>
        <p>Welcome back!</p>
        <button onclick={logout}>Logout</button>
    </div>;
}

// Built-in logout function, no import needed
server def logout() {
    jacLogout();
    navigate("/login");
}
```

**Key Improvements**:
- ❌ No manual auth checks
- ❌ No manual redirects
- ❌ No form event handling boilerplate
- ✅ Declarative route guards: `page(auth=required)`
- ✅ Form binding to walker: `action={Authenticate}`
- ✅ Standard `<a>` tags instead of `<Link>`
- **60% less code**

### Example 3: Data Fetching

#### Before (Current Explicit Style)
```jac
cl import from jac:client_runtime { createState }

walker GetTweets {
    can load with `root entry {
        tweets = [-->(`?Tweet)];
        report [{"id": jid(t), "content": t.content} for t in tweets];
    }
}

cl def Feed() {
    [state, setState] = createState({
        "tweets": [],
        "loading": True
    });

    async def loadTweets() {
        setState({"loading": True});
        try {
            result = await GetTweets();  // __jacSpawn generated
            setState({"tweets": result, "loading": False});
        } except Exception as e {
            print("Error:", e);
            setState({"loading": False});
        }
    }

    // Manual effect to load on mount
    createEffect(lambda: loadTweets());

    if state().get("loading") {
        return <div>Loading...</div>;
    }

    return <div>
        {[<div>{tweet["content"]}</div> for tweet in state().get("tweets", [])]}
    </div>;
}
```

#### After (Proposed Natural Style)
```jac
walker GetTweets {
    can load with `root entry {
        tweets = [-->(`?Tweet)];
        report [{"id": jid(t), "content": t.content} for t in tweets];
    }
}

page def Feed() {
    var tweets = await load GetTweets();

    return <div>
        {[<div>{tweet.content}</div> for tweet in tweets]}
    </div>;
}
```

**Key Improvements**:
- ❌ No manual loading state
- ❌ No try/catch boilerplate
- ❌ No effect hooks
- ✅ Direct data loading: `await load Walker()`
- ✅ Automatic loading UI
- ✅ Automatic error handling
- **75% less code**

---

## Conclusion

This proposal outlines a path toward making Jac a truly unified full-stack language where:

1. **Developers write natural code** without worrying about CSR/SSR/SPA/MPA distinctions
2. **The compiler infers intent** from code patterns and generates optimal runtime plumbing
3. **Build configuration determines output** (same code compiles to SPA, MPA, SSR, or SSG)
4. **Boilerplate is eliminated** through language-level features like `page`, `var`, and automatic routing
5. **Server-client boundaries are transparent** with automatic RPC generation

### Next Steps

1. **Community Feedback**: Gather input on proposed syntax and features
2. **Prototype Phase 1**: Implement `page` keyword and auto-routing
3. **Benchmarking**: Compare bundle sizes and performance vs manual approach
4. **Documentation**: Create migration guides and best practices
5. **Iterative Rollout**: Release features incrementally with backward compatibility

### Design Principles

- **Convention over Configuration**: Sensible defaults, but allow overrides
- **Progressive Enhancement**: Start simple, add complexity only when needed
- **Zero-Cost Abstractions**: Generated code should be as efficient as hand-written
- **Gradual Migration**: Old code continues to work during transition
- **Build-Time Optimization**: Move complexity from runtime to compile-time

This evolution would position Jac as a leader in developer experience for full-stack web development, rivaling frameworks like Next.js, SvelteKit, and Remix, while maintaining the unique graph-native and walker-based paradigm.
