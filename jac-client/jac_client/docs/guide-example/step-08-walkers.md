# Step 8: Backend with Walkers

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll add a **real backend** to your app using walkers - so your todos are stored on a server!

---

## Part 1: Building the App

### Step 8.1: Define the Todo Node

First, let's define our data structure. Add this **OUTSIDE** the `cl { }` block (at the top of your file):

```jac
# Backend - Data Model
node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - We'll add walkers here soon

# Note: useState is auto-injected, only useEffect needs explicit import
cl import from react {useEffect}

cl {
    # ... your frontend code
}
```

### Step 8.2: Create Your First Walker - Read Todos

Add these walkers **AFTER** the node definition but **BEFORE** the `cl {` block:

```jac
# Backend - Data Model
node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - Walkers
walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with Todo entry {
        report here;
    }
}

cl import from react {useState, useEffect}

cl {
    # ... your frontend code
}
```

### Step 8.3: Create Walker for Adding Todos

Add this walker:

```jac
walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}
```

### Step 8.4: Create Walkers for Toggle and Delete

Add these walkers:

```jac
walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}
```

Your complete backend should now look like this:

```jac
# Backend - Data Model
node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - Walkers
walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with Todo entry {
        report here;
    }
}

walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}

# Frontend (keep all your existing code)
# Note: useState is auto-injected, only useEffect needs explicit import
cl import from react {useEffect}

cl {
    # ... all your frontend components
}
```

### Step 8.5: Call Walkers from Frontend - Load Todos

Update your `useEffect` to load todos from the backend:

```jac
def:pub app() -> any {
    [todos, setTodos] = useState([]);
    [input, setInput] = useState("");
    [filter, setFilter] = useState("all");

    # Load todos from backend when app mounts
    useEffect(lambda -> None {
        async def loadTodos() -> None {
            result = root spawn read_todos();
            setTodos(result.reports if result.reports else []);
        }
        loadTodos();
    }, []);

    # ... rest of your code
}
```

### Step 8.6: Call Walkers from Frontend - Add Todo

Update your `addTodo` function:

```jac
# Add todo
async def addTodo() -> None {
    if not input.trim() {
        return;
    }

    # Call backend walker
    result = root spawn create_todo(text=input.trim());

    # Add the new todo to local state
    setTodos(todos.concat([result.reports[0][0]]));
    setInput("");
}
```

### Step 8.7: Call Walkers from Frontend - Toggle and Delete

Update your toggle and delete functions:

```jac
# Toggle todo
async def toggleTodo(id: any) -> None {
    # Call backend walker
    id spawn toggle_todo();

    # Update local state
    setTodos(todos.map(lambda todo: any -> any {
        if todo._jac_id == id {
            return {
                "_jac_id": todo._jac_id,
                "text": todo.text,
                "done": not todo.done
            };
        }
        return todo;
    }));
}

# Delete todo
async def deleteTodo(id: any) -> None {
    # Call backend walker
    #id spawn delete_todo();

    # Update local state
    setTodos(todos.filter(lambda todo: any -> bool {
        return todo._jac_id != id;
    }));
}
```

### Step 8.8: Update TodoItem to Use _jac_id

When rendering todos, use `_jac_id` instead of custom id:

```jac
# In your app() function
<div>
    {filteredTodos.map(lambda todo: any -> any {
        return <TodoItem
            key={todo._jac_id}
            id={todo._jac_id}
            text={todo.text}
            done={todo.done}
            toggleTodo={toggleTodo}
            deleteTodo={deleteTodo}
        />;
    })}
</div>
```

**Try it!**

1. Add some todos
2. Check/uncheck them
3. Delete some
4. **Refresh the page** - your todos persist!

---

**⏭ Want to skip the theory?** Jump to [Step 9: Authentication](./step-09-authentication.md)

---

## Part 2: Understanding the Concepts

### What Are Walkers?

Walkers are **backend functions** that:

- Run on the **server** (not in the browser)
- Can traverse your data graph
- Automatically become API endpoints
- Are called from your frontend

**Traditional way (Flask):**

```python
# Backend - separate file
@app.route("/api/todos", methods=["GET"])
def get_todos():
    todos = db.query(Todo).all()
    return jsonify(todos)
```

**Jac way:**

```jac
# Backend - same file!
walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }
    can report_todos with Todo entry {
        report here;
    }
}
```

No routes, no manual API setup - it just works!

### The `spawn` Syntax

This is how you call walkers from your frontend:

```jac
# Syntax
node_reference spawn walker_name(parameters);

# Examples
root spawn read_todos();                    # On root node
root spawn create_todo(text="New todo");   # With parameters
todoId spawn toggle_todo();                 # On specific node
```

**What happens:**

1. Request sent to server
2. Walker runs on server
3. Data stored in backend
4. Response sent back to frontend

### Graph Structure

Your data is stored as a graph:

```
     root (your root node)
      |
      +---> Todo("Learn Jac")
      |
      +---> Todo("Build app")
      |
      +---> Todo("Deploy")
```

When you call `read_todos`:

1. Walker starts at `root`
2. Follows edges (`-->`) to find Todo nodes
3. Reports each Todo found

### Creating Connections (++>)

```jac
new_todo = here ++> Todo(text=self.text);
```

**Breakdown:**

- `here` - Current node (root)
- `++>` - Create node and connect it
- `Todo(...)` - New node to create
- Result: New Todo connected to root

### Visiting Nodes

```jac
visit [-->(`?Todo)];
```

**Breakdown:**

- `visit` - Traverse to these nodes
- `-->` - Follow outgoing edges
- `` `?Todo `` - Find nodes of type Todo
- `[...]` - Array of nodes to visit

### Reporting Data

```jac
report new_todo;        # Report a node
report here;            # Report current node
report {"success": True};  # Report an object
```

`report` sends data back to the frontend. All reports are collected in the `result.reports` array.

### The `_jac_id` Field

Every node gets a unique `_jac_id`:

```jac
todo = result.reports[0][0];
console.log(todo._jac_id);  # "urn:uuid:abc123..."
```

Use this ID to reference specific nodes:

```jac
todoId spawn toggle_todo();  # Operates on that specific todo
```

### Backend vs Frontend Code

```jac
# Backend (runs on server)
node Todo {
    has text: str;
}

walker create_todo {
    has text: str;
    can create with `root entry {
        # This code runs on the server
    }
}

# Frontend (runs in browser)
cl {
    def:pub app() -> any {
        # This code runs in the browser
        result = root spawn create_todo(text="Todo");
    }
}
```

### Data Persistence

**localStorage (Step 7):**

- Stored in browser only
- Lost when you clear browser data
- Not shared across devices

**Walkers (Step 8):**

- Stored on server
- Persists forever
- Accessible from any device
- Per-user (each user sees only their data)

### async/await for Walkers

Walker calls are asynchronous:

```jac
# Must use async/await
async def addTodo() -> None {
    result = await root spawn create_todo(text="Todo");
    # Wait for result before continuing
}

# Or use it in a lambda
useEffect(lambda -> None {
    async def loadTodos() -> None {
        result = await root spawn read_todos();
        setTodos(result.reports);
    }
    loadTodos();
}, []);
```

---

## What You've Learned

- What walkers are (backend functions)
- How to define data models with nodes
- Creating walkers for CRUD operations
- Calling walkers from frontend with `spawn`
- Graph traversal (`-->`, `` `?Node ``)
- Creating node connections (`++>`)
- Reporting data to frontend
- Using `_jac_id` for node references
- Data persistence on the server

---

## Common Issues

### Issue: Walker not found

**Check:** Is the walker defined OUTSIDE the `cl { }` block?

```jac
#  Correct
walker read_todos {
    # ...
}

cl {
    # frontend code
}

#  Wrong
cl {
    walker read_todos {  # Can't define walkers in frontend!
        # ...
    }
}
```

### Issue: Empty reports array

**Check:** Did you call `report` in your walker?

```jac
#  Wrong - no report
can read with `root entry {
    visit [-->(`?Todo)];
}

#  Correct - report in Todo entry
can report_todos with Todo entry {
    report here;
}
```

### Issue: "Cannot read property '_jac_id'"

**Check:** Is `result.reports` empty? Does the todo exist?

```jac
# Safe access
if result.reports and result.reports.length > 0 {
    todo = result.reports[0][0];
    console.log(todo._jac_id);
}
```

### Issue: Data not persisting

**Check:**

- Are you calling the walker? `root spawn create_todo(...)`
- Is the walker running successfully? Check browser console
- Did you remove the localStorage code? (We don't need it anymore!)

---

## Quick Exercise

Try adding a walker to clear all completed todos:

```jac
walker clear_completed {
    can clear with `root entry {
        visit [-->(`?Todo)];
    }

    can delete_if_done with Todo entry {
        if here.done {
            here.destroy();
        }
    }
}

# Call from frontend
async def clearCompleted() -> None {
    await root spawn clear_completed();
    setTodos(todos.filter(lambda todo: any -> bool {
        return not todo.done;
    }));
}
```

---

## Next Step

Excellent! Your app now has a real backend. But there's a problem: **everyone can see everyone's todos!**

In the next step, we'll add **authentication** to make your app secure and private!

 **[Continue to Step 9: Authentication](./step-09-authentication.md)**
