# Todo App - Beginner's Guide to Building with Jac

> **️ Version Compatibility Warning**
>
> **For jac-client < 0.2.4:**
>
> - All `def` functions are **automatically exported** - no `:pub` needed
> - You **cannot export variables** (globals) - only functions can be exported
>
> **For jac-client >= 0.2.4:**
>
> - Functions and variables **must be explicitly exported** with `:pub`
> - The `app()` function must be `def:pub app()` to be accessible
> - This guide assumes version 0.2.4 or later

Welcome to the Todo App example! This guide will walk you through building a full-stack web application with Jac, from setup to deployment. Jac simplifies web development by eliminating the need for separate frontend and backend technologies, HTTP clients, and complex build configurations.

---

## 1. Creating the Application

### Prerequisites

Before installing Jac client, you need to have **Node.js** installed on your system.

#### Installing Node.js

**For Linux users:**

Visit [https://nodejs.org/en/download](https://nodejs.org/en/download) and follow the instructions to install Node.js using **nvm** (Node Version Manager) with **npm**.

Select:

- **Platform**: Linux
- **Package Manager**: nvm
- **Package**: npm

Then follow the installation commands provided on that page.

**For macOS users:**

Download and install Node.js from [https://nodejs.org/en/download](https://nodejs.org/en/download) by selecting your operating system.

**Verify Installation:**

After installation, verify Node.js and npm are installed correctly:

```bash
node -v
npm -v
```

### Installation

Once Node.js is installed, install the Jac client package:

```bash
pip install jac-client
```

### Create a New Jac App

Use the `jac create --use client` command to scaffold a new client-side application. You can name your app however you want (here we're using `todo-app`):

```bash
jac create --use client todo-app
```

This command will:

- Create a new directory with your project name
- Set up an organized project structure
- Create a starter `main.jac` file with a sample component
- Include a sample TypeScript component
- **Automatically install npm packages** in the `.jac/client/` directory

#### Skipping Package Installation

If you want to skip the automatic installation of default packages, use the `--skip` flag:

```bash
jac create --use client --skip todo-app
```

**When to use `--skip`:**

- You want to manually control when packages are installed
- You're setting up the project in an environment without npm/Node.js initially
- You want to customize the package.json before installation

**Note:** If you use `--skip`, you'll need to install packages manually later using:

```bash
jac add --npm <package-name>
```

Or you can manually run `npm install` in the `.jac/client/configs/` directory after the project is created.

**What gets created:**

```
todo-app/
├── jac.toml              # Project configuration
├── main.jac              # Main application file
├── components/           # Reusable components
│   └── Button.tsx        # Example TypeScript component
├── assets/               # Static assets
└── build/                # Build output (generated)
```

### Running Your App

Navigate to your project directory and start the development server:

```bash
cd todo-app
jac start main.jac
```

This starts both:

- **Backend server**: Handles your Jac graph operations and walkers
- **Frontend development server**: Serves your React components

You can access your app at `http://localhost:8000`

### Hot Module Replacement (HMR)

For faster development with live reloading, use `--watch` mode:

```bash
jac start main.jac --watch
```

This enables Hot Module Replacement, which automatically reloads your code when you make changes:

- **Vite dev server** runs on port 8000 (open this in your browser)
- **API server** runs on port 8001 (proxied via Vite)
- **File watcher** monitors `*.jac` files for changes

When you edit a `.jac` file, the backend recompiles automatically and the frontend hot-reloads without a full page refresh.

**Note:** HMR requires the `watchdog` package, which is included in `[dev-dependencies]` by default. Install it with:

```bash
jac install --dev
```

---

## 2. Entry Point of the App

Every Jac client application needs an entry point function. This is where your app starts rendering.

### The `app()` Function

Inside your `cl` block, define a function called `app()`:

```jac
# Note: useState is auto-injected by the Jac compiler - no import needed!
# The 'has' keyword automatically creates reactive state with useState under the hood.

cl {
    def app() -> any {
        has count: int = 0;
        return <div>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <button onClick={lambda e: any -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

**Key Points:**

- `app()` is the **required entry point** that Jac looks for
- It must be defined inside a `cl { }` block (client-side code)
- The `cl` (client) block indicates this code runs in the browser
- This function gets called automatically when the page loads
- You can define other components and helper functions in the same `cl` block

**Example with Multiple Components:**

```jac
# Note: Only import hooks that aren't auto-injected (useEffect, useRef, etc.)
# useState is auto-injected when you use 'has' for state variables.
cl import from react { useEffect }

cl {
    def TodoList(todos: list) -> any {
        return <ul>
            {todos.map(lambda todo: any -> any {
                return <li key={todo._jac_id}>{todo.text}</li>;
            })}
        </ul>;
    }

    def:pub app() -> any {
        has todos: list = [];

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                result = root spawn read_todos();
                todos = result.reports if result.reports else [];
            }
            loadTodos();
        }, []);

        return <div>
            <h1>My Todos</h1>
            <TodoList todos={todos} />
        </div>;
    }
}
```

---

## 3. Creating Components

Components in Jac are functions that return JSX (JavaScript XML). They're similar to React components but written in pure Jac syntax.

### Basic Component Structure

```jac
cl {
    def MyComponent() -> any {
        return <div>
            <h1>Hello from Jac!</h1>
        </div>;
    }
}
```

### Component with Props

Components can accept parameters (props):

```jac
def TodoItem(item: dict) -> any {
    return <li key={item.id}>
        <span>{item.text}</span>
        <button onClick={lambda -> None { removeTodo(item.id); }}>
            Remove
        </button>
    </li>;
}
```

**Component Features:**

- **JSX Syntax**: Write HTML-like syntax directly in Jac
- **Inline Styles**: Use JavaScript objects for styling
- **Event Handlers**: Attach functions to user interactions
- **Reusability**: Components can call other components

### Example: TodoItem Component

```jac
def TodoItem(item: dict) -> any {
    return <li key={item.id} style={{
        "display": "flex",
        "gap": "12px",
        "alignItems": "center",
        "padding": "12px",
        "background": "#FFFFFF",
        "borderRadius": "10px"
    }}>
        <input
            type="checkbox"
            checked={item.done}
            onChange={lambda -> None { toggleTodo(item.id); }}
        />
        <span style={{
            "textDecoration": ("line-through" if item.done else "none")
        }}>
            {item.text}
        </span>
        <button onClick={lambda -> None { removeTodo(item.id); }}>
            Remove
        </button>
    </li>;
}
```

**Breaking it down:**

- `item: dict` - Component receives a dictionary (todo item) as a prop
- `style={{...}}` - Inline styles using JavaScript objects
- `checked={item.done}` - Dynamic attribute binding
- `onChange={lambda -> None {...}}` - Event handler using lambda
- `{item.text}` - Interpolation of JavaScript expressions in JSX

---

## 4. Adding State with React Hooks

Jac simplifies state management with the `has` keyword, which automatically uses React's `useState` under the hood. You can also use other React hooks by importing them explicitly.

```jac
# Note: useState is auto-injected - only import other hooks you need
cl import from react { useEffect }

cl {
    def Counter() -> any {
        # The 'has' keyword creates reactive state (auto-injects useState)
        has count: int = 0;

        useEffect(lambda -> None {
            console.log("Count changed:", count);
        }, [count]);

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                count = count + 1;
            }}>
                Increment
            </button>
        </div>;
    }
}
```

**State with `has` Keyword:**

- `has varname: type = value;` - Declares reactive state (useState is auto-injected)
- Direct assignment `varname = newValue;` - Updates the state (calls the setter automatically)

**Available React Hooks (import as needed):**

- `useEffect` - For side effects
- `useRef` - For refs
- `useContext` - For context
- `useCallback`, `useMemo` - For performance optimization
- And more...

> **Note:** You do NOT need to import `useState` - the Jac compiler auto-injects it when you use the `has` keyword for state variables.

### State Management Example

Here's a complete example showing state management in a todo app:

```jac
# Only import useEffect - useState is auto-injected via 'has' keyword
cl import from react { useEffect }

cl {
    def app() -> any {
        # Reactive state using 'has' - no useState import needed!
        has todos: list = [];
        has input: str = "";
        has filter: str = "all";

        # Load todos on mount
        useEffect(lambda -> None {
            async def loadTodos() -> None {
                result = root spawn read_todos();
                todos = result.reports if result.reports else [];
            }
            loadTodos();
        }, []);

        # Add new todo
        async def addTodo() -> None {
            if not input.trim() { return; }
            response = root spawn create_todo(text=input.trim());
            new_todo = response.reports[0][0];
            todos = todos.concat([new_todo]);
            input = "";
        }

        # Filter todos
        def getFilteredTodos() -> list {
            if filter == "active" {
                return todos.filter(lambda todo: any -> bool { return not todo.done; });
            } elif filter == "completed" {
                return todos.filter(lambda todo: any -> bool { return todo.done; });
            }
            return todos;
        }

        filteredTodos = getFilteredTodos();

        return <div>
            <h1>My Todos</h1>
            <input
                value={input}
                onChange={lambda e: any -> None { input = e.target.value; }}
                onKeyPress={lambda e: any -> None {
                    if e.key == "Enter" { addTodo(); }
                }}
            />
            <button onClick={addTodo}>Add</button>

            <div>
                {filteredTodos.map(lambda todo: any -> any {
                    return <div key={todo._jac_id}>
                        <span>{todo.text}</span>
                    </div>;
                })}
            </div>
        </div>;
    }
}
```

---

## 5. Event Handling

Event handling in Jac works just like React, but with Jac's lambda syntax.

### Basic Event Handlers

```jac
def Button() -> any {
    return <button onClick={lambda -> None {
        console.log("Button clicked!");
    }}>
        Click Me
    </button>;
}
```

### Event Handlers with Event Object

```jac
def InputField() -> any {
    # 'has' creates reactive state - useState is auto-injected
    has value: str = "";

    return <input
        type="text"
        value={value}
        onChange={lambda e: any -> None {
            console.log("Input value:", e.target.value);
            value = e.target.value;
        }}
    />;
}
```

### Form Submission

```jac
def TodoForm() -> any {
    return <form onSubmit={onAddTodo}>
        <input id="todo-input" type="text" />
        <button type="submit">Add Todo</button>
    </form>;
}

async def onAddTodo(e: any) -> None {
    e.preventDefault();  # Prevent page refresh
    inputEl = document.getElementById("todo-input");
    text = inputEl.value.trim();

    if not text { return; }

    # Handle form submission
    response = root spawn create_todo(text=text);
    new_todo = response.reports[0][0];
    # ... update state
}
```

### Common Event Types

| Event | Syntax | Use Case |
|-------|--------|----------|
| `onClick` | `onClick={lambda -> None {...}}` | Button clicks |
| `onChange` | `onChange={lambda e: any -> None {...}}` | Input changes |
| `onSubmit` | `onSubmit={lambda e: any -> None {...}}` | Form submission |
| `onKeyPress` | `onKeyPress={lambda e: any -> None {...}}` | Keyboard input |

### Advanced: Conditional Event Handlers

```jac
def FilterButton(filterType: str, currentFilter: str, onFilterChange: any) -> any {
    isActive = currentFilter == filterType;

    return <button
        onClick={lambda -> None {
            onFilterChange(filterType);
        }}
        style={{
            "background": ("#7C3AED" if isActive else "#FFFFFF"),
            "color": ("#FFFFFF" if isActive else "#7C3AED")
        }}
    >
        {filterType}
    </button>;
}
```

---

## 6. Magic: No More Axios/Fetch!

One of Jac's most powerful features is **seamless backend communication** without writing HTTP requests, fetch calls, or axios code.

### The `spawn` Syntax

Instead of writing:

```javascript
// Traditional approach
const response = await fetch('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'New todo' })
});
const data = await response.json();
```

You simply write:

```jac
response = root spawn create_todo(text="New todo");
```

### How `spawn` Works

```jac
# Call a walker on a node
result = node_reference spawn walker_name(parameters);
```

**Syntax:**

- `node_reference` - The node to spawn the walker on (commonly `root` for the root node, or a node ID)
- `spawn` - The spawn keyword
- `walker_name` - Name of the walker to execute
- `parameters` - Parameters to pass to the walker (as function arguments)

**Example from Todo App:**

```jac
# Create a new todo (spawn on root node)
response = root spawn create_todo(text=text);

# Toggle todo status (spawn on specific todo node)
id spawn toggle_todo();

# Read all todos
todos = root spawn read_todos();
```

### Backend Walkers

Walkers are defined in the same `app.jac` file (outside the `cl` block):

```jac
# Node definition (data model)
node Todo {
    has text: str;
    has done: bool = False;
}

# Walker: Create a new todo
walker create_todo {
    has text: str;
    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

# Walker: Toggle todo status
walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}

# Walker: Read all todos
walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with exit {
        report here;
    }
}
```

### Complete Example: Creating a Todo

**Frontend (in `cl` block):**

```jac
async def onAddTodo(e: any) -> None {
    e.preventDefault();
    text = document.getElementById("todo-input").value.trim();
    if not text { return; }

    # Call backend walker - no fetch/axios needed!
    response = root spawn create_todo(text=text);
    new_todo = response.reports[0][0];

    # Update frontend state
    s = todoState();
    newItem = {
        "id": new_todo._jac_id,
        "text": new_todo.text,
        "done": new_todo.done
    };
    setTodoState({"items": s.items.concat([newItem])});
}
```

**Backend (outside `cl` block):**

```jac
walker create_todo {
    has text: str;
    can create with `root entry {
        # 'text' comes from the walker parameter
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}
```

### Benefits of `spawn`

 **No HTTP Configuration**: No need to set up API endpoints, CORS, or request/response formats
 **Type Safety**: Jac handles serialization automatically
 **Authentication**: Built-in token management via `jacLogin()` / `jacLogout()`
 **Error Handling**: Exceptions are properly propagated
 **Graph Operations**: Direct access to graph-based data operations
 **Less Code**: Eliminates boilerplate HTTP client code
 **Natural Syntax**: Call walkers on nodes using intuitive syntax

### Authentication Helpers

Jac also provides built-in auth functions:

```jac
# Sign up
result = await jacSignup(username, password);
if result["success"] {
    navigate("/todos");
}

# Log in
success = await jacLogin(username, password);
if success {
    navigate("/todos");
}

# Log out
jacLogout();
navigate("/login");

# Check if logged in
if jacIsLoggedIn() {
    return <div>Welcome!</div>;
}
```

---

## Complete Example: Todo App Structure

Here's how all the pieces fit together:

```jac
# ============================================================================
# BACKEND: Data Models and Walkers
# ============================================================================
node Todo {
    has text: str;
    has done: bool = False;
}

walker create_todo {
    has text: str;
    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

# ============================================================================
# FRONTEND: Components, State, and Events
# ============================================================================
# Note: No need to import useState - it's auto-injected when using 'has' keyword

cl {
    def app() -> any {
        # Reactive state with 'has' - useState is auto-injected by the compiler
        has todos: list = [];
        has input: str = "";

        # Event Handler
        async def addTodo() -> None {
            if not input.trim() { return; }
            response = root spawn create_todo(text=input.trim());
            new_todo = response.reports[0][0];
            todos = todos.concat([new_todo]);
            input = "";
        }

        return <div>
            <h2>My Todos</h2>
            <input
                value={input}
                onChange={lambda e: any -> None { input = e.target.value; }}
                onKeyPress={lambda e: any -> None {
                    if e.key == "Enter" { addTodo(); }
                }}
            />
            <button onClick={addTodo}>Add Todo</button>

            <div>
                {todos.map(lambda todo: any -> any {
                    return <div key={todo._jac_id}>
                        <span>{todo.text}</span>
                    </div>;
                })}
            </div>
        </div>;
    }
}
```

---

## Running the Todo App

To run this example:

```bash
# From the todo-app directory
jac start main.jac
```

Then visit `http://localhost:8000` in your browser.

---

## Next Steps

Ready to dive deeper? Explore these advanced topics:

- **[Routing](routing.md)**: Build multi-page apps with declarative routing (`<Router>`, `<Routes>`, `<Route>`)
- **[Lifecycle Hooks](lifecycle-hooks.md)**: Use `onMount()` and React hooks for initialization logic
- **[Advanced State](advanced-state.md)**: Manage complex state with React hooks and context
- **[Imports](imports.md)**: Import third-party libraries (React, Ant Design, Lodash), other Jac files, and JavaScript modules
- **[Learn JAC](https://www.jac-lang.org)**: Explore Jac's graph-based data modeling

## Examples

Check out the `examples/` directory for working applications:

- **[basic](../../examples/basic/)**: Simple counter app using React hooks
- **[with-router](../../examples/with-router/)**: Multi-page app with declarative routing
- **[little-x](../../examples/little-x/)**: Social media app with third-party libraries
- **[todo-app](../../examples/todo-app/)**: Full-featured todo app with authentication
- **[basic-full-stack](../../examples/basic-full-stack/)**: Full-stack app with backend integration

---

## Key Takeaways

1. **Single Language**: Write frontend and backend in Jac
2. **No HTTP Client**: Use `spawn` syntax instead of fetch/axios
3. **Reactive State**: React hooks manage UI updates automatically
4. **Component-Based**: Build reusable UI components with JSX
5. **Type Safety**: Jac provides type checking across frontend and backend
6. **Graph Database**: Built-in graph data model eliminates need for SQL/NoSQL

Happy coding with Jac!
