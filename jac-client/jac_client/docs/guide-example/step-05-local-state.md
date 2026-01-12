# Step 5: Local State

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll learn about **state** - the data that makes your app interactive and dynamic!

---

## Part 1: Building the App

### Step 5.1: First, Let's See Why Normal Variables Don't Work

Let's try using a normal variable to track todos:

```jac
cl {
    # ... (keep all your components from Step 4)

    def:pub app() -> any {
        # Try using a normal variable
        todos = [
            {"text": "Learn Jac", "done": false},
            {"text": "Build app", "done": false}
        ];

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos ({todos.length})</h1>
            <p>Todos: {todos.length}</p>
        </div>;
    }
}
```

This works for displaying data, but **what if we want to change it?** Normal variables can't trigger UI updates!

### Step 5.2: Introducing `useState`

To make data interactive, we need `useState`. When you use `has` variables in `cl {}` blocks or `.cl.jac` files, the `useState` import is **automatically injected** - you don't need to import it manually!

```jac
cl {
    def:pub app() -> any {
        # Create state with useState
        # Note: No import needed - useState is auto-injected when using has variables
        [todos, setTodos] = useState([]);

        return <div style={{"padding": "20px"}}>
            <h1>My Todos</h1>
            <p>Total: {todos.length}</p>
        </div>;
    }
}
```

> **Note:** The `useState` import from React is automatically injected when you use `has` variables in `cl {}` blocks or `.cl.jac` files. You no longer need to explicitly import it!

**What's happening:**

- `useState([])` creates state with initial value `[]` (empty array)
- Returns two things:
  - `todos` - The current value (read-only)
  - `setTodos` - Function to update the value

### Step 5.3: Add State for Input Field

Let's make the input field work:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoInput(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <input
                type="text"
                value={props.input}
                placeholder="What needs to be done?"
                style={{
                    "flex": "1",
                    "padding": "8px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px"
                }}
            />
            <button style={{
                "padding": "8px 16px",
                "background": "#3b82f6",
                "color": "#ffffff",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                Add
            </button>
        </div>;
    }

    def:pub app() -> any {
        # State for input field
        [input, setInput] = useState("");

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoInput input={input} />
            <p>You typed: {input}</p>
        </div>;
    }
}
```

**Try typing in the input!** Nothing happens yet because we haven't connected the onChange event (we'll do that in the next step).

### Step 5.4: Add State for Todos List

Now let's track our todos list with state:

```jac
# No useState import needed - it's auto-injected!

cl {
    def TodoItem(props: any) -> any {
        return <div style={{
            "display": "flex",
            "alignItems": "center",
            "gap": "10px",
            "padding": "10px",
            "borderBottom": "1px solid #e5e7eb"
        }}>
            <input type="checkbox" checked={props.done} />
            <span style={{
                "flex": "1",
                "textDecoration": ("line-through" if props.done else "none"),
                "color": ("#999" if props.done else "#000")
            }}>
                {props.text}
            </span>
            <button style={{
                "padding": "4px 8px",
                "background": "#ef4444",
                "color": "white",
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                Delete
            </button>
        </div>;
    }

    def:pub app() -> any {
        # State for todos
        [todos, setTodos] = useState([
            {"text": "Learn Jac basics", "done": false},
            {"text": "Build a todo app", "done": false}
        ]);

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px",
            "background": "#ffffff",
            "borderRadius": "8px"
        }}>
            <h1>My Todos</h1>

            # Display todos
            <div>
                {todos.map(lambda todo: any -> any {
                    return <TodoItem
                        text={todo.text}
                        done={todo.done}
                    />;
                })}
            </div>

            # Stats
            <div style={{"marginTop": "16px", "color": "#666"}}>
                {todos.length} items total
            </div>
        </div>;
    }
}
```

### Step 5.5: Add State for Filter

Let's add filter state:

```jac
# No useState import needed - it's auto-injected!

cl {
    # ... (keep all previous components)

    def TodoFilters(props: any) -> any {
        return <div style={{
            "display": "flex",
            "gap": "8px",
            "marginBottom": "16px"
        }}>
            <button style={{
                "padding": "6px 12px",
                "background": ("#3b82f6" if props.filter == "all" else "#e5e7eb"),
                "color": ("#ffffff" if props.filter == "all" else "#000000"),
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                All
            </button>
            <button style={{
                "padding": "6px 12px",
                "background": ("#3b82f6" if props.filter == "active" else "#e5e7eb"),
                "color": ("#ffffff" if props.filter == "active" else "#000000"),
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                Active
            </button>
            <button style={{
                "padding": "6px 12px",
                "background": ("#3b82f6" if props.filter == "completed" else "#e5e7eb"),
                "color": ("#ffffff" if props.filter == "completed" else "#000000"),
                "border": "none",
                "borderRadius": "4px",
                "cursor": "pointer"
            }}>
                Completed
            </button>
        </div>;
    }

    def:pub app() -> any {
        [todos, setTodos] = useState([
            {"text": "Learn Jac basics", "done": false},
            {"text": "Build a todo app", "done": true}
        ]);
        [filter, setFilter] = useState("all");

        return <div style={{
            "maxWidth": "600px",
            "margin": "20px auto",
            "padding": "20px"
        }}>
            <h1>My Todos</h1>
            <TodoFilters filter={filter} />

            # Show current filter
            <p>Current filter: {filter}</p>
        </div>;
    }
}
```

**Notice:** The filter buttons now highlight based on the current filter! But clicking them doesn't work yet (we'll add that in Step 6).

---

**⏭ Want to skip the theory?** Jump to [Step 6: Event Handlers](./step-06-events.md)

---

## Part 2: Understanding the Concepts

### What is State?

**State** is data that can change over time and causes your UI to update when it changes.

**Python analogy:**

```python
# Python class with state
class TodoApp:
    def __init__(self):
        self.todos = []  # This is state

    def add_todo(self, text):
        self.todos.append(text)  # Changing state
        self.render()  # Manually update UI
```

```jac
# Jac with React
def:pub app() -> any {
    [todos, setTodos] = useState([]);  # This is state

    # When you call setTodos(), React automatically updates the UI!
}
```

### The `useState` Hook

```jac
[value, setValue] = useState(initialValue);
```

**Returns a pair:**

1. `value` - Current state value (read-only, don't modify directly!)
2. `setValue` - Function to update state

**Examples:**

```jac
# String state
[name, setName] = useState("Alice");

# Number state
[count, setCount] = useState(0);

# Boolean state
[isOpen, setIsOpen] = useState(false);

# Array state
[todos, setTodos] = useState([]);

# Object state
[user, setUser] = useState({"name": "Alice", "age": 30});
```

### Why Use `useState`?

**Without useState (doesn't work):**

```jac
def:pub app() -> any {
    count = 0;  # Normal variable

    # Button click would change count, but UI won't update!
    return <button>Count: {count}</button>;
}
```

**With useState (works!):**

```jac
def:pub app() -> any {
    [count, setCount] = useState(0);  # State

    # When setCount is called, React re-renders the component!
    return <button>Count: {count}</button>;
}
```

### Multiple State Variables

You can have multiple pieces of state:

```jac
def:pub app() -> any {
    [todos, setTodos] = useState([]);
    [input, setInput] = useState("");
    [filter, setFilter] = useState("all");
    [loading, setLoading] = useState(false);

    # Use them independently
}
```

Each state variable is independent and has its own update function.

### State Naming Convention

Follow this pattern:

```jac
# Pattern: [thing, setThing]
[count, setCount] = useState(0);
[name, setName] = useState("");
[isOpen, setIsOpen] = useState(false);
[todos, setTodos] = useState([]);

#  Bad names
[count, updateCount] = useState(0);  # Inconsistent
[x, y] = useState(0);                 # Not descriptive
```

### The `.map()` Method for Lists

To render a list of items, use `.map()`:

```jac
{todos.map(lambda todo: any -> any {
    return <TodoItem text={todo.text} done={todo.done} />;
})}
```

**How it works:**

```python
# Python equivalent
todos = [{"text": "Task 1"}, {"text": "Task 2"}]
items = [TodoItem(text=todo["text"]) for todo in todos]
```

**Breakdown:**

- `todos.map(...)` - Loop through each todo
- `lambda todo: any -> any { ... }` - Function that runs for each item
- `return <TodoItem ... />` - Returns a component for each item

### State is Immutable

**Never modify state directly:**

```jac
#  WRONG - Never do this!
[todos, setTodos] = useState([]);
todos.push(newTodo);  # DON'T modify directly!

#  CORRECT - Create new array
[todos, setTodos] = useState([]);
setTodos(todos.concat([newTodo]));  # Create new array
```

Why? Because React needs to detect changes to update the UI. If you modify directly, React won't know it changed!

### Passing State to Children

State flows down through props:

```jac
def Parent() -> any {
    [name, setName] = useState("Alice");

    # Pass state down as props
    return <Child name={name} />;
}

def Child(props: any) -> any {
    # Access state via props
    return <div>Hello, {props.name}!</div>;
}
```

The child receives state but **cannot modify** the parent's state directly (we'll learn how to do that with callbacks in the next step).

---

## What You've Learned

- What state is and why we need it
- How to use the `useState` hook
- Creating multiple state variables
- State naming conventions
- Using `.map()` to render lists
- State is immutable (don't modify directly)
- Passing state to child components via props

---

## Common Issues

### Issue: UI not updating when state changes

**Check:** Are you modifying state directly?

```jac
#  Wrong
todos.push(newTodo);

#  Correct
setTodos(todos.concat([newTodo]));
```

### Issue: "todos is not iterable"

**Check:** Did you initialize state as an array?

```jac
#  Wrong
[todos, setTodos] = useState();  # undefined

#  Correct
[todos, setTodos] = useState([]);  # empty array
```

### Issue: useState is not defined

**Check:** Are you using `useState` inside a `cl {}` block or `.cl.jac` file? The `useState` import is automatically injected when using `has` variables in these contexts. If you're still seeing this error, make sure your code is within the `cl {}` block.

---

## Quick Exercise

Try adding more initial todos:

```jac
[todos, setTodos] = useState([
    {"text": "Learn Jac basics", "done": true},
    {"text": "Build a todo app", "done": false},
    {"text": "Deploy to production", "done": false},
    {"text": "Celebrate!", "done": false}
]);
```

And display the count of completed todos:

```jac
completedCount = todos.filter(lambda todo: any -> bool {
    return todo.done;
}).length;

return <div>
    <p>{completedCount} completed out of {todos.length}</p>
</div>;
```

---

## Next Step

Great! You now have state in your app, but you can't change it yet. Clicking buttons does nothing!

In the next step, we'll add **event handlers** to make your app fully interactive!

 **[Continue to Step 6: Event Handlers](./step-06-events.md)**
