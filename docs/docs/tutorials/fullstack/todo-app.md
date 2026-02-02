# Build a Full-Stack Todo App with AI

!!! tip "New Tutorial Available"
    For a comprehensive, step-by-step guide to building a full-stack AI app, see the **[Build Your First App](../first-app/part1-todo-app.md)** tutorial series. It covers the same concepts in a more progressive format across three parts.

This tutorial walks you through building a complete full-stack application with Jac, covering server-side graph operations, client-side React UI, and AI-powered features using `by llm()`.

> **Prerequisites:** Complete [Project Setup](setup.md) first.
>
> **Reference:** [Walker Responses](../../reference/language/walker-responses.md) | [Graph Operations](../../reference/language/graph-operations.md)

---

## What You'll Learn

- **Server/Client separation** with `sv {}` and `cl {}` blocks
- **Graph operations** - creating, traversing, and deleting nodes
- **Walker patterns** - CRUD operations and data accumulation
- **Walker response handling** - understanding `.reports` structure
- **Client-server communication** - spawning walkers from the frontend
- **AI integration** - using `by llm()` with semantic hints

## Project Structure

```
todo-app/
├── main.jac              # Entry point
├── endpoints.sv.jac      # Server-side walkers and nodes
├── frontend.cl.jac       # Client-side UI
└── components/
    ├── AuthForm.cl.jac   # Login/signup form
    └── TodoItem.cl.jac   # Todo item component
```

---

## Part 1: Server-Side Data Layer

### 1.1 Define the Data Model

Create `endpoints.sv.jac` - this file contains server-side code that persists data in the graph.

```jac
"""Todo App - Server-Side Data Layer."""

import from uuid { uuid4 }

# Define a node to store todo items
node Todo {
    has id: str,
        title: str,
        completed: bool = False,
        priority: str = "medium",
        parent_id: str = "";
}
```

**Key concepts:**

- `node` defines a persistent data type stored in the graph
- `has` declares node properties with optional default values
- Nodes are connected to the user's root node for per-user isolation

### 1.2 Create Walker - Adding Todos

Walkers traverse the graph and perform operations. Here's a walker to add new todos:

```jac
walker:priv AddTodo {
    has title: str,
        priority: str = "medium",
        parent_id: str = "";

    can create with `root entry {
        # Generate a unique ID
        new_id = str(uuid4());

        # Create a new Todo node and connect it to root
        new_todo = here ++> Todo(
            id=new_id,
            title=self.title,
            completed=False,
            priority=self.priority,
            parent_id=self.parent_id
        );

        # Report the created todo back to the caller
        report new_todo[0];
    }
}
```

**Key concepts:**

- `walker:priv` - Private walker (not exposed as REST API, called from code)
- `has` - Walker parameters passed during instantiation
- `can create with`root entry` - Ability that runs when walker enters the root node
- `here ++> Node(...)` - Creates a new node and connects it to the current node (`here`)
- `new_todo[0]` - The `++>` operator returns a list; access the first element
- `report` - Returns data to the caller (collected in `.reports` array)

### 1.3 List Walker - Accumulating Data Across Traversal

This walker demonstrates the **accumulator pattern** - collecting data as it traverses the graph:

```jac
walker:priv ListTodos {
    has todos: list = [];

    # Entry point: start traversing from root
    can collect with `root entry {
        visit [-->];  # Visit all outgoing edges
    }

    # Called for each Todo node encountered
    can gather with Todo entry {
        self.todos.append({
            "id": here.id,
            "title": here.title,
            "completed": here.completed,
            "priority": here.priority,
            "parent_id": here.parent_id
        });
    }

    # Exit point: report accumulated data
    can report_all with `root exit {
        report self.todos;
    }
}
```

**Key concepts:**

- Multiple `can` abilities with different triggers
- `with`root entry` - Runs when entering the root node
- `with Todo entry` - Runs when entering any Todo node
- `with`root exit` - Runs when exiting the root node (after traversal)
- `visit [-->]` - Traverse all outgoing edges from current node
- `self.todos` - Walker state persists across the traversal
- The pattern: enter root → visit children → gather from each → exit root with results

### 1.4 Toggle and Delete Walkers

```jac
walker:priv ToggleTodo {
    has todo_id: str;

    can search with `root entry {
        visit [-->];
    }

    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.completed = not here.completed;
            report {"id": here.id, "completed": here.completed};
        }
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can search with `root entry {
        visit [-->];
    }

    can delete with Todo entry {
        # Delete the todo and its children (cascade)
        if here.id == self.todo_id or here.parent_id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}
```

**Key concepts:**

- `here.property = value` - Modify node properties directly
- `del here` - Remove the current node from the graph
- Conditional logic to find the target node during traversal

---

## Part 2: Understanding Walker Responses

This is a **critical pattern** that trips up many developers.

### 2.1 The `.reports` Array

When you spawn a walker, every `report` statement adds to a `.reports` array:

```jac
# Walker with multiple reports
walker:priv MyWalker {
    can do_stuff with `root entry {
        report "first";   # reports[0]
        report "second";  # reports[1]
        report "third";   # reports[2]
    }
}
```

### 2.2 Reports During Traversal

When a walker visits multiple nodes and reports from each:

```jac
walker:priv VisitAll {
    can start with `root entry {
        visit [-->];
    }

    can process with Todo entry {
        report here.title;  # Reports once per Todo node visited
    }
}

# If there are 3 todos, response.reports = ["todo1", "todo2", "todo3"]
```

### 2.3 Common Pattern: Single Accumulated Report

The `ListTodos` walker uses the cleanest pattern - accumulate internally, report once:

```jac
walker:priv ListTodos {
    has todos: list = [];

    can collect with `root entry { visit [-->]; }
    can gather with Todo entry { self.todos.append({...}); }
    can report_all with `root exit { report self.todos; }  # Single report
}

# response.reports[0] = [all todos as a list]
```

### 2.4 Handling Responses in Client Code

```jac
cl {
    # Safe pattern for single-report walkers
    async def example() -> None {
        result = root spawn ListTodos();
        todos = result.reports[0] if result.reports else [];
    }
}
```

---

## Part 3: Client-Side UI

### 3.1 Entry Point (main.jac)

```jac
"""Todo App - Entry Point."""

# Server-side imports
sv {
    import from endpoints { Todo, AddTodo, ListTodos, ToggleTodo, DeleteTodo }
}

# Client-side UI
cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return <ClientApp />;
    }
}
```

**Key concepts:**

- `sv { }` block - Server-side code, runs on the backend
- `cl { }` block - Client-side code, runs in the browser
- `def:pub` - Public function exported as the app entry point

### 3.2 Frontend Component (frontend.cl.jac)

```jac
"""Todo App - Client-Side UI."""

import from react { useEffect }
import from "@jac-client/utils" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

# Import server-side walkers for client use
sv import from endpoints { AddTodo, ListTodos, ToggleTodo, DeleteTodo }

def:pub app -> any {
    # Component state
    has isLoggedIn: bool = False,
        todos: list = [],
        newTodoText: str = "",
        todosLoading: bool = True;

    # Check auth on mount
    useEffect(lambda -> None {
        isLoggedIn = jacIsLoggedIn();
    }, []);

    # Fetch todos when logged in
    useEffect(
        lambda -> None { if isLoggedIn { fetchTodos(); }},
        [isLoggedIn]
    );

    # Fetch all todos from server
    async def fetchTodos -> None {
        todosLoading = True;
        result = root spawn ListTodos();
        todos = result.reports[0] if result.reports else [];
        todosLoading = False;
    }

    # Add a new todo
    async def addTodo -> None {
        if not newTodoText.trim() { return; }

        response = root spawn AddTodo(title=newTodoText);
        newTodo = response.reports[0];

        # Update local state with the new todo
        todos = todos.concat([{
            "id": newTodo.id,
            "title": newTodo.title,
            "completed": newTodo.completed,
            "priority": newTodo.priority,
            "parent_id": newTodo.parent_id
        }]);
        newTodoText = "";
    }

    # Toggle todo completion
    async def toggleTodo(todoId: str) -> None {
        root spawn ToggleTodo(todo_id=todoId);

        # Update local state
        todos = todos.map(lambda t: any -> any {
            if t.id == todoId {
                return {
                    "id": t.id,
                    "title": t.title,
                    "completed": not t.completed,
                    "priority": t.priority,
                    "parent_id": t.parent_id
                };
            }
            return t;
        });
    }

    # Delete a todo
    async def deleteTodo(todoId: str) -> None {
        root spawn DeleteTodo(todo_id=todoId);
        todos = todos.filter(lambda t: any -> bool {
            return t.id != todoId and t.parent_id != todoId;
        });
    }

    # Render UI
    return
        <div style={{"padding": "2rem", "maxWidth": "600px", "margin": "0 auto"}}>
            <h1>My Todos</h1>

            <div style={{"display": "flex", "gap": "0.5rem", "marginBottom": "1rem"}}>
                <input
                    type="text"
                    value={newTodoText}
                    onChange={lambda e: any -> None { newTodoText = e.target.value; }}
                    placeholder="What needs to be done?"
                    style={{"flex": "1", "padding": "0.5rem"}}
                />
                <button onClick={lambda -> None { addTodo(); }}>Add</button>
            </div>

            {(
                <p>Loading...</p>
            ) if todosLoading else (
                <ul>
                    {todos.map(lambda todo: any -> any {
                        return
                            <li key={todo.id} style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                                <input
                                    type="checkbox"
                                    checked={todo.completed}
                                    onChange={lambda -> None { toggleTodo(todo.id); }}
                                />
                                <span style={{"textDecoration": (todo.completed if "line-through" else "none")}}>
                                    {todo.title}
                                </span>
                                <button onClick={lambda -> None { deleteTodo(todo.id); }}>Delete</button>
                            </li>;
                    })}
                </ul>
            )}
        </div>;
}
```

**Key concepts:**

- `sv import from endpoints { ... }` - Import server walkers for client use
- `root spawn WalkerName(params)` - Execute a server walker from client code
- `has` in a component - Declares reactive state
- `useEffect` - React hook for side effects
- `async def` - Asynchronous function for API calls
- JSX syntax with Jac expressions in `{}`

---

## Part 4: Adding AI Features

### 4.1 Define Structured Types with Semantic Hints

Add to `endpoints.sv.jac`:

```jac
import from byllm.lib { Model }

# Initialize the LLM model globally
glob llm = Model(model_name="claude-sonnet-4-20250514");

# Enum for units of measurement
enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, CLOVE, BUNCH }

# Structured object for ingredients
obj Ingredient {
    has name: str;
    has quantity: float;
    has unit: Unit;
    has cost: float;
    has carby: bool;
}

# Semantic hints guide the LLM's output
sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient will spike blood glucose";

"""
Generate a shopping list of ingredients needed for a described meal.
"""
def generate_ingredients(meal_description: str) -> list[Ingredient] by llm();
```

**Key concepts:**

- `glob llm = Model(...)` - Initialize LLM once, globally available
- `enum` - Constrained set of values
- `obj` - Structured data type (not persisted like `node`)
- `sem Field.name = "description"` - Semantic hint for LLM guidance
- `def func() -> Type by llm()` - LLM-powered function with structured output
- The function name, parameter names, and types provide context for the LLM; use `sem` for additional semantics

### 4.2 Walker That Uses AI

```jac
walker:priv MealToIngredients {
    has meal_description: str;

    can process with `root entry {
        # Call the LLM-powered function
        ingredients = generate_ingredients(self.meal_description);

        total_cost: float = 0.0;

        # Create a todo for each ingredient
        for ingredient in ingredients {
            new_id = str(uuid4());
            title = f"{ingredient.quantity} {ingredient.unit.name} {ingredient.name} (${ingredient.cost:.2f})";

            here ++> Todo(
                id=new_id,
                title=title,
                completed=False,
                priority="medium",
                parent_id=""
            );

            total_cost += ingredient.cost;
        }

        # Get the updated todo list
        todos_result = root spawn ListTodos();
        todos_list = todos_result.reports[0] if todos_result.reports else [];

        # Report summary (this becomes reports[1] since ListTodos added reports[0])
        report {
            "meal": self.meal_description,
            "ingredients_added": todos_list,
            "total_cost": total_cost
        };
    }
}
```

**Key concepts:**

- Call LLM function: `ingredients = generate_ingredients(self.meal_description)`
- LLM returns structured `list[Ingredient]` automatically parsed
- F-strings: `f"{ingredient.quantity} {ingredient.unit.name}"`
- Nested walker spawn: `root spawn ListTodos()` within another walker
- Multiple reports: `ListTodos` reports first, then this walker reports second

### 4.3 Client-Side AI Integration

Add to `frontend.cl.jac`:

```jac
sv import from endpoints { AddTodo, ListTodos, ToggleTodo, DeleteTodo, MealToIngredients }

def:pub app -> any {
    has mealDescription: str = "",
        mealLoading: bool = False;
    # ... other state ...

    async def generateMealIngredients -> None {
        if not mealDescription.trim() { return; }
        mealLoading = True;

        try {
            response = root spawn MealToIngredients(meal_description=mealDescription);

            # MealToIngredients has multiple reports:
            # reports[0] = ListTodos output (from nested spawn)
            # reports[1] = Summary object with ingredients_added
            if response.reports and response.reports.length > 1 {
                result = response.reports[1];
                added = result["ingredients_added"];

                if added and added.length > 0 {
                    todos = todos.concat(added);
                }
            }
        } except Exception as e {
            console.error("Error generating ingredients:", e);
        }

        mealDescription = "";
        mealLoading = False;
    }

    # In render, add meal input:
    return
        <div>
            <div style={{"marginTop": "2rem", "padding": "1rem", "border": "1px solid #ccc"}}>
                <h3>AI Meal Planner</h3>
                <input
                    type="text"
                    value={mealDescription}
                    onChange={lambda e: any -> None { mealDescription = e.target.value; }}
                    placeholder="Describe a meal (e.g., spaghetti bolognese)"
                    disabled={mealLoading}
                />
                <button
                    onClick={lambda -> None { generateMealIngredients(); }}
                    disabled={mealLoading}
                >
                    {("Generating..." if mealLoading else "Generate Shopping List")}
                </button>
            </div>
        </div>;
}
```

---

## Part 5: Running the App

### 5.1 Start the Development Server

```bash
# Set your API key for AI features
export ANTHROPIC_API_KEY="your-key-here"

# Start the server
jac start main.jac --port 8000
```

### 5.2 Access the App

Open http://localhost:8000 in your browser.

### 5.3 Test the Features

1. **Register/Login** - Create an account
2. **Add Todos** - Type and click Add
3. **Toggle Complete** - Click the checkbox
4. **Delete** - Click Delete button
5. **AI Generate** - Type "tacos" and click Generate Shopping List

---

## Summary: Key Patterns

### Graph Operations

| Operation | Syntax | Description |
|-----------|--------|-------------|
| Create & Connect | `here ++> Node(...)` | Creates node, connects to current |
| Traverse | `visit [-->]` | Visit all outgoing edges |
| Delete | `del here` | Remove current node |
| Access | `here.property` | Read/write node properties |

### Walker Response Pattern

```jac
# Walker
walker MyWalker {
    can do_work with `root entry {
        report "data";  # Adds to .reports array
    }
}
```

### Client-Server Communication

```jac
# Import server walkers in client code
sv import from endpoints { MyWalker }

# Spawn walker from client
async def callServer -> None {
    result = root spawn MyWalker(param="value");
    data = result.reports[0] if result.reports else [];
}
```

### AI Integration

```jac
# Define structured type with semantic hints
obj MyType {
    has field: str;
}
sem MyType.field = "Description for LLM";

# LLM-powered function
def myFunc(input: str) -> MyType by llm();
```

---

## Next Steps

**Extend this app:**

- Add sub-todos with parent-child relationships
- Implement priority filtering
- Add due dates with calendar integration

**Learn more:**

- [Walker Responses](../../reference/language/walker-responses.md) - Deep dive into `.reports` patterns
- [Graph Operations](../../reference/language/graph-operations.md) - Complete reference for graph operators
- [byLLM Reference](../../reference/plugins/byllm.md) - Full AI integration documentation
- [Deploy to Kubernetes](../production/kubernetes.md) - Production deployment
