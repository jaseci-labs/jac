# Jac & Jaseci - Knowledge Map

## What is Jac?

Jac is a full-stack language that compiles to Python bytecode (server), JavaScript (client), and native
binaries - from a single file. It extends Python with 3 paradigms:

  1. Codespaces (sv/cl/na) - target where code runs: server, browser, or native binary
  2. Object-Spatial Programming (OSP) - graph-native data model with built-in multi-user persistence
  3. Meaning-Typed Programming (MTP) - AI functions via `by llm` with compiler-extracted semantics

## What is Jaseci?

The runtime stack: jaclang (compiler + runtime), jac-client (React frontend), jac-scale (deployment).
They handle DB schema, API routing, HTTP, auth, and frontend generation automatically.

---

## Resource Index

Each section describes a topic and lists resource URIs to fetch with get_resource.
Size tags: S = small (<500 lines), M = medium (500-1000), L = large (1000+).
Only fetch what you need for your current task.

### [A] Language Syntax - Jac is NOT Python

Semicolons on ALL statements. Braces {} for blocks, not indentation. `has` for instance fields
(not self.x). `obj` preferred over `class`. `def` for regular methods, `can` ONLY for
event-driven abilities. `import from X { Y }` syntax and `import X;` for module-level import.
`with entry {}` as main block. `glob` for module-level variables. `self` is implicit in method signatures.

  jac://guide/pitfalls       [M] WRONG vs RIGHT for common AI mistakes
  jac://guide/patterns       [M] complete working idiomatic examples
  jac://docs/cheatsheet      [L] complete syntax lookup
  jac://docs/foundation      [L] full language specification

### [B] Object-Spatial Programming (OSP)

Data lives in a graph anchored to `root`. Walkers traverse nodes as mobile agents. Replaces
ORM + database + API boilerplate. Per-user data isolation built-in via `root`.
Keywords: node, edge, walker, visit, report, here, visitor, disengage, root, spawn, ++>, [-->], [?:Type]

  jac://docs/osp              [L] nodes, edges, walkers, CRUD patterns
  jac://docs/walker-responses  [S] walker response and reporting patterns
  jac://examples/data_spatial  [S] canonical working OSP example

### [C] Data Persistence & Multi-User Auth

Nodes connected to `root` auto-persist (no DB, no SQL, no ORM). Each user gets their own
isolated root automatically. `walker:priv` enforces auth. `walker:pub` = public. `def:pub` = public function endpoint.

  jac://docs/osp              [L] persistence under graph construction section

### [D] AI Integration (byLLM / MTP)

`def fn(x: T) -> R by llm;` - delegates function body to LLM using name/types as the prompt.
`sem fn = "..."` adds semantic hints. Supports: structured output, tool calling, streaming, multimodal.

  jac://docs/byllm                [L] full byLLM + MTP reference
  jac://docs/tutorial-ai-agentic  [S] agentic AI with tool calling

### [E] Full-Stack Development (Codespaces)

Single .jac file = complete full-stack app. `sv {}` = server code. `cl {}` = client code
(React/JSX). `.cl.jac` files default to client mode (no `cl {}` wrapper needed).

**Client components**: `cl def:pub Name(prop: str) -> JsxElement { ... }`
**Reactive state**: `has count: int = 0;` = React useState. Assignment `count = count + 1;`
triggers re-render. NEVER mutate directly (`items.append(x)` won't re-render - use
`items = items + [x];`).
**Effects**: `async can with entry { ... }` = useEffect on mount. `can with exit { ... }` = cleanup.
**Events**: `onChange={lambda e: ChangeEvent { name = e.target.value; }}` - use ambient DOM types (ChangeEvent, KeyboardEvent, FormEvent, etc.) -- no import needed.
**Lists**: `{[<Item key={item._jac_id} item={item}/> for item in items]}` - use `_jac_id` for keys.

**Calling server from client** (critical pattern):
  `sv import from ..main { my_walker }` - import server walker into client code
  `response = root() spawn my_walker(field=value);` - spawns walker via HTTP automatically
  `data = response.reports[0][0];` - access walker report results

**Client imports**: `cl import from react { useState }`,
  `cl import from "@jac/runtime" { Link, useNavigate, JacForm, JacSchema }`
**Auth built-ins**: `jacLogin(user, pass)`, `jacSignup(user, pass)`, `jacLogout()`, `jacIsLoggedIn()`
**Context**: `glob:pub MyCtx = createContext(None);` - module-level context
**Dict spread**: `{** dict1, ** dict2}` (NOT `{...dict1}`)
**Routing**: file-based via `pages/` directory, or manual `<Router><Routes><Route path="/" .../>`.

  jac://docs/jac-client                      [L] full client reference
  jac://docs/tutorial-fullstack-setup        [S] project scaffolding
  jac://docs/tutorial-fullstack-components   [S] components, props, JSX
  jac://docs/tutorial-fullstack-state        [S] state, effects, context
  jac://docs/tutorial-fullstack-backend      [M] walker calls from client
  jac://docs/tutorial-fullstack-auth         [M] login, signup, protected routes
  jac://docs/tutorial-fullstack-routing      [M] file-based & manual routing
  jac://docs/tutorial-fullstack-npm          [M] npm packages, UI libraries, JS interop
  jac://docs/tutorial-fullstack-advanced     [M] advanced full-stack patterns
  jac://docs/jac-vs-traditional              [S] side-by-side vs Python+React

### [F] Design Patterns

CRUD walkers, search walkers, aggregation, hierarchical traversal, walker vs def:pub decision,
declaration/implementation separation (.jac + .impl.jac split).

  jac://guide/patterns         [M] idiomatic patterns with working code
  jac://examples/littleX       [S] full-stack social app (real-world OSP)
  jac://examples/guess_game    [S] progressive: plain obj -> walker -> LLM

Available example categories (use ONLY these names with get_example):
  chess, data_spatial, guess_game, littleX, manual_code, medical, micro, plugins, rpg_game, shopping_cart

### [G] Code Organization & Project Structure

.jac (server default), .impl.jac (implementations), .cl.jac (client), .sv.jac (server-explicit),
.test.jac (tests). impl/ subdirectory for method bodies. Declaration/impl separation pattern.

  jac://docs/code-organization [M] project structure and file conventions

### [H] API Server & Deployment

`jac start app.jac` auto-exposes `walker:pub` and `def:pub` as HTTP endpoints. Walker `has`
fields = request body. `report` values = response body. `@restspec` customises method/path.

  jac://docs/jac-scale                  [L] deployment and scaling
  jac://docs/tutorial-production-local  [M] local API server setup

### [I] Testing

`test "name" { ... }` blocks inline or in .test.jac files. Spawn walkers and assert on `.reports`.
Run with `jac test`.

  jac://docs/testing           [M] test framework reference

### [J] Python Integration

Import Python packages with `import from os { path }` (same syntax, no import:py prefix).
Inline Python: `::py:: ... ::py::`. Use `class` only for Python-specific features (metaclasses,
decorators, @property). Prefer `obj` for everything else.

  jac://docs/python-integration [M] Python interop reference

### [K] Official Plugins

4 official plugins - check if one covers your task before building from scratch.

  jac-byllm   - AI integration: `by llm`, `sem`, structured output, tool calling, streaming.
                jac://docs/byllm [L]

  jac-client  - Full-stack frontend: React/JSX client components, routing, auth, state.
                jac://docs/jac-client [L]

  jac-scale   - Production deployment: REST API server, scaling, Kubernetes.
                jac://docs/jac-scale [L]

  jac-shadcn  - UI component library (shadcn/ui components for cl blocks).
                jac://examples/plugins [S]

---

## Quick Task -> Resource Lookup

  Task                                    | Resource URI
  ----------------------------------------|-------------------------------------------
  Write ANY Jac code                      | jac://guide/pitfalls + jac://guide/patterns
  Store / retrieve user data              | jac://docs/osp
  Build a REST endpoint                   | jac://docs/osp
  Call an LLM / AI function               | jac://docs/byllm
  Build UI components                     | jac://docs/tutorial-fullstack-components
  Build a full-stack app                  | jac://docs/jac-client + jac://docs/tutorial-fullstack-setup
  Call walkers from client UI             | jac://docs/tutorial-fullstack-backend
  Add login / signup / auth               | jac://docs/tutorial-fullstack-auth
  Manage client state / effects           | jac://docs/tutorial-fullstack-state
  Add routing / pages                     | jac://docs/tutorial-fullstack-routing
  Use npm packages / UI libraries         | jac://docs/tutorial-fullstack-npm
  Advanced full-stack patterns            | jac://docs/tutorial-fullstack-advanced
  Look up syntax while coding             | jac://docs/cheatsheet
  Debug a parse or type error             | jac://guide/pitfalls + jac://docs/cheatsheet
  Compare Jac to Python/React             | jac://docs/jac-vs-traditional
  Deploy to production                    | jac://docs/jac-scale
  Write tests                             | jac://docs/testing
  See a working example                   | jac://examples/data_spatial or jac://examples/littleX
  Understand project file layout          | jac://docs/code-organization
  Discover available plugins              | jac://examples/plugins + list_templates tool
