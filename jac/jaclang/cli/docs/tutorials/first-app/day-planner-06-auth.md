# Day Planner 6: Authentication and Multi-File Organization

**Outcome:** Authentication and Multi-File Organization. **Prerequisite:** complete [lesson 5](day-planner-05-ai.md) or restore its complete-code checkpoint.

Work through the examples in order. Partial snippets extend the current file; blocks labeled complete contain the replacement file for that stage.

## Part 6: Authentication and Multi-File Organization

Your day planner has AI-powered task categorization, a shopping list generator, and automatic persistence. But there's a fundamental gap: there's no concept of users. Anyone who visits the app sees the same data. In a real application, each user needs their own private data. This part teaches two important concepts: how Jac handles authentication and per-user data isolation, and how to organize a growing codebase across multiple files.

**Built-in Auth**

Jac has built-in authentication functions for client-side code:

```jac
import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
```

- **`jacSignup(username, password)`** -- create an account (returns `{"success": True/False}`). Note: signup does not start a session by itself, so call `jacLogin` after a successful result to actually log the user in.
- **`jacLogin(username, password)`** -- log in (returns `True` or `False`)
- **`jacLogout()`** -- log out
- **`jacIsLoggedIn()`** -- check login status

These helpers manage the client authentication flow. The server still enforces endpoint access, and the application must handle unsuccessful signup and login attempts. This lesson verifies isolation using two accounts.

**`def:priv` -- Per-User Endpoints**

Remember from Part 2 that `root` is a self-referential pointer to the *current runner* of the program. In Parts 3-5, you used `def:pub` to create public endpoints where all users shared the same `root`. Now that you have authentication, you want each user's data to be private. For these endpoints, replace `def:pub` with `def:priv`:

- **`def:pub`** -- public endpoint, shared data (no authentication required)
- **`def:priv`** -- private endpoint, requires authentication, operates on the user's **own `root`**

With `def:priv`, each authenticated user gets their own isolated graph with its own `root`. User A's tasks are completely invisible to User B -- same code, isolated data, enforced by the runtime. This is the payoff of the `root` abstraction you learned earlier: because all your code already references `root` rather than a global variable, switching to per-user isolation requires no changes to your business logic.

**Multi-File Organization**

You met components at the end of Part 5 -- four JSX-bearing `def:pub` functions in one file. As your app grows, you'll want each component in its own file. Jac gives you two **orthogonal** axes for splitting code:

1. **Split by component** -- each component lives in its own `.jac` file. Use this when components can be understood and reused independently.
2. **Split by declaration / implementation** -- *inside* one component, you can put the state and render tree in a `.jac` file and the method bodies in a `.impl.jac` file. This is optional and useful only when a single component grows too long to read top-to-bottom.

Most code organization happens on axis (1). We'll cover (2) at the end of this section.

**Component files**

A component file is just a `.jac` file that exports a `def:pub` function returning `JsxElement`. The JSX is what makes it client code -- the compiler sees it and places the component (and any helpers it uses) in the browser bundle, with nothing to annotate. Other files import the component by name:

```jac
import from .components.TaskItem { TaskItem }
import from .components.TasksPanel { TasksPanel }
```

The authenticated app will have this shape:

```
day-planner-auth/
├── main.jac                       # Server: nodes, AI, endpoints + client entry
├── frontend.jac                # Client: top-level orchestrator
├── components/
│   ├── AuthForm.jac            # Login / signup form
│   ├── Header.jac              # Header with sign-out button
│   ├── TasksPanel.jac          # Task column -- owns task state
│   ├── TaskItem.jac            # Single task row -- presentational
│   ├── ShoppingPanel.jac       # Shopping column -- owns ingredient state
│   └── IngredientItem.jac      # Single ingredient row -- presentational
└── styles.css
```

`TaskItem` and `IngredientItem` were already components in Part 5 -- the only difference now is that they live in their own files. Each panel still owns its own state and fetches on mount; you just rendered everything in one file before.

**Importing server code into client files**

When a component calls server functions, it just imports them -- the compiler knows the targets are server endpoints (`def:pub` on a server module never relocates) and generates authenticated HTTP stubs instead of raw function calls:

```jac
import from ..main { Task, get_tasks, add_task, toggle_task, delete_task }
```

The same import brings server `node` types into client code, so `TaskItem(task: Task)` can be typed end-to-end. The `..main` is a relative import: `..` means "parent directory," because components live one folder below `main.jac` -- the same convention Python uses.

**Mixing server and client code in one file**

Both sides can live in the same file -- typically the entry point, where one client-side `app` component just renders the imported client app while the server code lives alongside it. Nothing marks the boundary; the compiler places each declaration by its content:

```jac
import from frontend { app as ClientApp }

def:pub app -> JsxElement {
    return
        <ClientApp/>;
}

# Server-side: nodes, AI delegations, endpoints live here.
```

The JSX in `app` places it in the browser; the nodes, walkers, and AI delegations below it have server-anchoring syntax and stay on the server. When you ever need to overrule a decision -- say, a pure helper that must stay server even though client code calls it -- add a `[placement.pins]` entry in `jac.toml` rather than any annotation in the source.

**Optional: splitting one big component into declaration + implementation**

For an individual component that grows too large, you can split its state and render tree from its method bodies using `.impl.jac`. The header file holds method *signatures*:

```jac
# big_component.jac
def:pub BigComponent -> JsxElement {
    has tasks: list[Task] = [];

    async def fetchTasks;        # signature only
    async def addTask;
    # ... render tree ...
}
```

And the implementation file holds the *bodies* in `impl` blocks:

```jac
# big_component.impl.jac
impl BigComponent.fetchTasks {
    tasks = await get_tasks();
}

impl BigComponent.addTask {
    # ...
}
```

In this tutorial we won't use this axis -- each component is small enough that keeping state, methods, and render tree together is easier to read than splitting them across two files. Reach for `.impl.jac` only when a single component file feels overwhelming on its own.

**Dependency-Triggered Abilities**

A **dependency-triggered ability** re-runs whenever specific state changes -- conceptually similar to React's `useEffect` with a dependency array:

```jac
can with [isLoggedIn] entry {
    if isLoggedIn {
        fetchTasks();
        fetchShoppingList();
    }
}
```

When `isLoggedIn` flips from `False` to `True`, this ability fires automatically. The auth example below uses a different approach for the same effect: each panel mounts only *after* the user logs in (because the parent renders `<TasksPanel/>` conditionally), so the panel's plain `can with entry` is enough -- no dependency tracking needed. Both patterns are idiomatic; pick the one that matches where the state lives.

**The Complete Authenticated App**

Create a new project for the authenticated version:

```bash
jac create day-planner-auth --kind web-static
cd day-planner-auth
```

**Run It**

All the complete files are in the collapsible sections below. Create each file, then run.

??? note "Complete `main.jac`"

    ```jac
    """AI Day Planner -- authenticated, multi-file version."""

    import from jaclang.comptime { fields, get_field }
    import from frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp />;
    }

    # --- Enums ---

    enum Category { WORK, PERSONAL, SHOPPING, HEALTH, FITNESS, OTHER }

    enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, BUNCH }

    # --- AI Types ---

    obj Ingredient {
        has name: str,
            quantity: float,
            unit: Unit,
            cost: float,
            carby: bool;
    }

    sem Ingredient.cost = "Estimated cost in USD";
    sem Ingredient.carby = "True if this ingredient is high in carbohydrates";

    def categorize(title: str) -> Category by llm();
    sem categorize = "Categorize a task based on its title";

    def generate_shopping_list(meal_description: str) -> list[Ingredient] by llm();
    sem generate_shopping_list = "Generate a shopping list of ingredients needed for a described meal";

    # --- Data Nodes ---

    node Task {
        has title: str,
            done: bool = False,
            category: str = "other";
    }

    node ShoppingItem {
        has name: str,
            quantity: float,
            unit: str,
            cost: float,
            carby: bool;
    }

    # --- Task Endpoints ---

    """Add a task with AI categorization."""
    def:priv add_task(title: str) -> Task {
        category = str(categorize(title)).split(".")[-1].lower();
        task = root ++> Task(title=title, category=category);
        return task;
    }

    """Get all tasks."""
    def:priv get_tasks -> list[Task] {
        return [root-->][?:Task];
    }

    """Toggle a task's done status."""
    def:priv toggle_task(id: str) -> Task | None {
        for task in [root-->][?:Task] {
            if jid(task) == id {
                task.done = not task.done;
                return task;
            }
        }
        return None;
    }

    """Delete a task."""
    def:priv delete_task(id: str) -> dict[str, str] {
        for task in [root-->][?:Task] {
            if jid(task) == id {
                del task;
                return {"deleted": id};
            }
        }
        return {};
    }

    # --- Shopping List Endpoints ---

    """Generate a shopping list from a meal description."""
    def:priv generate_list(meal: str) -> list[ShoppingItem] {
        for item in [root-->][?:ShoppingItem] {
            del item;
        }
        ingredients = generate_shopping_list(meal);
        for ing in ingredients {
            item: dict[str, any] = {"unit": str(ing.unit).split(".")[-1].lower()};
            comptime for f in fields(ShoppingItem) {
                comptime if f.name != "unit" {
                    item[f.name] = get_field(ing, f.name);
                }
            }
            root ++> ShoppingItem(**item);
        }
        return [root-->][?:ShoppingItem];
    }

    """Get the current shopping list."""
    def:priv get_shopping_list -> list[ShoppingItem] {
        return [root-->][?:ShoppingItem];
    }

    """Clear the shopping list."""
    def:priv clear_shopping_list -> dict[str, bool] {
        for item in [root-->][?:ShoppingItem] {
            del item;
        }
        return {"cleared": True};
    }
    ```

??? note "Complete `frontend.jac`"

    ```jac
    """AI Day Planner -- top-level client app composes feature components."""

    import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

    import "./styles.css";

    import from .components.AuthForm { AuthForm }
    import from .components.Header { Header }
    import from .components.TasksPanel { TasksPanel }
    import from .components.ShoppingPanel { ShoppingPanel }

    def:pub app -> JsxElement {
        has isLoggedIn: bool = False,
            checkingAuth: bool = True;

        can with entry {
            isLoggedIn = jacIsLoggedIn();
            checkingAuth = False;
        }

        def handleAuth {
            isLoggedIn = True;
        }

        def handleLogout {
            jacLogout();
            isLoggedIn = False;
        }

        if checkingAuth {
            return
                <div class="auth-loading">Loading...</div>;
        }

        if isLoggedIn {
            return
                <div class="container">
                    <Header onLogout={handleLogout}/>
                    <div class="two-column">
                        <TasksPanel/>
                        <ShoppingPanel/>
                    </div>
                </div>;
        }

        return
            <AuthForm onAuth={handleAuth}/>;
    }
    ```

??? note "Complete `components/AuthForm.jac`"

    ```jac
    """Login / signup form -- owns its own form state.

    Calls `onAuth()` after a successful login or signup so the parent can
    flip the app into its logged-in state.
    """

    import from "@jac/runtime" { jacLogin, jacSignup }

    def:pub AuthForm(onAuth: Callable[[], None]) -> JsxElement {
        has isSignup: bool = False,
            username: str = "",
            password: str = "",
            error: str = "",
            loading: bool = False;

        async def handleLogin {
            error = "";
            if not username.strip() or not password {
                error = "Please fill in all fields";
                return;
            }
            loading = True;
            success = await jacLogin(username, password);
            loading = False;
            if success {
                onAuth();
            } else {
                error = "Invalid username or password";
            }
        }

        async def handleSignup {
            error = "";
            if not username.strip() or not password {
                error = "Please fill in all fields";
                return;
            }
            if len(password) < 4 {
                error = "Password must be at least 4 characters";
                return;
            }
            loading = True;
            result = await jacSignup(username, password);
            if result["success"] {
                # /user/register creates the account but does not return a
                # session token; sign in immediately to establish one.
                logged_in = await jacLogin(username, password);
                loading = False;
                if logged_in {
                    onAuth();
                } else {
                    error = "Account created but sign-in failed";
                }
            } else {
                loading = False;
                error = str(result["error"]) if result["error"] else "Signup failed";
            }
        }

        async def handleSubmit(e: FormEvent) {
            e.preventDefault();
            if isSignup {
                await handleSignup();
            } else {
                await handleLogin();
            }
        }

        return
            <div class="auth-container">
                <div class="auth-card">
                    <h1 class="auth-title">AI Day Planner</h1>
                    <p class="auth-subtitle">
                        {("Create your account" if isSignup else "Welcome back")}
                    </p>
                    {(<div class="auth-error">{error}</div>) if error else None}
                    <form onSubmit={handleSubmit}>
                        <div class="form-field">
                            <label class="form-label">Username</label>
                            <input
                                type="text"
                                value={username}
                                onChange={lambda (e: ChangeEvent) { username = e.target.value; }}
                                placeholder="Enter username"
                                class="auth-input"
                            />
                        </div>
                        <div class="form-field">
                            <label class="form-label">Password</label>
                            <input
                                type="password"
                                value={password}
                                onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                                placeholder="Enter password"
                                class="auth-input"
                            />
                        </div>
                        <button type="submit" disabled={loading} class="auth-submit">
                            {(
                                "Processing..."
                                    if loading
                                    else ("Create Account" if isSignup else "Sign In")
                            )}
                        </button>
                    </form>
                    <div class="auth-toggle">
                        <span class="auth-toggle-text">
                            {(
                                "Already have an account? "
                                    if isSignup
                                    else "Don't have an account? "
                            )}
                        </span>
                        <button
                            type="button"
                            onClick={lambda {
                                isSignup = not isSignup;
                                error = "";
                            }}
                            class="auth-toggle-btn"
                        >
                            {("Sign In" if isSignup else "Sign Up")}
                        </button>
                    </div>
                </div>
            </div>;
    }
    ```

??? note "Complete `components/Header.jac`"

    ```jac
    """App header with title, subtitle, and sign-out button."""

    def:pub Header(onLogout: Callable[[], None]) -> JsxElement {
        return
            <div class="header">
                <div>
                    <h1>AI Day Planner</h1>
                    <p class="subtitle">Task management with AI-powered meal planning</p>
                </div>
                <button class="btn-signout" onClick={onLogout}>Sign Out</button>
            </div>;
    }
    ```

??? note "Complete `components/TasksPanel.jac`"

    ```jac
    """Tasks column -- owns task list state, fetches on mount."""

    import from ..main { Task, get_tasks, add_task, toggle_task, delete_task }

    import from .TaskItem { TaskItem }

    def:pub TasksPanel -> JsxElement {
        has tasks: list[Task] = [],
            taskText: str = "",
            tasksLoading: bool = True;

        async can with entry {
            tasks = await get_tasks();
            tasksLoading = False;
        }

        async def addTask {
            if not taskText.strip() {
                return;
            }
            task = await add_task(taskText.strip());
            tasks = tasks + [task];
            taskText = "";
        }

        async def toggleTask(id: str) {
            updated = await toggle_task(id);
            if updated is not None {
                tasks = [updated if jid(t) == id else t for t in tasks];
            }
        }

        async def deleteTask(id: str) {
            await delete_task(id);
            tasks = [t for t in tasks if jid(t) != id];
        }

        def handleKeyPress(e: KeyboardEvent) {
            if e.key == "Enter" {
                addTask();
            }
        }

        remaining = len([t for t in tasks if not t.done]);

        return
            <div class="column">
                <h2>Today's Tasks</h2>
                <div class="input-row">
                    <input
                        class="input"
                        value={taskText}
                        onChange={lambda (e: ChangeEvent) { taskText = e.target.value; }}
                        onKeyPress={handleKeyPress}
                        placeholder="What needs to be done today?"
                    />
                    <button class="btn-add" onClick={lambda { addTask(); }}>Add</button>
                </div>
                {(<div class="loading-msg">Loading tasks...</div>)
                    if tasksLoading
                    else (
                        <div>
                            {(<div class="empty-msg">No tasks yet. Add one above!</div>)
                                if len(tasks) == 0
                                else (
                                    <div>
                                        {[
                                            <TaskItem
                                                key={jid(t)}
                                                task={t}
                                                onToggle={lambda { toggleTask(jid(t)); }}
                                                onDelete={lambda { deleteTask(jid(t)); }}
                                            /> for t in tasks
                                        ]}
                                    </div>
                                )}
                        </div>
                    )}
                <div class="count">
                    {remaining} {("task" if remaining == 1 else "tasks")} remaining
                </div>
            </div>;
    }
    ```

??? note "Complete `components/TaskItem.jac`"

    ```jac
    """Single task row -- presentational; toggle and delete are passed in."""

    import from ..main { Task }

    def:pub TaskItem(
        task: Task, onToggle: Callable[[], None], onDelete: Callable[[], None]
    ) -> JsxElement {
        return
            <div class="task-item">
                <input type="checkbox" checked={task.done} onChange={onToggle}/>
                <span class={"task-title " + ("task-done" if task.done else "")}>
                    {task.title}
                </span>
                {(<span class="category">{task.category}</span>)
                    if task.category and task.category != "other"
                    else None}
                <button class="btn-delete" onClick={onDelete}>X</button>
            </div>;
    }
    ```

??? note "Complete `components/ShoppingPanel.jac`"

    ```jac
    """Shopping list column -- owns ingredient state, fetches on mount."""

    import from ..main {
        ShoppingItem,
        generate_list,
        get_shopping_list,
        clear_shopping_list
    }

    import from .IngredientItem { IngredientItem }

    def:pub ShoppingPanel -> JsxElement {
        has ingredients: list[ShoppingItem] = [],
            mealText: str = "",
            generating: bool = False;

        async can with entry {
            ingredients = await get_shopping_list();
        }

        async def generateList {
            if not mealText.strip() {
                return;
            }
            generating = True;
            ingredients = await generate_list(mealText.strip());
            generating = False;
        }

        async def clearList {
            await clear_shopping_list();
            ingredients = [];
            mealText = "";
        }

        def handleKeyPress(e: KeyboardEvent) {
            if e.key == "Enter" {
                generateList();
            }
        }

        totalCost = 0.0;
        for ing in ingredients {
            totalCost = totalCost + ing.cost;
        }

        return
            <div class="column">
                <h2>Meal Shopping List</h2>
                <div class="input-row">
                    <input
                        class="input"
                        value={mealText}
                        onChange={lambda (e: ChangeEvent) { mealText = e.target.value; }}
                        onKeyPress={handleKeyPress}
                        placeholder="e.g. 'chicken stir fry for 4'"
                    />
                    <button
                        class="btn-generate"
                        onClick={lambda { generateList(); }}
                        disabled={generating}
                    >
                        {("Generating..." if generating else "Generate")}
                    </button>
                </div>
                {(<div class="generating-msg">Generating with AI...</div>)
                    if generating
                    else (
                        <div>
                            {(
                                <div class="empty-msg">
                                    Enter a meal above to generate ingredients.
                                </div>
                            )
                                if len(ingredients) == 0
                                else (
                                    <div>
                                        {[
                                            <IngredientItem key={ing.name} ing={ing}/>
                                            for ing in ingredients
                                        ]}
                                        <div class="shopping-footer">
                                            <span class="total">
                                                Total: ${f"{totalCost:.2f}"}
                                            </span>
                                            <button
                                                class="btn-clear"
                                                onClick={lambda { clearList(); }}
                                            >
                                                Clear
                                            </button>
                                        </div>
                                    </div>
                                )}
                        </div>
                    )}
            </div>;
    }
    ```

??? note "Complete `components/IngredientItem.jac`"

    ```jac
    """Single ingredient row -- presentational."""

    import from ..main { ShoppingItem }

    def:pub IngredientItem(ing: ShoppingItem) -> JsxElement {
        return
            <div class="ingredient-item">
                <div class="ing-info">
                    <span class="ing-name">{ing.name}</span>
                    <span class="ing-qty">{ing.quantity} {ing.unit}</span>
                </div>
                <div class="ing-meta">
                    {(<span class="carb-badge">Carbs</span>) if ing.carby else None}
                    <span class="ing-cost">${f"{ing.cost:.2f}"}</span>
                </div>
            </div>;
    }
    ```

??? note "Complete `styles.css`"

    ```css
    /* Base */
    .container { max-width: 900px; margin: 40px auto; font-family: system-ui; padding: 20px; }
    h1 { margin: 0; color: #333; }
    h2 { margin: 0 0 16px 0; font-size: 1.2rem; color: #444; }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
    .subtitle { margin: 4px 0 0 0; color: #888; font-size: 0.85rem; }

    /* Layout */
    .two-column { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
    @media (max-width: 700px) { .two-column { grid-template-columns: 1fr; } }

    /* Inputs */
    .input-row { display: flex; gap: 8px; margin-bottom: 16px; }
    .input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 1rem; }

    /* Buttons */
    .btn-add { padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }
    .btn-generate { padding: 10px 16px; background: #2196F3; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; white-space: nowrap; }
    .btn-generate:disabled { opacity: 0.6; cursor: not-allowed; }
    .btn-delete { background: #e53e3e; color: white; border: none; border-radius: 4px; padding: 4px 8px; cursor: pointer; font-size: 0.85rem; }
    .btn-clear { background: #888; color: white; border: none; border-radius: 4px; padding: 6px 12px; cursor: pointer; font-size: 0.85rem; }
    .btn-signout { padding: 8px 16px; background: #f5f5f5; color: #666; border: 1px solid #ddd; border-radius: 6px; cursor: pointer; }

    /* Task Items */
    .task-item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; gap: 10px; }
    .task-title { flex: 1; }
    .task-done { text-decoration: line-through; color: #888; }
    .category { padding: 2px 8px; background: #e8f5e9; border-radius: 12px; font-size: 0.75rem; color: #2e7d32; margin-right: 8px; }
    .count { text-align: center; color: #888; margin-top: 12px; font-size: 0.9rem; }

    /* Shopping Items */
    .ingredient-item { display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid #eee; }
    .ing-info { display: flex; flex-direction: column; gap: 2px; }
    .ing-name { font-weight: 500; }
    .ing-qty { color: #666; font-size: 0.85rem; }
    .ing-meta { display: flex; align-items: center; gap: 8px; }
    .ing-cost { color: #2196F3; font-weight: 600; }
    .carb-badge { padding: 2px 6px; background: #fff3e0; border-radius: 12px; font-size: 0.7rem; color: #e65100; }
    .shopping-footer { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; margin-top: 8px; border-top: 1px solid #ddd; }
    .total { font-weight: 700; color: #2196F3; }
    .generating-msg { text-align: center; padding: 20px; color: #666; }

    /* Status Messages */
    .loading-msg { text-align: center; padding: 20px; color: #888; }
    .empty-msg { text-align: center; padding: 30px; color: #888; }
    .auth-loading { display: flex; justify-content: center; align-items: center; min-height: 100vh; color: #888; font-family: system-ui; }

    /* Auth Form */
    .auth-container { min-height: 100vh; display: flex; align-items: center; justify-content: center; font-family: system-ui; background: #f5f5f5; }
    .auth-card { background: white; border-radius: 16px; padding: 2.5rem; width: 100%; max-width: 400px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }
    .auth-title { margin: 0 0 4px 0; text-align: center; font-size: 1.75rem; color: #333; }
    .auth-subtitle { margin: 0 0 24px 0; text-align: center; color: #888; font-size: 0.9rem; }
    .auth-error { margin-bottom: 16px; padding: 10px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; color: #dc2626; font-size: 0.9rem; }
    .form-field { margin-bottom: 16px; }
    .form-label { display: block; color: #555; font-size: 0.85rem; margin-bottom: 6px; }
    .auth-input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 8px; font-size: 1rem; box-sizing: border-box; }
    .auth-submit { width: 100%; padding: 12px; background: #4CAF50; color: white; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; margin-top: 8px; }
    .auth-submit:disabled { opacity: 0.6; }
    .auth-toggle { margin-top: 16px; text-align: center; }
    .auth-toggle-text { color: #888; font-size: 0.9rem; }
    .auth-toggle-btn { background: none; border: none; color: #4CAF50; font-weight: 600; cursor: pointer; font-size: 0.9rem; }
    ```

```bash
jac run main.jac    # builds and serves
```

Open [http://localhost:8000](http://localhost:8000). You should see a login screen.

1. **Sign up** with any username and password
2. **Add tasks** -- they auto-categorize just like Part 5
3. **Try the meal planner** -- type "spaghetti bolognese for 4" and click Generate
4. **Refresh the page** -- your data persists (it's in the graph)
5. **Log out and sign up as a different user** -- you'll see a completely empty app. Each user gets their own graph thanks to `def:priv`.
6. **Restart the server** -- all data persists for both users

!!! tip "Visualize per-user graphs"
    Visit [http://localhost:8000/graph](http://localhost:8000/graph) to see the graph for the currently logged-in user. Log in as different users and compare -- each has their own isolated graph with their own `root`, tasks, and shopping items.

Step back and consider what you've built: a **complete, fully functional application** with authentication, per-user data isolation, AI-powered categorization, meal planning, graph persistence, and a clean multi-file architecture. In a traditional stack, this would require a web framework, an ORM, a database, an authentication library, a frontend build system, and AI integration code. In Jac, it's built with `def:priv` endpoints, nodes, and edges.

**What You Learned**

- **`def:priv`** -- private endpoints with per-user data isolation (each user gets their own `root`)
- **`jacSignup`**, **`jacLogin`**, **`jacLogout`**, **`jacIsLoggedIn`** -- built-in auth functions
- **`import from "@jac/runtime"`** -- import Jac's built-in client-side utilities
- **Component files** -- each component in its own `.jac` file; the JSX makes it client code, nothing to annotate
- **`import from ..main { ... }`** -- bring server functions and node types into client files (the compiler bridges them over HTTP); the `..` is a relative import to the parent directory
- **Placement is inferred** -- the compiler places every declaration by its content; `[placement.pins]` in `jac.toml` is the override when you need one
- **`can with [deps] entry`** -- dependency-triggered abilities (re-run when state changes); useful when the component owning the dependency stays mounted
- **Optional: declaration/implementation split** -- `.jac` for state + render tree, `.impl.jac` for `impl Component.method { ... }` bodies; reach for it only when a single component is too long to read top-to-bottom

!!! example "Try It Yourself"
    Add a small `Footer` component (presentational, no state) that shows a copyright line. Place it in `components/Footer.jac`, import it into `frontend.jac`, and render it at the bottom of the logged-in container -- the same pattern as `Header`.

---

## Checkpoint

Use the complete files above, retaining assets and configuration from the previous lesson. Sign up as two different users and confirm that each sees their own tasks. Log out and verify that protected operations require authentication.

[Lesson overview](build-ai-day-planner.md) · [Previous lesson](day-planner-05-ai.md) · [Next lesson](day-planner-07-walkers.md)
