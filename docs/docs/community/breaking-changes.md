# Breaking Changes

This page documents significant breaking changes in Jac and Jaseci that may affect your existing code or workflows. Use this information to plan and execute updates to your applications.

## Latest Breaking Changes

MTLLM library is now deprecated and replaced by the byLLM package. In all place where `mtllm` was used before can be replaced with `byllm`.

### BrowserRouter Migration (jac-client 0.2.12)

Client-side routing has migrated from `HashRouter` to `BrowserRouter`. URLs now use clean paths instead of hash-based URLs.

**Before:**

```
http://localhost:8000#/about
http://localhost:8000#/login
http://localhost:8000#/user/123
```

**After:**

```
http://localhost:8000/about
http://localhost:8000/login
http://localhost:8000/user/123
```

**Key Changes:**

- `HashRouter` replaced with `BrowserRouter` in the React Router integration
- `navigate()` now uses `window.history.pushState` instead of `window.location.hash`
- The vanilla runtime's `__jacGetHashPath` renamed to `__jacGetPath`, returns `window.location.pathname` instead of hash fragment
- Server-side SPA catch-all automatically serves app HTML for clean URL paths when `base_route_app` is configured

**Migration Steps:**

1. Update any hardcoded hash-based URLs (`#/path`) to clean paths (`/path`) in your code
2. If using the vanilla runtime's `Link` component, `href` values no longer need a `#` prefix
3. Ensure `base_route_app` is set in `jac.toml` `[serve]` section for direct navigation and page refresh to work
4. If deploying as a static site, configure your hosting provider's SPA fallback (see [routing documentation](../../learn/tools/jac_serve.md))

### `--cl` Flag Replaced with `--npm` and `--use client`

The `--cl` flag has been removed from jac-client CLI commands and replaced with more descriptive alternatives.

**Before:**

```bash
# Create a client project
jac create myapp --cl

# Add npm dependencies
jac add tailwind --cl
jac add typescript --cl --dev

# Remove npm dependencies
jac remove lodash --cl
```

**After:**

```bash
# Create a client project (use --use client instead of --cl)
jac create myapp --use client

# Add npm dependencies (use --npm instead of --cl)
jac add tailwind --npm
jac add typescript --npm --dev

# Remove npm dependencies (use --npm instead of --cl)
jac remove lodash --npm
```

**Key Changes:**

- `jac create --cl` → `jac create --use client`
- `jac add --cl` → `jac add --npm`
- `jac remove --cl` → `jac remove --npm`
- The `--skip` flag remains available for `jac create --use client --skip` to skip npm package installation

### `.cl.jac` Files No Longer Auto-Imported as Annexes

Client module files (`.cl.jac`) are now treated as **standalone modules only**. Previously, `.cl.jac` files were automatically annexed to their corresponding `.jac` files (similar to `.impl.jac` files). This dual behavior has been removed to simplify the module system.

**Before:**

```jac
# main.jac - automatically included main.cl.jac content
node Todo { has title: str; }

walker AddTodo { has title: str; }
```

```jac
# main.cl.jac - auto-annexed to main.jac (no explicit import needed)
cl {
    def:pub app -> any {
        return <div>Hello World</div>;
    }
}
```

**After:**

```jac
# main.jac - must explicitly import client code
node Todo { has title: str; }

walker AddTodo { has title: str; }

# Explicit client block with import
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> any {
        return <ClientApp />;
    }
}
```

```jac
# frontend.cl.jac - standalone client module (renamed from main.cl.jac)
def:pub app -> any {
    return <div>Hello World</div>;
}
```

**Key Changes:**

- `.cl.jac` files are no longer automatically annexed to matching `.jac` files
- Client code must be explicitly imported using `cl import` or imported inside a `cl {}` block
- The main entry point must re-export the client app through a `cl {}` block to trigger client compilation
- Use uppercase aliases when importing components (e.g., `app as ClientApp`) so JSX compiles to component references instead of strings

**Migration Steps:**

1. Rename your `main.cl.jac` to a descriptive name like `frontend.cl.jac` or `app.cl.jac`
2. Add a `cl {}` block in your `main.jac` that imports and re-exports the client app:

   ```jac
   cl {
       import from .frontend { app as ClientApp }

       def:pub app -> any {
           return <ClientApp />;
       }
   }
   ```

3. If your `.cl.jac` file references walkers defined in `main.jac`, add walker stub declarations in the client file:

   ```jac
   # frontend.cl.jac
   walker AddTodo { has title: str; }  # Stub for RPC calls
   walker ListTodos {}

   def:pub app -> any { ... }
   ```

**Note:** `.cl.jac` files can still have their own `.impl.jac` annexes for separating declarations from implementations.

### Version 0.9.8

#### 1. Walker Traversal Semantics Changed to Recursive DFS with Deferred Exits

Walker traversal now uses recursive depth-first semantics where **entry abilities execute when entering a node**, and **exit abilities execute after all descendants are visited** (post-order). Previously, both entry and exit abilities executed on each node before moving to the next.

**Before (v0.9.7 and earlier):**

For a graph `root → A → B → C`, the execution order was:

```
Enter root → Exit root → Enter A → Exit A → Enter B → Exit B → Enter C → Exit C
```

Each node's entries AND exits completed before visiting the next node.

**After (v0.9.8+):**

```
Enter root → Enter A → Enter B → Enter C → Exit C → Exit B → Exit A → Exit root
```

Entries execute depth-first, exits execute in reverse order (LIFO/stack unwinding).

**Example with sibling nodes:**

```jac
# Graph: root → a, root → b, root → c (three children)

# Before: a entries, a exits, b entries, b exits, c entries, c exits
# After:  a entries, b entries, c entries, c exits, b exits, a exits
```

**Key Behavioral Changes:**

1. **Exit abilities are deferred** until all descendants of a node are visited
2. **If `disengage` is called during entry/child traversal**, exit abilities for ancestor nodes will NOT execute
3. **Exit order is LIFO** (last visited node's exits run first)
4. **`walker.path`** is now populated during traversal, tracking visited nodes in order

**Migration Steps:**

1. Review any code that relies on exit abilities running before visiting child nodes
2. If your walker uses `disengage` and depends on ancestor exit abilities running, refactor to use entry abilities or remove the disengage
3. Update tests that assert specific entry/exit execution order

**Example migration for disengage pattern:**

```jac
# Before: Exit ability would run before disengage stops traversal
walker MyWalker {
    can process with MyNode entry {
        if some_condition { disengage; }
        visit [-->];
    }
    can cleanup with `root exit {
        # This WOULD run before disengage in old semantics
        print("Cleanup");
    }
}

# After: Use entry ability instead, since exits won't run after disengage
walker MyWalker {
    can process with MyNode entry {
        if some_condition { disengage; }
        visit [-->];
    }
    can cleanup with `root entry {
        # Use entry to ensure this runs before any disengage
        print("Cleanup will run");
    }
}
```

### Version 0.9.5

#### 1. `jac serve` Renamed to `jac start`, `jac scale` Now Uses `--scale` Flag

The `jac serve` command has been renamed to `jac start` for better clarity. Additionally, the `jac scale` command (from jac-scale plugin) is now accessed via `jac start --scale` instead of a separate command.

**Before (v0.9.4 and earlier):**

```bash
# Start local server
jac serve main.jac

# Deploy to Kubernetes (jac-scale plugin)
jac scale main.jac
jac scale main.jac -b  # with build
```

**After (v0.9.5+):**

```bash
# Start local server
jac start main.jac

# Deploy to Kubernetes (jac-scale plugin)
jac start main.jac --scale
jac start main.jac --scale --build  # with build
```

**Migration Steps:**

1. Replace all `jac serve` commands with `jac start`
2. Replace `jac scale` commands with `jac start --scale`
3. Replace `jac scale -b` with `jac start --scale --build`
4. Update any CI/CD scripts or documentation that reference these commands

**Key Changes:**

- `jac serve` → `jac start`
- `jac scale` → `jac start --scale`
- `jac scale -b` → `jac start --scale --build` (or `jac start --scale -b`)
- The `jac destroy` command remains unchanged for removing Kubernetes deployments

#### 2. Build Artifacts Consolidated to `.jac/` Directory

All Jac project build artifacts are now organized under a single `.jac/` directory instead of being scattered across the project root. This is a breaking change for existing projects.

**Before (v0.9.4 and earlier):**

```
my-project/
├── jac.toml
├── main.jac
├── .jaccache/                    # Bytecode cache
├── packages/                     # Python packages
├── .client-build/                # Client build artifacts (jac-client)
├── .jac-client.configs/          # Client config files (jac-client)
└── anchor_store.db.*             # ShelfDB files (jac-scale)
```

**After (v0.9.5+):**

```
my-project/
├── jac.toml
├── main.jac
└── .jac/                         # All build artifacts
    ├── cache/                    # Bytecode cache
    ├── packages/                 # Python packages
    ├── client/                   # Client build artifacts
    │   ├── configs/              # Generated config files
    │   ├── build/                # Build output
    │   └── dist/                 # Distribution files
    └── data/                     # Runtime data (ShelfDB)
```

**Migration Steps:**

1. Delete old artifact directories from your project root:

   ```bash
   rm -rf .jaccache packages .client-build .jac-client.configs anchor_store.db.*
   ```

2. Update `.gitignore` (simplified):

   ```gitignore
   # Before
   .jaccache/
   packages/
   .client-build/
   .jac-client.configs/
   *.db

   # After
   .jac/
   ```

3. If using custom `shelf_db_path` in jac-scale config, update the path:

   ```toml
   [plugins.scale.database]
   shelf_db_path = ".jac/data/anchor_store.db"
   ```

4. Optionally configure a custom base directory in `jac.toml`:

   ```toml
   [build]
   dir = ".custom-build"  # Defaults to ".jac"
   ```

**Key Changes:**

- Bytecode cache moved from `.jaccache/` to `.jac/cache/`
- Python packages moved from `packages/` to `.jac/packages/`
- Client build artifacts moved from `.client-build/` to `.jac/client/`
- Client configs moved from `.jac-client.configs/` to `.jac/client/configs/`
- ShelfDB files moved to `.jac/data/`
- New `[build].dir` config option allows customizing the base directory

### Version 0.9.4

#### 1. `let` Keyword Removed - Use Direct Assignment

The `let` keyword has been removed from Jaclang. Variable declarations now use direct assignment syntax, aligning with Python's approach to variable binding.

**Before**

```jac
with entry {
    let x = 10;
    let name = "Alice";
}
```

**After**

```jac
with entry {
    x = 10;
    name = "Alice";
}
```

**Key Changes:**

- Remove the `let` keyword from all variable declarations
- Use direct assignment (`x = value`) instead of `let x = value`
- This applies to all contexts including destructuring assignments

> **Note for client-side code:** In `cl {}` blocks and `.cl.jac` files, prefer using `has` for reactive state (see v0.9.5 reactive state feature) instead of explicit `useState` destructuring.

### Version 0.8.10

#### 1. byLLM Imports Moved to `byllm.lib`

All byLLM exports have been moved under the `byllm.lib` module to enable lazy loading and faster startup. Direct imports from `byllm` are removed.

**Before**

```jac
import from byllm { Model }

glob llm = Model(model_name="gpt-4o-mini", verbose=True);
```

**After**

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini", verbose=True);
```

### Version 0.8.8

#### 1. `check` Keyword Removed - Use `assert` in Test Blocks

The `check` keyword has been removed from Jaclang. All testing functionality is now unified under `assert` statements, which behave differently depending on context: raising exceptions in regular code and reporting test failures within `test` blocks.

**Before**

```jac
glob a: int = 5;
glob b: int = 2;

test test_equality {
    check a == 5;
    check b == 2;
}

test test_comparison {
    check a > b;
    check a - b == 3;
}

test test_membership {
    check "a" in "abc";
    check "d" not in "abc";
}

test test_function_result {
    check almostEqual(a + b, 7);
}
```

**After**

```jac
glob a: int = 5;
glob b: int = 2;

test test_equality {
    assert a == 5;
    assert b == 2;
}

test test_comparison {
    assert a > b;
    assert a - b == 3;
}

test test_membership {
    assert "a" in "abc";
    assert "d" not in "abc";
}

test test_function_result {
    assert almostEqual(a + b, 7);
}
```

**Key Changes:**

- Replace all `check` statements with `assert` statements in test blocks
- `assert` statements in test blocks report test failures without raising exceptions
- `assert` statements outside test blocks continue to raise `AssertionError` as before
- Optional error messages can be added: `assert condition, "Error message";`

This change unifies the testing and validation syntax, making the language more consistent while maintaining all testing capabilities.

### Version 0.8.4

#### 1. Global, Nonlocal Operators Updated to `global`, `nonlocal`

This renaming aims to make the operator's purpose align with python, as `global`, `nonlocal` more aligned with python.

**Before**

```jac
glob x = "Jaclang ";

def outer_func -> None {
    :global: x; # :g: also correct

    x = 'Jaclang is ';
    y = 'Awesome';
    def inner_func -> tuple[str, str] {
        :nonlocal: y; #:nl: also correct

        y = "Fantastic";
        return (x, y);
    }
    print(x, y);
    print(inner_func());
}

with entry {
    outer_func();
}
```

**After**

```jac
glob x = "Jaclang ";

def outer_func -> None {
    global x;

    x = 'Jaclang is ';
    y = 'Awesome';
    def inner_func -> tuple[str, str] {
        nonlocal y;

        y = "Fantastic";
        return (x, y);
    }
    print(x, y);
    print(inner_func());
}

with entry {
    outer_func();
}
```

#### 2. `mtllm.llms` Module Replaced with Unified `mtllm.llm {Model}`

The mtllm library now uses a single unified Model class under the `mtllm.llm` module, instead of separate classes like `Gemini` and `OpenAI`. This simplifies usage and aligns model loading with HuggingFace-style naming conventions.

**Before**

```jac
import from mtllm.llms { Gemini, OpenAI }

glob llm1 = Gemini(model_name="gemini-2.0-flash");
glob llm2 = OpenAI();
```

**After**

```jac
import from mtllm.llm { Model }

glob llm1 = Model(model_name="gemini/gemini-2.0-flash");
glob llm2 = Model(model_name="gpt-4o");
```

### Version 0.8.1

#### 1. `dotgen` builtin function is now name `printgraph`

This renaming aims to make the function's purpose clearer, as `printgraph` more accurately reflects its action of outputting graph data, similar to how it can also output in JSON format. Also other formats may be added (like mermaid).

**Before**

```jac
node N {has val: int;}
edge E {has val: int = 0;}

with entry {
    end = root;
    for i in range(0, 2) {
        end +>: E : val=i :+> (end := [ N(val=i) for i in range(0, 2) ]);
    }
    data = dotgen(node=root);
    print(data);
}
```

**After**

```jac
node N {has val: int;}
edge E {has val: int = 0;}

with entry {
    end = root;
    for i in range(0, 2) {
        end +>: E : val=i :+> (end := [ N(val=i) for i in range(0, 2) ]);
    }
    data = printgraph(node=root);
    print(data);
}
```

#### 2. `ignore` feature is removed

This removal aims to avoid being over specifc with data spatial features.

**Before**

```jac
node MyNode {
    has val:int;
}

walker MyWalker {
    can func1 with MyNode entry {
        ignore [here];
        visit [-->]; # before
        print(here);
    }
}

with entry {
    n1 = MyNode(5);
    n1 ++> MyNode(10) ++> MyNode(15) ++> n1; # will result circular
    n1 spawn MyWalker();
}
```

**After**

```jac
node MyNode {
    has val:int;
}

walker MyWalker {
    has Ignore: list = [];

    can func1 with MyNode entry {
        self.Ignore.append(here); # comment here to check the circular graph
        visit [i for i in [-->] if i not in self.Ignore]; # now
        print(here);
    }
}

with entry {
    n1 = MyNode(5);
    n1 ++> MyNode(10) ++> MyNode(15) ++> n1; # will result circular
    n1 spawn MyWalker();
}
```

### Version 0.8.0 (Main branch since 5/5/2025)

#### 1. `impl` keyword introduced to simplify Implementation

The new `impl` keyword provides a simpler and more explicit way to implement abilities and methods for objects, nodes, edges, and other types. This replaces the previous more complex colon-based syntax for implementation.

**Before (v0.7.x):**

```jac
:obj:Circle:def:area -> float {
    return math.pi * self.radius * self.radius;
}

:node:Person:can:greet with Room entry {
    print("Hello, I am " + self.name);
}

:def:calculate_distance(x: float, y: float) -> float {
    return math.sqrt(x*x + y*y);
}
```

**After (v0.8.0+):**

```jac
impl Circle.area -> float {
    return math.pi * self.radius * self.radius;
}

impl Person.greet with Room entry {
    return "Hello, I am " + self.name;
}

impl calculate_distance(x: float, y: float) -> float {
    return math.sqrt(x*x + y*y);
}
```

This change makes the implementation syntax more readable, eliminates ambiguity, and better aligns with object-oriented programming conventions by using the familiar dot notation to indicate which type a method belongs to.

#### 2. Inheritance base classes specification syntax changed

The syntax for specifying inheritance has been updated from using colons to using parentheses, which better aligns with common object-oriented programming languages.

**Before (v0.7.x):**

```jac
obj Vehicle {
    has wheels: int;
}

obj Car :Vehicle: {
    has doors: int = 4;
}

node BaseUser {
    has username: str;
}

node AdminUser :BaseUser: {
    has is_admin: bool = true;
}
```

**After (v0.8.0+):**

```jac
obj Vehicle {
    has wheels: int;
}

obj Car(Vehicle) {
    has doors: int = 4;
}

node BaseUser {
    has username: str;
}

node AdminUser(BaseUser) {
    has is_admin: bool = true;
}
```

This change makes the inheritance syntax more intuitive and consistent with languages like Python, making it easier for developers to understand class hierarchies at a glance.

#### 3. `def` keyword introduced

Instead of using `can` keyword for all functions and abilities, `can` statements are only used for object-spatial abilities and `def` keyword must be used for traditional python like functions and methods.

**Before (v0.7.x and earlier):**

```jac
can add(x: int, y: int) -> int {
    return x + y;
}

node Person {
    has name;
    has age;

    can get_name {
        return self.name;
    }

    can greet with speak_to {
        return "Hello " + visitor.name + ", my name is " + self.name;
    }

    can calculate_birth_year {
        return 2025 - self.age;
    }
}
```

**After (v0.8.0+):**

```jac
def add(x: int, y: int) -> int {
    return x + y;
}

node Person {
    has name;
    has age;

    def get_name {
        return self.name;
    }

    can greet with speak_to entry {
        return "Hello " + visitor.name + ", my name is " + self.name;
    }

    def calculate_birth_year {
        return 2025 - self.age;
    }
}
```

#### 4. `visitor` keyword introduced

Instead of using `here` keyword to represent the other object context while `self` is the self referencial context. Now `here` can only be used in walker abilities to reference a node or edge, and `visitor` must be used in nodes/edges to reference the walker context.

**Before (v0.7.x and earlier):**

```jac
node Person {
    has name;

    can greet {
        self.name = self.name.upper();
        return "Hello, I am " + self.name;
    }

    can update_walker_info {
        here.age = 25;  # 'here' refers to the walker
    }
}

walker PersonVisitor {
    has age;

    can visit: Person {
        here.name = "Visitor";  # 'here' refers to the current node
        report here.greet();
    }
}
```

**After (v0.8.0+):**

```jac
node Person {
    has name;

    can greet {
        self.name = self.name.upper();
        return "Hello, I am " + self.name;
    }

    can update_walker_info {
        visitor.age = 25;  # 'visitor' refers to the walker
    }
}

walker PersonVisitor {
    has age;

    can visit: Person {
        here.name = "Visitor";  # 'here' still refers to the current node in walker context
        report here.greet();
    }
}
```

This change makes the code more intuitive by clearly distinguishing between:

- `self`: The current object (node or edge) referring to itself
- `visitor`: The walker interacting with a node/edge
- `here`: Used only in walker abilities to reference the current node/edge being visited

#### 5. Changes to lambda syntax and `lambda` instroduced

Instead of using the `with x: int can x;` type syntax the updated lambda syntax now replaces `with` and `can` with `lambda` and `:` repsectively.

**Before (v0.7.x):**

```jac
# Lambda function syntax with 'with' and 'can'
with entry {
    square_func = with x: int can x * x;
}
```

**After (v0.8.0+):**

```jac
# Updated lambda
with entry {
    square_func = lambda x: int: x * x;
}
```

This change brings Jac's lambda syntax closer to Python's familiar `lambda parameter: expression` pattern, making it more intuitive for developers coming from Python backgrounds while maintaining Jac's type annotations.

#### 6. Data spatial arrow notation updated

The syntax for typed arrow notations are updated as `-:MyEdge:->` and `+:MyEdge:+>` is now `->:MyEdge:->` and `+>:MyEdge:+> for reference and creations.

**Before (v0.7.x):**

```jac
friends = [-:Friendship:->];
alice <+:Friendship:strength=0.9:+ bob;
```

**After (v0.8.0+):**

```jac
friends = [->:Friendship:->];
alice <+:Friendship:strength=0.9:<+ bob;
```

This change was made to eliminate syntax conflicts with Python-style list slicing operations (e.g., `my_list[:-1]` was forced to be written `my_list[: -1]`). The new arrow notation provides clearer directional indication while ensuring that object-spatial operations don't conflict with the token parsing for common list operations.

#### 7. Import `from` syntax updated for clarity

The syntax for importing specific modules or components from a package has been updated to use curly braces for better readability and to align with modern language conventions.

**Before (v0.7.x):**

```jac
import from pygame_mock, color, display;
import from utils, helper, math_utils, string_formatter;
```

**After (v0.8.0+):**

```jac
import from pygame_mock { color, display };
import from utils { helper, math_utils, string_formatter };
```

This new syntax using curly braces makes it clearer which modules are being imported from which package, especially when importing multiple items from different packages.

#### 8. Import statement are auto resolved (no language hints needed)

The language-specific import syntax has been simplified by removing the explicit language annotations (`:py` and `:jac`). The compiler now automatically resolves imports based on context and file extensions.

**Before (v0.7.x):**

```jac
import:py requests;
import:jac graph_utils;
import:py json, os, sys;
```

**After (v0.8.0+):**

```jac
import requests;
import graph_utils;
import json, os, sys;
```

This change simplifies the import syntax, making code cleaner while still maintaining the ability to import from both Python and Jac modules. The Jac compiler now intelligently determines the appropriate language context for each import.

#### 9. `restrict` and `unrestrict` Interfaces to Jac Machine now `perm_grant` and `perm_revoke`

The permission management API has been renamed to better reflect its purpose and functionality.

**Before (v0.7.x):**

```jac
walker create_item {
    can create with `root entry {
        new_item = spawn Item(name="New Item");
        Jac.unrestrict(new_item, level="CONNECT");  # Grant permissions
        Jac.restrict(new_item, level="WRITE");      # Revoke permissions
    }
}
```

**After (v0.8.0+):**

```jac
walker create_item {
    can create with `root entry {
        new_item = spawn Item(name="New Item");
        Jac.perm_grant(new_item, level="CONNECT");  # Grant permissions
        Jac.perm_revoke(new_item, level="WRITE");   # Revoke permissions
    }
}
```

This change makes the permission management API more intuitive by using verbs that directly describe the actions being performed.
