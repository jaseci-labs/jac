# Jac & Jaseci - Knowledge Map

## What is Jac?

Jac is a full-stack language that compiles to Python bytecode (server), JavaScript (client), and native
binaries - from a single file. It extends Python with 3 paradigms:

  1. Codespaces (sv/cl/na) - target where code runs: server, browser, or native binary
  2. Object-Spatial Programming (OSP) - graph-native data model with built-in multi-user persistence
  3. Meaning-Typed Programming (MTP) - AI functions via `by llm` with compiler-extracted semantics

## What is Jaseci?

The runtime stack: jaclang (compiler + runtime + built-in React client framework) and jac-scale
(deployment). They handle DB schema, API routing, HTTP, auth, and frontend generation automatically.

---

## Resource Index

Each section lists the guide URIs to fetch with get_resource. Every guide ships inside the `jac`
binary, so these always resolve. Fetch jac://guide/pitfalls and jac://guide/patterns before writing
any code; fetch the topic guides as needed for the task in front of you.

### [A] Language Syntax - Jac is NOT Python

Semicolons on ALL statements. Braces {} for blocks, not indentation. `has` for instance fields
(not self.x). `obj` preferred over `class`. `def` for regular methods, `can` ONLY for
event-driven abilities. `import from X { Y }` and `import X;`. `with entry {}` as main block.
`glob` for module-level variables. `self` is implicit in method signatures.

  jac://guide/pitfalls              WRONG vs RIGHT for common AI mistakes
  jac://guide/patterns              complete working idiomatic examples
  jac://guide/jac-core-cheatsheet   baseline syntax: imports, control flow, match, comprehensions
  jac://guide/jac-types             type system: annotations, unions, optionals, `as` casts
  jac://guide/jac-has-fields        has-field declarations, defaults, post-init
  jac://guide/jac-impl-files        declaration/implementation separation (.impl.jac, impl/)

### [B] Object-Spatial Programming (OSP)

Data lives in a graph anchored to `root`. Walkers traverse nodes as mobile agents. Replaces
ORM + database + API boilerplate. Per-user data isolation built-in via `root`.
Keywords: node, edge, walker, visit, report, here, visitor, disengage, root, spawn, ++>, [-->], [?:Type]

  jac://guide/jac-node-edge-patterns   shaping the graph: nodes, edges, relationships
  jac://guide/jac-walker-patterns      writing walkers, traversal, report/response patterns
  jac://examples/littleX               canonical working OSP example

### [C] Data Persistence & Multi-User Auth

Nodes connected to `root` auto-persist (no DB, no SQL, no ORM). Each user gets their own
isolated root automatically. `walker:priv` enforces auth. `walker:pub` = public. `def:pub` = public function endpoint.

  jac://guide/jac-sv-persistence   modeling relationships, querying the graph from endpoints
  jac://guide/jac-sv-multi-user    cross-user permission grants and shared data
  jac://guide/jac-sv-auth          server-side auth, protected endpoints

### [D] AI Integration (byLLM / MTP)

`def fn(x: T) -> R by llm;` - delegates the function body to an LLM using the name/types as the prompt.
`sem fn = "..."` adds semantic hints. Supports structured output, tool calling, streaming, multimodal.

  jac://guide/jac-by-llm   full byLLM / MTP: structured outputs, tools, streaming, multimodal

### [E] Full-Stack Development (Codespaces)

Single .jac file = complete full-stack app. `sv {}` = server code. `cl {}` = client code
(React/JSX). `.cl.jac` files default to client mode (no `cl {}` wrapper needed).

**Client components**: `cl def:pub Name(prop: str) -> JsxElement { ... }`
**Reactive state**: `has count: int = 0;` = React useState. Assignment `count = count + 1;` triggers
a re-render. NEVER mutate directly (`items.append(x)` won't re-render - use `items = items + [x];`).
**Effects**: `async can with entry { ... }` = useEffect on mount. `can with exit { ... }` = cleanup.
**Events**: `onChange={lambda e: ChangeEvent { name = e.target.value; }}` - ambient DOM types, no import.
**Calling server from client** (critical pattern):
  `sv import from ..main { my_walker }` - import server walker into client code
  `response = root() spawn my_walker(field=value);` - spawns walker via HTTP automatically
  `data = response.reports[0][0];` - access walker report results
**Auth built-ins**: `jacLogin(user, pass)`, `jacSignup(user, pass)`, `jacLogout()`, `jacIsLoggedIn()`

  jac://guide/jac-fullstack-patterns   wiring main.jac: endpoint registration + client mount
  jac://guide/jac-cl-components        client components: state, effects, props, callables
  jac://guide/jac-cl-routing           pages/ routing, [id] params, layouts
  jac://guide/jac-cl-auth              client auth: login/signup/logout, AuthGuard
  jac://guide/jac-cl-organization      splitting client code, importing server walkers
  jac://guide/jac-cl-styling           styling client components
  jac://guide/jac-cl-js-interop        DOM refs and JS value interop
  jac://guide/jac-npm-packages         adding npm packages, importing them in .cl.jac
  jac://guide/jac-scaffold             scaffolding a new project
  jac://guide/jac-project-kinds        project kinds: server / client / fullstack / native
  jac://guide/jac-shadcn-components    shadcn/ui components for cl blocks
  jac://guide/jac-shadcn-blocks        shadcn/ui composite blocks

### [F] Design Patterns

CRUD walkers, search walkers, aggregation, hierarchical traversal, walker vs def:pub decision,
declaration/implementation separation (.jac + .impl.jac split).

  jac://guide/patterns              idiomatic patterns with working code
  jac://guide/jac-walker-patterns   walker design patterns
  jac://examples/littleX            full-stack social app (real-world OSP)

Available example categories (use ONLY these names with get_example):
  chess, littleX

### [G] Code Organization & Project Structure

.jac (server default), .impl.jac (implementations), .cl.jac (client), .sv.jac (server-explicit),
.test.jac (tests). impl/ subdirectory for method bodies. Declaration/impl separation pattern.

  jac://guide/jac-impl-files        declaration/impl separation, impl/ layout
  jac://guide/jac-cl-organization   organizing client modules
  jac://guide/jac-scaffold          project scaffolding and file conventions

### [H] API Server & Deployment

`jac start app.jac` auto-exposes `walker:pub` and `def:pub` as HTTP endpoints. Walker `has`
fields = request body. `report` values = response body. `@restspec` customises method/path.

  jac://guide/jac-sv-endpoints      REST endpoints, walker:pub, request/response shape
  jac://guide/jac-sv-deploy         running in production: jac start flags, DB backends
  jac://guide/jac-sv-microservices  microservice decomposition and scaling
  jac://guide/jac-sv-streaming      streaming responses

### [I] Testing

`test "name" { ... }` blocks inline or in .test.jac files. Spawn walkers and assert on `.reports`.
Run with `jac test`.

  jac://guide/jac-testing   test blocks, `jac test` flags, testing walkers

### [J] Python Integration

Import Python packages with `import from os { path }` (same syntax, no import:py prefix).
Inline Python: `::py:: ... ::py::`. Use `class` only for Python-specific features (metaclasses,
decorators, @property). Prefer `obj` for everything else.

  jac://guide/jac-python-interop   PyPI imports, using Python from Jac and Jac from Python

### [K] Native Compilation

Compile Jac to native binaries and WebAssembly.

  jac://guide/jac-native          native compilation pathway
  jac://guide/jac-native-wasm     WebAssembly target
  jac://guide/jac-native-shared   shared-library output

### [L] Concurrency, Config, Debugging, Packaging

  jac://guide/jac-concurrency   flow, wait, async
  jac://guide/jac-config        jac.toml configuration
  jac://guide/jac-debugging     debugging parse / type / runtime errors
  jac://guide/jac-packaging     packaging and distributing Jac projects

### [M] Mobile & Desktop Targets

  jac://guide/jac-mobile-app    mobile app target
  jac://guide/jac-desktop-app   desktop app target

### [N] Official Plugins

Optional plugins - check if one covers your task before building from scratch:

  byllm      - AI integration: `by llm`, `sem`, structured output, tool calling, streaming
               (jac://guide/jac-by-llm)
  jac-scale  - Production deployment: REST API server, scaling, Kubernetes
               (jac://guide/jac-sv-deploy)
  jac-shadcn - UI component library, shadcn/ui components for cl blocks
               (jac://guide/jac-shadcn-components)

The React client framework, byLLM compilation support, and the MCP server itself are built into the
`jac` binary - no install needed.

---

## Quick Task -> Resource Lookup

  Task                                    | Resource URI
  ----------------------------------------|-------------------------------------------
  Write ANY Jac code                      | jac://guide/pitfalls + jac://guide/patterns
  Look up syntax while coding             | jac://guide/jac-core-cheatsheet
  Fix a type error                        | jac://guide/jac-types
  Store / retrieve user data              | jac://guide/jac-sv-persistence
  Build a REST endpoint                   | jac://guide/jac-sv-endpoints
  Write a walker / traverse the graph     | jac://guide/jac-walker-patterns
  Model nodes & edges                     | jac://guide/jac-node-edge-patterns
  Multi-user data / permissions           | jac://guide/jac-sv-multi-user
  Call an LLM / AI function               | jac://guide/jac-by-llm
  Build UI components                     | jac://guide/jac-cl-components
  Build a full-stack app                  | jac://guide/jac-fullstack-patterns + jac://guide/jac-scaffold
  Add login / signup / auth               | jac://guide/jac-cl-auth + jac://guide/jac-sv-auth
  Add routing / pages                     | jac://guide/jac-cl-routing
  Use npm packages / UI libraries         | jac://guide/jac-npm-packages
  Deploy to production                    | jac://guide/jac-sv-deploy
  Write tests                             | jac://guide/jac-testing
  Use Python from Jac                     | jac://guide/jac-python-interop
  Compile to native / wasm                | jac://guide/jac-native
  See a working example                   | jac://examples/littleX
  Understand project file layout          | jac://guide/jac-impl-files + jac://guide/jac-scaffold
  Discover all guides                     | list the jac://guide/* resources
