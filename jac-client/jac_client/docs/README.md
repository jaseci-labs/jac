# Todo App - Beginner's Guide to Building with Jac

Welcome to the Todo App example! This guide will walk you through building a full-stack web application with Jac, from setup to deployment. Jac simplifies web development by eliminating the need for separate frontend and backend technologies, HTTP clients, and complex build configurations.

---

## 📦 1. Creating the Application

### Installation

First, install the Jac client package:

```bash
pip install jac-client
```

### Create a New Jac App

Use the `jac create_jac_app` command to scaffold a new application: (* we can name our app however we want, here we are using `todo-app)

```bash
jac create_jac_app todo-app
```

This command will:
- Create a new directory with your project name
- Set up the basic project structure
- Initialize npm and install Vite (for development server)
- Create a starter `app.jac` file with a sample component

**What gets created:**
```
my-app/
├── app.jac          # Your main application file
├── package.json      # Node.js dependencies
└── node_modules/    # Dependencies (after npm install)
```

### Running Your App

Navigate to your project directory and start the development server:

```bash
cd todo-app
jac serve app.jac
```

This starts both:
- **Backend server**: Handles your Jac graph operations and walkers
- **Frontend development server**: Serves your React components

You can access your app at `http://localhost:8000`

---

## 🚪 2. Entry Point of the App

Every Jac client application needs an entry point function. This is where your app starts rendering.

### The `jac_app()` Function

At the bottom of your `app.jac` file, you'll find the entry point:

```jac
cl {
    def App() -> any {
        # Your main app component with routing
        return <div>Hello World</div>;
    }

    def jac_app() -> any {
        return App();
    }
}
```

**Key Points:**
- `jac_app()` is the **required entry point** that Jac looks for
- It should return your root component (usually called `App`)
- The `cl` (client) block indicates this code runs in the browser
- This function gets called automatically when the page loads

**Example from Todo App:**
```jac
def App() -> any {
    login_route = {"path": "/login", "component": lambda -> any { return LoginForm(); }, "guard": None};
    signup_route = {"path": "/signup", "component": lambda -> any { return SignupForm(); }, "guard": None};
    todos_route  = {"path": "/todos", "component": lambda -> any { return TodoApp(); }, "guard": jacIsLoggedIn};

    routes = [login_route, signup_route, todos_route];
    router = initRouter(routes, "/login");

    currentPath = router.path();
    return <div>
        {Nav(currentPath)}
        {router.render()}
    </div>;
}

def jac_app() -> any {
    return App();
}
```

---

## 🧩 3. Creating Components

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

## 🗄️ 4. Adding State

Jac supports two approaches to state management: React hooks (recommended) and Jac's custom `createState()`.

### Option 1: React Hooks (Recommended)

You can use React hooks directly in Jac by importing them:

```jac
cl import from react { useState, useEffect }

cl {
    def Counter() -> any {
        let [count, setCount] = useState(0);

        useEffect(lambda -> None {
            console.log("Count changed:", count);
        }, [count]);

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                setCount(count + 1);
            }}>
                Increment
            </button>
        </div>;
    }
}
```

**Available React Hooks:**
- `useState` - For state management
- `useEffect` - For side effects
- `useRef` - For refs
- `useContext` - For context
- And more...

### Option 2: Jac's createState()

Jac also provides its own `createState()` function:

```jac
let [todoState, setTodoState] = createState({
    "items": [],
    "filter": "all",
    "input": ""
});
```

**How it works:**
- `createState()` returns a tuple: `[getter, setter]`
- **Getter** (`todoState`): A function that returns the current state value
- **Setter** (`setTodoState`): A function that updates the state and triggers re-renders

### Choosing Between React Hooks and createState()

**Use React Hooks if:**
- You're familiar with React
- You want to use the React ecosystem
- You need access to all React features

**Use createState() if:**
- You want Jac-native state management
- You prefer simpler syntax for basic state
- You're building a pure Jac application

### Reading State with createState()

When using `createState()`, always call the getter as a function:

```jac
def TodoApp() -> any {
    s = todoState();  # Call getter function

    return <div>
        <p>Total todos: {s.items.length}</p>
        <p>Current filter: {s.filter}</p>
    </div>;
}
```

### Updating State

The setter merges updates with existing state:

```jac
# Update single property
setTodoState({"filter": "active"});

# Update multiple properties
setTodoState({
    "filter": "completed",
    "input": "New todo text"
});

# Update arrays (create new array)
s = todoState();
setTodoState({"items": s.items.concat([newItem])});
```

**Important:** The setter performs a **shallow merge**, meaning:
- Existing properties are preserved
- Only specified properties are updated
- Arrays and objects are replaced, not merged deeply

### Complete State Example

```jac
cl {
    # Initialize state
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "input": ""
    });

    # Read state in component
    def TodoApp() -> any {
        s = todoState();
        itemsArr = s.items;

        return <div>
            <input
                value={s.input}
                onChange={lambda e: any -> None {
                    setTodoState({"input": e.target.value});
                }}
            />
            <div>
                {[TodoItem(item) for item in itemsArr]}
            </div>
        </div>;
    }

    # Update state in event handler
    async def onAddTodo(e: any) -> None {
        e.preventDefault();
        text = document.getElementById("todo-input").value.trim();

        if not text { return; }

        # Create todo on backend
        new_todo = await __jacSpawn("create_todo", {"text": text});

        # Update frontend state
        s = todoState();
        newItem = {
            "id": new_todo._jac_id,
            "text": new_todo.text,
            "done": new_todo.done
        };
        setTodoState({"items": s.items.concat([newItem])});
    }
}
```

---

## 🎯 5. Event Handling

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
    return <input
        type="text"
        onChange={lambda e: any -> None {
            console.log("Input value:", e.target.value);
            setTodoState({"input": e.target.value});
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
    new_todo = await __jacSpawn("create_todo", {"text": text});
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
def FilterButton(filterType: str) -> any {
    s = todoState();
    isActive = s.filter == filterType;

    return <button
        onClick={lambda -> None {
            setFilter(filterType);
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

## ✨ 6. Magic: No More Axios/Fetch!

One of Jac's most powerful features is **seamless backend communication** without writing HTTP requests, fetch calls, or axios code.

### The `__jacSpawn()` Function

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
new_todo = await __jacSpawn("create_todo", {"text": "New todo"});
```

### How `__jacSpawn()` Works

```jac
# Call a walker on the backend
result = await __jacSpawn(
    walker_name,    # Name of the walker to execute
    fields,         # Dictionary of parameters to pass
    node_id         # Optional: specific node ID (defaults to "root")
);
```

**Example from Todo App:**
```jac
# Create a new todo
new_todo = await __jacSpawn("create_todo", {"text": text});

# Toggle todo status
toggled_todo = await __jacSpawn("toggle_todo", {}, todo_id);

# Read all todos
todos = await __jacSpawn("read_todos");
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
    can create with `root entry {
        new_todo = here ++> Todo(text="Example Todo");
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
    new_todo = await __jacSpawn("create_todo", {"text": text});

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
    can create with `root entry {
        # 'text' comes from the fields dictionary passed to __jacSpawn
        text = context.text;
        new_todo = here ++> Todo(text=text);
        report new_todo;
    }
}
```

### Benefits of `__jacSpawn()`

✅ **No HTTP Configuration**: No need to set up API endpoints, CORS, or request/response formats
✅ **Type Safety**: Jac handles serialization automatically
✅ **Authentication**: Built-in token management via `jacLogin()` / `jacLogout()`
✅ **Error Handling**: Exceptions are properly propagated
✅ **Graph Operations**: Direct access to graph-based data operations
✅ **Less Code**: Eliminates boilerplate HTTP client code

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

## 🎨 Complete Example: Todo App Structure

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
    can create with `root entry {
        new_todo = here ++> Todo(text=context.text);
        report new_todo;
    }
}

# ============================================================================
# FRONTEND: Components, State, and Events
# ============================================================================
cl {
    # State
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all"
    });

    # Component
    def TodoApp() -> any {
        s = todoState();
        return <div>
            <h2>My Todos</h2>
            <form onSubmit={onAddTodo}>
                <input id="todo-input" type="text" />
                <button type="submit">Add Todo</button>
            </form>
            {[TodoItem(item) for item in s.items]}
        </div>;
    }

    # Event Handler
    async def onAddTodo(e: any) -> None {
        e.preventDefault();
        text = document.getElementById("todo-input").value;
        new_todo = await __jacSpawn("create_todo", {"text": text});
        # Update state...
    }

    # Entry Point
    def jac_app() -> any {
        return TodoApp();
    }
}
```

---

## 🚀 Running the Todo App

To run this example:

```bash
# From the todo-app directory
jac serve app.jac
```

Then visit `http://localhost:8000` in your browser.

---

## 📚 Next Steps

Ready to dive deeper? Explore these advanced topics:

- **[Routing](routing.md)**: Build multi-page apps with declarative routing (`<Router>`, `<Routes>`, `<Route>`)
- **[Lifecycle Hooks](lifecycle-hooks.md)**: Use `onMount()` and React hooks for initialization logic
- **[Advanced State](advanced-state.md)**: Manage complex state with multiple `createState()` calls or React hooks
- **[Imports](imports.md)**: Import third-party libraries (React, Ant Design, Lodash), other Jac files, and JavaScript modules
- **[Learn JAC](https://www.jac-lang.org)**: Explore Jac's graph-based data modeling

## 🎓 Examples

Check out the `examples/` directory for working applications:

- **[basic](../../examples/basic/)**: Simple counter app using React hooks
- **[with-router](../../examples/with-router/)**: Multi-page app with declarative routing
- **[little-x](../../examples/little-x/)**: Social media app with third-party libraries
- **[todo-app](../../examples/todo-app/)**: Full-featured todo app with authentication
- **[basic-full-stack](../../examples/basic-full-stack/)**: Full-stack app with backend integration

---

## 💡 Key Takeaways

1. **Single Language**: Write frontend and backend in Jac
2. **No HTTP Client**: Use `__jacSpawn()` instead of fetch/axios
3. **Reactive State**: `createState()` manages UI updates automatically
4. **Component-Based**: Build reusable UI components with JSX
5. **Type Safety**: Jac provides type checking across frontend and backend
6. **Graph Database**: Built-in graph data model eliminates need for SQL/NoSQL

Happy coding with Jac! 🎉
