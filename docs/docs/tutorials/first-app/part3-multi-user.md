# Part 3: Walkers, Auth & Structure

Your todo app has AI, but everyone shares the same data. Time to fix that. You'll introduce **walkers** -- Jac's native pattern for per-user graph operations -- add **login/signup**, build a persistent **meal planner** with structured AI outputs, and organize the code into **multiple files**.

**Prerequisites:** Complete [Part 2](part2-ai-features.md) first.

---

## The Problem with Shared Data

In Parts 1 and 2, every `def:pub` function operates on the same `root` node. If two people use the app, they see each other's todos. That's fine for prototyping, but not for a real app.

**Walkers** solve this. A `walker:priv` requires authentication and operates on the logged-in user's *private* root node. User A's todos stay separate from User B's -- same code, isolated data, enforced by the runtime.

For a detailed comparison table of when to use functions vs walkers, see [Functions vs Walkers](../language/osp.md#when-to-use-functions-vs-walkers) in the OSP tutorial.

---

## Understanding Walkers

A walker is code that moves through the graph, triggering abilities as it enters each node:

```
Walker: ListTodos
  |
  v
[root] ---> [Todo: "Buy milk"]     <- walker enters, `with Todo entry` runs
  |-------> [Todo: "Write tests"]  <- walker enters, `with Todo entry` runs
  |-------> [Todo: "Call dentist"] <- walker enters, `with Todo entry` runs
```

The core keywords:

- **`visit [-->]`** -- move the walker to all connected nodes
- **`here`** -- the node the walker is currently on
- **`self`** -- the walker's own state (its `has` properties)
- **`report`** -- send data back to the caller

!!! warning "Common issue"
    If walker reports come back empty, make sure you have `visit [-->]` to send the walker to connected nodes, and that the node type in `with X entry` matches your graph. See [Troubleshooting: Walker reports are empty](../troubleshooting.md#walker-reports-are-empty).

---

## New Project Structure

Walkers live on the server, but the frontend needs to spawn them. Jac handles this with `sv import` -- server imports that the client uses to call walkers. This naturally leads to splitting your code into separate files.

Create a new project (this gives you a clean slate with no leftover data from Parts 1-2):

```bash
jac create my-todo-app --use client --skip
cd my-todo-app
```

You can delete the scaffolded `main.jac` and `components/Button.cl.jac` -- you'll replace them with the files below.

You'll create these files:

```
my-todo-app/
├── main.jac                    # Server: nodes, AI, walkers
├── frontend.cl.jac             # Client: state, UI, method declarations
├── frontend.impl.jac           # Client: method implementations
├── styles.css                  # Styles
└── components/
    ├── AuthForm.cl.jac         # Login/signup form
    ├── TodoItem.cl.jac         # Single todo display
    └── IngredientItem.cl.jac   # Single ingredient display
```

The **declaration/implementation split** (`frontend.cl.jac` + `frontend.impl.jac`) is a Jac pattern for keeping UI and logic separate. The `.cl.jac` file has state, method signatures, and the render tree. The `.impl.jac` file has the method bodies. It's optional -- you could put everything in one file -- but it keeps things readable as the app grows.

---

## Build the Server (`main.jac`)

The server file has three sections: the app entry point, AI types and functions, and walkers.

### Entry Point and Imports

```jac
"""TaskFlow - A multi-user todo app with AI meal planning."""

cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}

import from byllm.lib { Model }
import from uuid { uuid4 }

glob llm = Model(model_name="claude-sonnet-4-20250514");
```

The `cl { }` block is client-side code embedded in a server file. It imports the frontend component and makes it the app's entry point. Everything outside `cl { }` runs on the server.

### Data Models

You already know `Todo` from Parts 1 and 2. Note the field rename from `done` to `completed` -- this aligns with the walker convention used throughout Part 3. Now add `MealIngredient` -- a node that persists generated ingredients to the graph (unlike Part 2 where they only existed in browser memory):

```jac
node Todo {
    has id: str,
        title: str,
        completed: bool = False,
        category: str = "other";
}

node MealIngredient {
    has name: str,
        quantity: float,
        unit: str,
        cost: float,
        carby: bool;
}
```

### AI Types and Functions

The `Category` enum and `categorize` function carry over from Part 2. The new additions are for the meal planner -- structured types that tell the LLM exactly what shape to return:

```jac
enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, CLOVE, BUNCH }

obj Ingredient {
    has name: str;
    has quantity: float;
    has unit: Unit;
    has cost: float;
    has carby: bool;
}

sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient is high in carbohydrates";
```

Three new concepts here:

- **`obj Ingredient`** -- a structured data type with typed fields. Unlike `node`, objects aren't stored in the graph -- they're just data containers.
- **`sem Ingredient.cost = "..."`** -- a semantic hint that tells the LLM what a field means. Without it, `cost: float` is ambiguous. With the hint, the LLM knows to estimate USD prices.
- **`enum Unit`** -- constrains ingredient units to specific values, just like `Category` constrains todo categories.

And the two AI functions:

```jac
"""Categorize a todo based on its title."""
def categorize(title: str) -> Category by llm();

"""Generate a shopping list of ingredients needed for a described meal."""
def generate_ingredients(meal_description: str) -> list[Ingredient] by llm();
```

`generate_ingredients` returns a `list[Ingredient]` -- the LLM produces a list of typed objects, each with name, quantity, unit, cost, and carb flag. Jac validates the structure automatically.

### Todo Walkers

Now for the walkers. Here's `AddTodo` -- compare it to the `def:pub add_todo` from Part 2:

```jac
walker:priv AddTodo {
    has title: str;

    can create with `root entry {
        category = str(categorize(self.title)).split(".")[-1].lower();
        new_todo = here ++> Todo(
            id=str(uuid4()),
            title=self.title,
            category=category
        );
        report {
            "id": new_todo[0].id,
            "title": new_todo[0].title,
            "completed": new_todo[0].completed,
            "category": new_todo[0].category
        };
    }
}
```

Line by line:

- **`walker:priv AddTodo`** -- a private walker. Only authenticated users can spawn it, and it runs on their personal root node.
- **`has title: str`** -- a parameter you pass when spawning the walker.
- **`` can create with `root entry ``** -- this ability fires when the walker enters the root node.
- **`here`** -- refers to the current node (root). This is what `root` was in `def:pub` functions.
- **`self.title`** -- accesses the walker's own properties.
- **`report { ... }`** -- sends data back to whoever spawned this walker.

The `ListTodos` walker shows the **accumulator pattern** -- a common walker idiom:

```jac
walker:priv ListTodos {
    has todos: list = [];

    can collect with `root entry {
        visit [-->];
    }

    can gather with Todo entry {
        self.todos.append({
            "id": here.id,
            "title": here.title,
            "completed": here.completed,
            "category": here.category
        });
    }

    can report_all with `root exit {
        report self.todos;
    }
}
```

Three abilities work together:

1. **Enter root** → `visit [-->]` sends the walker to all connected nodes
2. **Enter each Todo** → `with Todo entry` fires, appending data to `self.todos`
3. **Exit root** → after visiting all children, the walker returns to root and reports the accumulated list

The walker's `has todos: list = []` state persists across the entire traversal -- that's how it collects results from multiple nodes.

`ToggleTodo` and `DeleteTodo` follow the same visit-then-act pattern:

```jac
walker:priv ToggleTodo {
    has todo_id: str;

    can search with `root entry { visit [-->]; }

    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.completed = not here.completed;
            report {"id": here.id, "completed": here.completed};
        }
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can search with `root entry { visit [-->]; }

    can delete with Todo entry {
        if here.id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}
```

Both visit all nodes from root, then act only on the matching Todo.

### Meal Planner Walkers

The `GenerateShoppingList` walker is interesting because it does two things in one traversal:

```jac
walker:priv GenerateShoppingList {
    has meal_description: str;

    can generate with `root entry {
        # First clear old ingredients
        visit [-->];
        # Then generate new ones
        ingredients = generate_ingredients(self.meal_description);
        result: list = [];
        for ing in ingredients {
            ing_data = {
                "name": ing.name,
                "quantity": ing.quantity,
                "unit": str(ing.unit).split(".")[-1].lower(),
                "cost": ing.cost,
                "carby": ing.carby
            };
            here ++> MealIngredient(
                name=ing_data["name"],
                quantity=ing_data["quantity"],
                unit=ing_data["unit"],
                cost=ing_data["cost"],
                carby=ing_data["carby"]
            );
            result.append(ing_data);
        }
        report result;
    }

    can clear_old with MealIngredient entry {
        del here;
    }
}
```

When `visit [-->]` runs, the walker visits all connected nodes. If any are `MealIngredient` nodes, `clear_old` fires and deletes them. Then control returns to root, where the walker generates fresh ingredients via the LLM and persists them as new nodes.

`ListMealPlan` and `ClearMealPlan` complete the set -- they follow the same accumulator and visit-delete patterns you've already seen:

```jac
walker:priv ListMealPlan {
    has ingredients: list = [];

    can collect with `root entry { visit [-->]; }

    can gather with MealIngredient entry {
        self.ingredients.append({
            "name": here.name, "quantity": here.quantity,
            "unit": here.unit, "cost": here.cost, "carby": here.carby
        });
    }

    can report_all with `root exit { report self.ingredients; }
}

walker:priv ClearMealPlan {
    can collect with `root entry { visit [-->]; }

    can clear with MealIngredient entry {
        del here;
        report {"cleared": True};
    }
}
```

---

## Build the Frontend

The frontend is split into two files: declarations and implementations.

### State and Imports (`frontend.cl.jac`)

The top of the file sets up imports:

```jac
"""Todo App - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.TodoItem { TodoItem }
import from .components.AuthForm { AuthForm }
import from .components.IngredientItem { IngredientItem }

sv import from main {
    AddTodo, ListTodos, ToggleTodo, DeleteTodo,
    GenerateShoppingList, ListMealPlan, ClearMealPlan
}
```

Two new import styles:

- **`import from "@jac/runtime" { jacLogin, ... }`** -- built-in auth functions that handle token management automatically
- **`sv import from main { AddTodo, ... }`** -- import server walkers so you can spawn them from client code

The component declares its state and method signatures:

```jac
def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        todos: list = [],
        newTodoText: str = "",
        todosLoading: bool = True,
        mealInput: str = "",
        ingredients: list = [],
        ingredientsLoading: bool = False;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchTodos();
            fetchMealPlan();
        }
    }

    # Method declarations -- bodies are in frontend.impl.jac
    async def fetchTodos -> None;
    async def addTodo -> None;
    async def toggleTodo(todoId: str) -> None;
    async def deleteTodo(todoId: str) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;
    def handleTodoKeyPress(e: any) -> None;
    async def fetchMealPlan -> None;
    async def generateIngredients -> None;
    async def clearIngredients -> None;
    def handleMealKeyPress(e: any) -> None;
    def getIngredientsTotal -> float;

    # ... UI rendering follows ...
}
```

A few things to notice:

**`can with [isLoggedIn] entry`** is a dependency-triggered ability. It re-runs whenever `isLoggedIn` changes -- similar to React's `useEffect` with a dependency array. When the user logs in, it automatically fetches their data.

**`async def fetchTodos -> None;`** -- method declarations with no body, just a semicolon. Their implementations live in `frontend.impl.jac`. This keeps the UI file focused on layout.

The render tree shows either a login form or the main app based on auth state. If logged in, it renders a two-column layout with todos on the left and the meal planner on the right. The full rendering code is in the collapsible file below.

### Method Implementations (`frontend.impl.jac`)

Here's where walkers get spawned. Each `impl` block provides the body for a declared method:

```jac
impl app.fetchTodos -> None {
    todosLoading = True;
    result = root spawn ListTodos();
    todos = result.reports[0] if result.reports else [];
    todosLoading = False;
}

impl app.addTodo -> None {
    if not newTodoText.trim() { return; }
    response = root spawn AddTodo(title=newTodoText);
    newTodo = response.reports[0];
    todos = todos.concat([{
        "id": newTodo.id,
        "title": newTodo.title,
        "completed": newTodo.completed,
        "category": newTodo.category
    }]);
    newTodoText = "";
}
```

The key pattern: **`root spawn Walker(params)`** creates a walker and starts it at the user's root node. The walker traverses the graph, and whatever it `report`s ends up in `result.reports`. Since most walkers report once, you grab `result.reports[0]`.

Toggle and delete follow the same pattern:

```jac
impl app.toggleTodo(todoId: str) -> None {
    root spawn ToggleTodo(todo_id=todoId);
    todos = todos.map(
        lambda t: any -> any {
            if t.id == todoId {
                return {
                    "id": t.id, "title": t.title,
                    "completed": not t.completed, "category": t.category
                };
            }
            return t;
        }
    );
}

impl app.deleteTodo(todoId: str) -> None {
    root spawn DeleteTodo(todo_id=todoId);
    todos = todos.filter(
        lambda t: any -> bool { return t.id != todoId; }
    );
}
```

Authentication uses the built-in `jacLogin`, `jacSignup`, and `jacLogout` functions:

```jac
impl app.handleLogin -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    loading = True;
    success = await jacLogin(username, password);
    loading = False;
    if success {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = "Invalid username or password";
    }
}

impl app.handleSignup -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    if password.length < 4 {
        error = "Password must be at least 4 characters";
        return;
    }
    loading = True;
    result = await jacSignup(username, password);
    loading = False;
    if result["success"] {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = result["error"] if result["error"] else "Signup failed";
    }
}

impl app.handleLogout -> None {
    jacLogout();
    isLoggedIn = False;
    todos = [];
    ingredients = [];
    mealInput = "";
}
```

These handle token management automatically -- you don't deal with JWTs or session storage.

The meal planner methods spawn walkers just like the todo methods:

```jac
impl app.fetchMealPlan -> None {
    result = root spawn ListMealPlan();
    ingredients = result.reports[0] if result.reports else [];
}

impl app.generateIngredients -> None {
    if not mealInput.trim() { return; }
    ingredientsLoading = True;
    result = root spawn GenerateShoppingList(meal_description=mealInput);
    ingredients = result.reports[0] if result.reports else [];
    ingredientsLoading = False;
}

impl app.clearIngredients -> None {
    root spawn ClearMealPlan();
    ingredients = [];
    mealInput = "";
}
```

The remaining utility methods:

```jac
impl app.handleSubmit(e: any) -> None {
    e.preventDefault();
    if isSignup { await handleSignup(); }
    else { await handleLogin(); }
}

impl app.handleTodoKeyPress(e: any) -> None {
    if e.key == "Enter" { addTodo(); }
}

impl app.handleMealKeyPress(e: any) -> None {
    if e.key == "Enter" { generateIngredients(); }
}

impl app.getIngredientsTotal -> float {
    total = 0.0;
    for ing in ingredients { total = total + ing.cost; }
    return total;
}
```

---

## Components

Components in Jac are functions that return JSX. Extract them when a piece of UI gets reused or when a file gets too long. Each component lives in `components/` with a `.cl.jac` extension.

### `components/TodoItem.cl.jac`

Displays a single todo with toggle and delete:

```jac
"""Todo item component."""

def:pub TodoItem(todo: dict, onToggle: any, onDelete: any) -> any {
    return
        <div className="todo-item">
            <input
                type="checkbox"
                checked={todo.completed}
                onChange={lambda -> None { onToggle(todo.id); }}
                className="todo-checkbox"
            />
            <span className={("todo-title-completed" if todo.completed else "todo-title")}>
                {todo.title}
            </span>
            {(
                <span className="category-badge">{todo.category}</span>
            ) if todo.category and todo.category != "other" else None}
            <button
                onClick={lambda -> None { onDelete(todo.id); }}
                className="todo-delete-btn"
            >
                ×
            </button>
        </div>;
}
```

### `components/IngredientItem.cl.jac`

Displays a single ingredient with cost and carb badge:

```jac
"""Ingredient item component for the shopping list."""

def:pub IngredientItem(ingredient: dict) -> any {
    return
        <div className="ingredient-item">
            <div className="ingredient-info">
                <span className="ingredient-name">{ingredient.name}</span>
                <span className="ingredient-qty">
                    {ingredient.quantity} {ingredient.unit}
                </span>
            </div>
            <div className="ingredient-meta">
                {(
                    <span className="carb-badge">Carbs</span>
                ) if ingredient.carby else None}
                <span className="cost-label">${ingredient.cost.toFixed(2)}</span>
            </div>
        </div>;
}
```

### `components/AuthForm.cl.jac`

A login/signup form. It's the longest component, so here's the structure -- the full code is in the collapsible below:

```jac
"""Authentication form component."""

def:pub AuthForm(
    isSignup: bool, username: str, password: str,
    error: str, loading: bool,
    onUsernameChange: any, onPasswordChange: any,
    onSubmit: any, onToggleMode: any
) -> any {
    return
        <div className="auth-container">
            <div className="auth-card">
                <h1 className="auth-title">TaskFlow</h1>
                {(<div className="auth-error">{error}</div>) if error else None}
                <form onSubmit={onSubmit}>
                    {"... username input, password input, submit button ..."}
                </form>
                <button onClick={onToggleMode}>
                    {("Sign In" if isSignup else "Sign Up")}
                </button>
            </div>
        </div>;
}
```

---

## Run It

All the complete files are in the collapsible sections below. Create each file in the project, then run.

??? note "Complete `main.jac`"

    ```jac
    """TaskFlow - A multi-user todo app with AI meal planning."""

    cl {
        import from frontend { app as ClientApp }

        def:pub app -> any {
            return
                <ClientApp />;
        }
    }

    import from byllm.lib { Model }
    import from uuid { uuid4 }

    glob llm = Model(model_name="claude-sonnet-4-20250514");

    # --- AI Types ---

    enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

    enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, CLOVE, BUNCH }

    obj Ingredient {
        has name: str;
        has quantity: float;
        has unit: Unit;
        has cost: float;
        has carby: bool;
    }

    sem Ingredient.cost = "Estimated cost in USD";
    sem Ingredient.carby = "True if this ingredient is high in carbohydrates";

    """Categorize a todo based on its title."""
    def categorize(title: str) -> Category by llm();

    """Generate a shopping list of ingredients needed for a described meal."""
    def generate_ingredients(meal_description: str) -> list[Ingredient] by llm();

    # --- Data Nodes ---

    node Todo {
        has id: str,
            title: str,
            completed: bool = False,
            category: str = "other";
    }

    node MealIngredient {
        has name: str,
            quantity: float,
            unit: str,
            cost: float,
            carby: bool;
    }

    # --- Todo Walkers ---

    walker:priv AddTodo {
        has title: str;

        can create with `root entry {
            category = str(categorize(self.title)).split(".")[-1].lower();
            new_todo = here ++> Todo(
                id=str(uuid4()),
                title=self.title,
                category=category
            );
            report {
                "id": new_todo[0].id,
                "title": new_todo[0].title,
                "completed": new_todo[0].completed,
                "category": new_todo[0].category
            };
        }
    }

    walker:priv ListTodos {
        has todos: list = [];

        can collect with `root entry {
            visit [-->];
        }

        can gather with Todo entry {
            self.todos.append({
                "id": here.id,
                "title": here.title,
                "completed": here.completed,
                "category": here.category
            });
        }

        can report_all with `root exit {
            report self.todos;
        }
    }

    walker:priv ToggleTodo {
        has todo_id: str;

        can search with `root entry {
            visit [-->];
        }

        can toggle with Todo entry {
            if here.id == self.todo_id {
                here.completed = not here.completed;
                report {
                    "id": here.id,
                    "completed": here.completed
                };
            }
        }
    }

    walker:priv DeleteTodo {
        has todo_id: str;

        can search with `root entry {
            visit [-->];
        }

        can delete with Todo entry {
            if here.id == self.todo_id {
                del here;
                report {"deleted": self.todo_id};
            }
        }
    }

    # --- Meal Planner Walkers ---

    walker:priv GenerateShoppingList {
        has meal_description: str;

        can generate with `root entry {
            # First clear old ingredients
            visit [-->];
            # Then generate new ones
            ingredients = generate_ingredients(self.meal_description);
            result: list = [];
            for ing in ingredients {
                ing_data = {
                    "name": ing.name,
                    "quantity": ing.quantity,
                    "unit": str(ing.unit).split(".")[-1].lower(),
                    "cost": ing.cost,
                    "carby": ing.carby
                };
                here ++> MealIngredient(
                    name=ing_data["name"],
                    quantity=ing_data["quantity"],
                    unit=ing_data["unit"],
                    cost=ing_data["cost"],
                    carby=ing_data["carby"]
                );
                result.append(ing_data);
            }
            report result;
        }

        can clear_old with MealIngredient entry {
            del here;
        }
    }

    walker:priv ListMealPlan {
        has ingredients: list = [];

        can collect with `root entry {
            visit [-->];
        }

        can gather with MealIngredient entry {
            self.ingredients.append({
                "name": here.name,
                "quantity": here.quantity,
                "unit": here.unit,
                "cost": here.cost,
                "carby": here.carby
            });
        }

        can report_all with `root exit {
            report self.ingredients;
        }
    }

    walker:priv ClearMealPlan {
        can collect with `root entry {
            visit [-->];
        }

        can clear with MealIngredient entry {
            del here;
            report {"cleared": True};
        }
    }
    ```

??? note "Complete `frontend.cl.jac`"

    ```jac
    """Todo App - Client-Side UI."""

    import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

    import "./styles.css";

    import from .components.TodoItem { TodoItem }
    import from .components.AuthForm { AuthForm }
    import from .components.IngredientItem { IngredientItem }

    sv import from main {
        AddTodo, ListTodos, ToggleTodo, DeleteTodo,
        GenerateShoppingList, ListMealPlan, ClearMealPlan
    }

    def:pub app -> any {
        has isLoggedIn: bool = False,
            checkingAuth: bool = True,
            isSignup: bool = False,
            username: str = "",
            password: str = "",
            error: str = "",
            loading: bool = False,
            todos: list = [],
            newTodoText: str = "",
            todosLoading: bool = True,
            mealInput: str = "",
            ingredients: list = [],
            ingredientsLoading: bool = False;

        can with entry {
            isLoggedIn = jacIsLoggedIn();
            checkingAuth = False;
        }

        can with [isLoggedIn] entry {
            if isLoggedIn {
                fetchTodos();
                fetchMealPlan();
            }
        }

        # Method declarations (implementations in frontend.impl.jac)
        async def fetchTodos -> None;
        async def addTodo -> None;
        async def toggleTodo(todoId: str) -> None;
        async def deleteTodo(todoId: str) -> None;
        async def handleLogin -> None;
        async def handleSignup -> None;
        def handleLogout -> None;
        async def handleSubmit(e: any) -> None;
        def handleTodoKeyPress(e: any) -> None;
        async def fetchMealPlan -> None;
        async def generateIngredients -> None;
        async def clearIngredients -> None;
        def handleMealKeyPress(e: any) -> None;
        def getIngredientsTotal -> float;

        if checkingAuth {
            return
                <div style={{"display": "flex", "justifyContent": "center",
                             "alignItems": "center", "minHeight": "100vh",
                             "color": "rgba(255,255,255,0.6)", "fontFamily": "system-ui"}}>
                    Loading...
                </div>;
        }

        if isLoggedIn {
            totalCost = getIngredientsTotal();
            return
                <div className="app-container">
                    <div className="app-content">
                        <div className="card">
                            <div className="card-header">
                                <div>
                                    <h1 className="app-title">TaskFlow</h1>
                                    <p className="app-subtitle">
                                        Todo list with AI meal planning
                                    </p>
                                </div>
                                <button onClick={handleLogout} className="btn-signout">
                                    Sign Out
                                </button>
                            </div>
                        </div>
                        <div className="two-column-layout">
                            <div className="column-left">
                                <div className="card">
                                    <div className="add-row">
                                        <input
                                            type="text"
                                            value={newTodoText}
                                            onChange={lambda e: any -> None { newTodoText = e.target.value; }}
                                            onKeyPress={handleTodoKeyPress}
                                            placeholder="What needs to be done?"
                                            className="todo-input"
                                        />
                                        <button
                                            onClick={lambda -> None { addTodo(); }}
                                            className="btn-add"
                                        >
                                            Add
                                        </button>
                                    </div>
                                </div>
                                <div className="card">
                                    {(
                                        <div className="loading-message">Loading tasks...</div>
                                    ) if todosLoading else (
                                        <div>
                                            {(
                                                <div className="empty-message">
                                                    No tasks yet. Add one above!
                                                </div>
                                            ) if todos.length == 0 else (
                                                <div>
                                                    {[
                                                        <TodoItem
                                                            key={todo.id}
                                                            todo={todo}
                                                            onToggle={toggleTodo}
                                                            onDelete={deleteTodo}
                                                        /> for todo in todos
                                                    ]}
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                                <div className="remaining-count">
                                    {todos.filter(
                                        lambda t: any -> bool { return not t.completed; }
                                    ).length} items remaining
                                </div>
                            </div>
                            <div className="column-right">
                                <div className="card">
                                    <h2 className="panel-title">Meal Planner</h2>
                                    <p className="panel-subtitle">
                                        Describe a meal to generate a shopping list
                                    </p>
                                    <div className="add-row">
                                        <input
                                            type="text"
                                            value={mealInput}
                                            onChange={lambda e: any -> None { mealInput = e.target.value; }}
                                            onKeyPress={handleMealKeyPress}
                                            placeholder="e.g. spaghetti bolognese for 4"
                                            className="todo-input"
                                        />
                                        <button
                                            onClick={lambda -> None { generateIngredients(); }}
                                            disabled={ingredientsLoading}
                                            className="btn-generate"
                                        >
                                            {("Generating..." if ingredientsLoading else "Generate")}
                                        </button>
                                    </div>
                                </div>
                                <div className="card">
                                    {(
                                        <div className="loading-message">
                                            <div className="generating-spinner"></div>
                                            Generating shopping list with AI...
                                        </div>
                                    ) if ingredientsLoading else (
                                        <div>
                                            {(
                                                <div className="empty-message">
                                                    Enter a meal above to generate ingredients.
                                                </div>
                                            ) if ingredients.length == 0 else (
                                                <div>
                                                    {[
                                                        <IngredientItem
                                                            key={ing.name}
                                                            ingredient={ing}
                                                        /> for ing in ingredients
                                                    ]}
                                                    <div className="ingredients-footer">
                                                        <div className="ingredients-total">
                                                            Total: ${totalCost.toFixed(2)}
                                                        </div>
                                                        <button
                                                            onClick={lambda -> None { clearIngredients(); }}
                                                            className="btn-clear"
                                                        >
                                                            Clear
                                                        </button>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>;
        }

        return
            <AuthForm
                isSignup={isSignup}
                username={username}
                password={password}
                error={error}
                loading={loading}
                onUsernameChange={lambda e: any -> None { username = e.target.value; }}
                onPasswordChange={lambda e: any -> None { password = e.target.value; }}
                onSubmit={handleSubmit}
                onToggleMode={lambda -> None { isSignup = not isSignup; error = ""; }}
            />;
    }
    ```

??? note "Complete `frontend.impl.jac`"

    ```jac
    """Implementations for the Todo App frontend component."""

    impl app.fetchTodos -> None {
        todosLoading = True;
        result = root spawn ListTodos();
        todos = result.reports[0] if result.reports else [];
        todosLoading = False;
    }

    impl app.addTodo -> None {
        if not newTodoText.trim() { return; }
        response = root spawn AddTodo(title=newTodoText);
        newTodo = response.reports[0];
        todos = todos.concat([{
            "id": newTodo.id,
            "title": newTodo.title,
            "completed": newTodo.completed,
            "category": newTodo.category
        }]);
        newTodoText = "";
    }

    impl app.toggleTodo(todoId: str) -> None {
        root spawn ToggleTodo(todo_id=todoId);
        todos = todos.map(
            lambda t: any -> any {
                if t.id == todoId {
                    return {
                        "id": t.id, "title": t.title,
                        "completed": not t.completed, "category": t.category
                    };
                }
                return t;
            }
        );
    }

    impl app.deleteTodo(todoId: str) -> None {
        root spawn DeleteTodo(todo_id=todoId);
        todos = todos.filter(
            lambda t: any -> bool { return t.id != todoId; }
        );
    }

    impl app.handleLogin -> None {
        error = "";
        if not username.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        loading = True;
        success = await jacLogin(username, password);
        loading = False;
        if success {
            isLoggedIn = True;
            username = "";
            password = "";
        } else {
            error = "Invalid username or password";
        }
    }

    impl app.handleSignup -> None {
        error = "";
        if not username.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        if password.length < 4 {
            error = "Password must be at least 4 characters";
            return;
        }
        loading = True;
        result = await jacSignup(username, password);
        loading = False;
        if result["success"] {
            isLoggedIn = True;
            username = "";
            password = "";
        } else {
            error = result["error"] if result["error"] else "Signup failed";
        }
    }

    impl app.handleLogout -> None {
        jacLogout();
        isLoggedIn = False;
        todos = [];
        ingredients = [];
        mealInput = "";
    }

    impl app.handleSubmit(e: any) -> None {
        e.preventDefault();
        if isSignup {
            await handleSignup();
        } else {
            await handleLogin();
        }
    }

    impl app.handleTodoKeyPress(e: any) -> None {
        if e.key == "Enter" { addTodo(); }
    }

    impl app.fetchMealPlan -> None {
        result = root spawn ListMealPlan();
        ingredients = result.reports[0] if result.reports else [];
    }

    impl app.generateIngredients -> None {
        if not mealInput.trim() { return; }
        ingredientsLoading = True;
        result = root spawn GenerateShoppingList(meal_description=mealInput);
        ingredients = result.reports[0] if result.reports else [];
        ingredientsLoading = False;
    }

    impl app.clearIngredients -> None {
        root spawn ClearMealPlan();
        ingredients = [];
        mealInput = "";
    }

    impl app.handleMealKeyPress(e: any) -> None {
        if e.key == "Enter" { generateIngredients(); }
    }

    impl app.getIngredientsTotal -> float {
        total = 0.0;
        for ing in ingredients {
            total = total + ing.cost;
        }
        return total;
    }
    ```

??? note "Complete `components/AuthForm.cl.jac`"

    ```jac
    """Authentication form component."""

    def:pub AuthForm(
        isSignup: bool,
        username: str,
        password: str,
        error: str,
        loading: bool,
        onUsernameChange: any,
        onPasswordChange: any,
        onSubmit: any,
        onToggleMode: any
    ) -> any {
        return
            <div className="auth-container">
                <div className="auth-card">
                    <div className="auth-header">
                        <div className="auth-logo">
                            TaskFlow
                        </div>
                        <h1 className="auth-title">TaskFlow</h1>
                        <p className="auth-subtitle">
                            {("Create your account" if isSignup else "Welcome back")}
                        </p>
                    </div>
                    {(
                        <div className="auth-error">{error}</div>
                    ) if error else None}
                    <form onSubmit={onSubmit}>
                        <div className="form-field">
                            <label className="form-label">Username</label>
                            <input
                                type="text"
                                value={username}
                                onChange={onUsernameChange}
                                placeholder="Enter username"
                                className="auth-input"
                            />
                        </div>
                        <div className="form-field-last">
                            <label className="form-label">Password</label>
                            <input
                                type="password"
                                value={password}
                                onChange={onPasswordChange}
                                placeholder="Enter password"
                                className="auth-input"
                            />
                        </div>
                        <button type="submit" disabled={loading} className="auth-submit">
                            {(
                                "Processing..."
                                if loading
                                else ("Create Account" if isSignup else "Sign In")
                            )}
                        </button>
                    </form>
                    <div className="auth-toggle">
                        <span className="auth-toggle-text">
                            {(
                                "Already have an account? "
                                if isSignup
                                else "Don't have an account? "
                            )}
                        </span>
                        <button
                            type="button"
                            onClick={onToggleMode}
                            className="auth-toggle-btn"
                        >
                            {("Sign In" if isSignup else "Sign Up")}
                        </button>
                    </div>
                </div>
            </div>;
    }
    ```

??? note "Complete `components/TodoItem.cl.jac`"

    ```jac
    """Todo item component."""

    def:pub TodoItem(todo: dict, onToggle: any, onDelete: any) -> any {
        return
            <div className="todo-item">
                <input
                    type="checkbox"
                    checked={todo.completed}
                    onChange={lambda -> None { onToggle(todo.id); }}
                    className="todo-checkbox"
                />
                <span className={("todo-title-completed" if todo.completed else "todo-title")}>
                    {todo.title}
                </span>
                {(
                    <span className="category-badge">{todo.category}</span>
                ) if todo.category and todo.category != "other" else None}
                <button
                    onClick={lambda -> None { onDelete(todo.id); }}
                    className="todo-delete-btn"
                >
                    ×
                </button>
            </div>;
    }
    ```

??? note "Complete `components/IngredientItem.cl.jac`"

    ```jac
    """Ingredient item component for the shopping list."""

    def:pub IngredientItem(ingredient: dict) -> any {
        return
            <div className="ingredient-item">
                <div className="ingredient-info">
                    <span className="ingredient-name">{ingredient.name}</span>
                    <span className="ingredient-qty">
                        {ingredient.quantity} {ingredient.unit}
                    </span>
                </div>
                <div className="ingredient-meta">
                    {(
                        <span className="carb-badge">Carbs</span>
                    ) if ingredient.carby else None}
                    <span className="cost-label">${ingredient.cost.toFixed(2)}</span>
                </div>
            </div>;
    }
    ```

??? note "Complete `styles.css`"

    ```css
    /* Base / Reset */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; border: 0; }

    html { margin: 0; padding: 0; background: #0a0a0a; }

    body {
        margin: 0 !important; padding: 0 !important;
        font-family: system-ui, -apple-system, sans-serif;
        background: linear-gradient(135deg, #0a0a0a 0%, #151010 50%, #0a0a0a 100%);
        min-height: 100vh;
        -webkit-font-smoothing: antialiased;
    }

    /* App Layout */
    .app-container {
        min-height: 100vh; position: absolute; top: 0; left: 0; right: 0; bottom: 0;
        background: linear-gradient(135deg, #0a0a0a 0%, #151010 50%, #0a0a0a 100%);
        padding: 2rem; font-family: system-ui, -apple-system, sans-serif; overflow: auto;
    }

    .app-content { max-width: 1200px; margin: 0 auto; display: flex; flex-direction: column; gap: 1.5rem; }

    /* Card */
    .card {
        background: rgba(25, 20, 20, 0.95); border-radius: 16px;
        border: 1px solid rgba(200, 80, 50, 0.2); padding: 1.5rem;
    }

    /* Header */
    .card-header { display: flex; justify-content: space-between; align-items: center; }
    .app-title { margin: 0; color: white; font-size: 1.75rem; }
    .app-subtitle { margin: 0.25rem 0 0 0; color: rgba(255, 255, 255, 0.5); font-size: 0.85rem; }

    /* Buttons */
    .btn-signout {
        padding: 0.5rem 1rem; background: rgba(200, 80, 50, 0.15); color: #d45a30;
        border: 1px solid rgba(200, 80, 50, 0.3); border-radius: 8px; cursor: pointer;
    }
    .btn-add {
        padding: 0.75rem 1.5rem; background: linear-gradient(135deg, #d45a30, #a33d1a);
        color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: 600;
    }

    /* Form */
    .add-row { display: flex; gap: 0.75rem; margin-bottom: 1rem; }
    .todo-input {
        flex: 1; padding: 0.75rem 1rem; background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(200, 80, 50, 0.2); border-radius: 8px; color: white;
        font-size: 1rem; outline: none;
    }

    /* Status Messages */
    .loading-message { text-align: center; padding: 2rem; color: rgba(255, 255, 255, 0.6); }
    .empty-message { text-align: center; padding: 3rem; color: rgba(255, 255, 255, 0.6); }
    .remaining-count { text-align: center; color: rgba(212, 90, 48, 0.7); font-size: 0.85rem; }

    /* Todo Item */
    .todo-item {
        display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem;
        background: rgba(255, 255, 255, 0.03); border-radius: 10px;
        border: 1px solid rgba(200, 80, 50, 0.15); margin-bottom: 0.5rem;
    }
    .todo-checkbox { width: 18px; height: 18px; cursor: pointer; accent-color: #d45a30; }
    .todo-title { flex: 1; color: rgba(255, 255, 255, 0.9); }
    .todo-title-completed { flex: 1; color: rgba(255, 255, 255, 0.4); text-decoration: line-through; }
    .category-badge {
        padding: 0.15rem 0.5rem; border-radius: 10px; font-size: 0.65rem; font-weight: 600;
        text-transform: uppercase; background: rgba(200, 80, 50, 0.13); color: #d45a30;
        border: 1px solid rgba(200, 80, 50, 0.27);
    }
    .todo-delete-btn {
        background: none; border: none; color: rgba(200, 80, 50, 0.5);
        cursor: pointer; padding: 0.25rem; font-size: 1.2rem;
    }

    /* Auth Form */
    .auth-container {
        min-height: 100vh; position: absolute; top: 0; left: 0; right: 0; bottom: 0; padding: 1rem;
        display: flex; align-items: center; justify-content: center;
        background: linear-gradient(135deg, #0a0a0a 0%, #151010 50%, #0a0a0a 100%);
        font-family: system-ui, -apple-system, sans-serif;
    }
    .auth-card {
        background: rgba(25, 20, 20, 0.95); border-radius: 20px;
        border: 1px solid rgba(200, 80, 50, 0.2); padding: 2.5rem; width: 100%; max-width: 400px;
    }
    .auth-header { text-align: center; margin-bottom: 2rem; }
    .auth-logo {
        width: 60px; height: 60px; margin: 0 auto 1rem;
        background: linear-gradient(135deg, #d45a30, #a33d1a); border-radius: 16px;
        display: flex; align-items: center; justify-content: center; font-size: 0.7rem;
        color: white; font-weight: bold;
    }
    .auth-title { margin: 0; color: white; font-size: 1.75rem; font-weight: bold; }
    .auth-subtitle { margin: 0.5rem 0 0; color: rgba(255, 255, 255, 0.6); font-size: 0.9rem; }
    .auth-error {
        margin-bottom: 1.5rem; padding: 0.875rem; background: rgba(239, 68, 68, 0.15);
        border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 10px; color: #f87171; font-size: 0.9rem;
    }
    .form-field { margin-bottom: 1rem; }
    .form-field-last { margin-bottom: 1.5rem; }
    .form-label { display: block; color: rgba(255, 255, 255, 0.6); font-size: 0.85rem; margin-bottom: 0.5rem; }
    .auth-input {
        width: 100%; padding: 0.875rem 1rem; background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(200, 80, 50, 0.2); border-radius: 10px; color: white;
        font-size: 1rem; outline: none; box-sizing: border-box;
    }
    .auth-submit {
        width: 100%; padding: 0.875rem; background: linear-gradient(135deg, #d45a30, #a33d1a);
        color: white; border: none; border-radius: 10px; font-size: 1rem; font-weight: 600; cursor: pointer;
    }
    .auth-submit:disabled { opacity: 0.7; }
    .auth-toggle { margin-top: 1.5rem; text-align: center; }
    .auth-toggle-text { color: rgba(255, 255, 255, 0.5); font-size: 0.9rem; }
    .auth-toggle-btn {
        background: none; border: none; color: #d45a30; font-weight: 600; cursor: pointer; font-size: 0.9rem;
    }

    /* Two-Column Layout */
    .two-column-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
    .column-left, .column-right { display: flex; flex-direction: column; gap: 1.5rem; }
    @media (max-width: 900px) { .two-column-layout { grid-template-columns: 1fr; } }

    /* Meal Planner Panel */
    .panel-title { margin: 0 0 0.25rem 0; color: white; font-size: 1.25rem; font-weight: 700; }
    .panel-subtitle { margin: 0 0 1rem 0; color: rgba(255, 255, 255, 0.5); font-size: 0.85rem; }
    .btn-generate {
        padding: 0.75rem 1.5rem; background: linear-gradient(135deg, #22c55e, #15803d);
        color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; white-space: nowrap;
    }
    .btn-generate:disabled { opacity: 0.7; cursor: not-allowed; }
    .btn-clear {
        padding: 0.4rem 1rem; background: rgba(255, 255, 255, 0.05); color: rgba(255, 255, 255, 0.5);
        border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 8px; cursor: pointer; font-size: 0.85rem;
    }

    /* Ingredient Items */
    .ingredient-item {
        display: flex; align-items: center; justify-content: space-between; gap: 0.75rem;
        padding: 0.75rem 1rem; background: rgba(255, 255, 255, 0.03); border-radius: 10px;
        border: 1px solid rgba(34, 197, 94, 0.15); margin-bottom: 0.5rem;
    }
    .ingredient-info { display: flex; flex-direction: column; gap: 0.15rem; }
    .ingredient-name { color: rgba(255, 255, 255, 0.9); font-size: 0.95rem; }
    .ingredient-qty { color: rgba(255, 255, 255, 0.45); font-size: 0.8rem; }
    .ingredient-meta { display: flex; align-items: center; gap: 0.5rem; flex-shrink: 0; }
    .carb-badge {
        padding: 0.15rem 0.5rem; border-radius: 10px; font-size: 0.65rem; font-weight: 600;
        text-transform: uppercase; background: rgba(234, 179, 8, 0.15); color: #eab308;
        border: 1px solid rgba(234, 179, 8, 0.3);
    }
    .cost-label { color: rgba(34, 197, 94, 0.85); font-size: 0.85rem; font-weight: 600; white-space: nowrap; }
    .ingredients-footer {
        display: flex; justify-content: space-between; align-items: center;
        margin-top: 1rem; padding-top: 0.75rem; border-top: 1px solid rgba(255, 255, 255, 0.1);
    }
    .ingredients-total { color: rgba(34, 197, 94, 0.9); font-size: 1rem; font-weight: 700; }
    .generating-spinner {
        width: 24px; height: 24px; border: 3px solid rgba(34, 197, 94, 0.2);
        border-top-color: #22c55e; border-radius: 50%;
        animation: spin 0.8s linear infinite; margin: 0 auto 0.75rem;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    ```

```bash
export ANTHROPIC_API_KEY="your-key"
jac start main.jac
```

!!! warning "Common issue"
    If you see "Address already in use", use `--port` to pick a different port: `jac start main.jac --port 3000`.

Open [http://localhost:8000](http://localhost:8000). You should see a login screen -- that's the auth working.

1. **Sign up** with any username and password
2. **Add todos** -- they auto-categorize just like Part 2
3. **Try the meal planner** -- type "chicken stir fry for 4" and click Generate. You'll see a structured shopping list with quantities, units, costs, and carb flags.
4. **Refresh the page** -- your meal plan is still there (it's persisted to the graph now)
5. **Log out and sign up as a different user** -- you'll see a completely empty app. No shared data.
6. **Restart the server** -- all data persists for both users

---

## What You Learned

Over three parts, you built the same app three ways -- each time adding capabilities:

- **Part 1:** `def:pub` functions, graph nodes, reactive frontend -- a working full-stack app in one file
- **Part 2:** `by llm()`, `enum`, AI categorization -- intelligence with minimal code
- **Part 3:** Walkers, auth, structured AI, multi-file -- production-ready architecture

The new concepts from this part:

- **`walker:priv`** -- per-user walker that requires authentication
- **`` can X with `root entry ``** -- ability that fires when the walker enters root
- **`can X with Todo entry`** -- ability that fires when the walker enters a Todo node
- **`visit [-->]`** -- move the walker to all connected nodes
- **`here`** / **`self`** -- current node / walker state
- **`report { ... }`** -- send data back, collected in `.reports`
- **`root spawn Walker()`** -- spawn a walker from the client
- **`result.reports[0]`** -- access the walker's reported data
- **`jacLogin`**, **`jacSignup`**, **`jacLogout`** -- built-in authentication
- **`can with [deps] entry`** -- re-runs when dependencies change (like `useEffect`)
- **`sv import from main`** -- import server walkers into client code
- **`impl app.method { ... }`** -- implement declared methods in a separate file
- **`obj`** -- structured data types for LLM output
- **`sem`** -- semantic hints that guide LLM field interpretation
- **`-> list[Type] by llm()`** -- LLM returns typed, structured data

**When to use each pattern:**

- **`def:pub` functions** -- simple endpoints, shared data, quick prototyping
- **`walker:priv`** -- per-user data, graph traversal, production apps

---

## Next Steps

- **Deploy** -- [Deploy to Kubernetes](../production/kubernetes.md) with `jac-scale`
- **Go deeper on walkers** -- [Object-Spatial Programming](../language/osp.md) covers advanced graph patterns
- **More AI** -- [byLLM Quickstart](../ai/quickstart.md) and [Agentic AI](../ai/agentic.md) for tool-using agents
- **Examples** -- [LittleX (Twitter Clone)](../examples/littlex.md), [RAG Chatbot](../examples/rag-chatbot.md)
