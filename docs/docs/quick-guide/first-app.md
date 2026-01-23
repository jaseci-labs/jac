# Your First App

Build a complete todo application in Jac. This 10-minute tutorial covers nodes, walkers, and running as an API server.

---

## What We're Building

A simple todo app with:

- Add tasks
- List tasks
- Mark tasks complete
- Persistent storage

---

## Step 1: Define the Data Model

Create `todo.jac`:

```jac
"""A simple todo item."""
node Todo {
    has title: str;
    has done: bool = False;
}
```

**What's happening:**

- `node` defines a graph node (like a class, but graph-aware)
- `has` declares attributes with types
- `done: bool = False` sets a default value

---

## Step 2: Add Walkers

Walkers are objects that traverse the graph and perform operations. Add these to `todo.jac`:

```jac
"""Create a new todo item."""
walker add_todo {
    has title: str;

    can create with `root entry {
        new_todo = here ++> Todo(title=self.title);
        report new_todo;
    }
}

"""List all todo items."""
walker list_todos {
    can list with `root entry {
        for todo in [-->](`?Todo) {
            report todo;
        }
    }
}

"""Mark a todo as complete."""
walker complete_todo {
    has todo_id: str;

    can complete with `root entry {
        for todo in [-->](`?Todo) {
            if str(todo.__jac__.id) == self.todo_id {
                todo.done = True;
                report todo;
            }
        }
    }
}
```

**What's happening:**

- `walker` defines a mobile computation unit
- `has` declares walker parameters (become API inputs)
- `can ... with \`root entry` runs when the walker starts at root
- `here ++> Todo(...)` creates a new node connected to current node
- `[-->](\`?Todo)` queries all connected Todo nodes
- `report` returns data (becomes API response)

---

## Step 3: Test Locally

Add an entry point for testing:

```jac
with entry {
    # Add some todos
    root spawn add_todo(title="Learn Jac");
    root spawn add_todo(title="Build an app");
    root spawn add_todo(title="Deploy to production");

    # List all todos
    print("All todos:");
    todos = root spawn list_todos();
    for todo in todos.reports {
        status = "[x]" if todo.done else "[ ]";
        print(f"  {status} {todo.title}");
    }
}
```

Run it:

```bash
jac todo.jac
```

Output:

```
All todos:
  [ ] Learn Jac
  [ ] Build an app
  [ ] Deploy to production
```

---

## Step 4: Run as an API Server

The same code becomes a REST API with one command:

```bash
jac start todo.jac
```

Open http://localhost:8000/docs to see the Swagger UI.

**Your walkers are now API endpoints:**

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/walker/add_todo` | POST | Create a todo |
| `/walker/list_todos` | POST | List all todos |
| `/walker/complete_todo` | POST | Mark complete |

> **Note:** By default, all walkers require authentication. To make a walker publicly accessible without authentication, use the `pub` modifier: `walker:pub add_todo { ... }`. See [Authentication](../tutorials/fullstack/auth.md) for details.

---

## Step 5: Test the API

For quick testing, make your walkers public by adding `:pub`:

```jac
walker:pub add_todo { ... }
walker:pub list_todos { ... }
walker:pub complete_todo { ... }
```

Then test with curl:

```bash
# Add a todo
curl -X POST http://localhost:8000/walker/add_todo \
  -H "Content-Type: application/json" \
  -d '{"title": "Test the API"}'

# List todos
curl -X POST http://localhost:8000/walker/list_todos
```

Or use the Swagger UI at http://localhost:8000/docs.

---

## Complete Code

Here's the full `todo.jac`:

```jac
"""A simple todo item."""
node Todo {
    has title: str;
    has done: bool = False;
}

"""Create a new todo item."""
walker add_todo {
    has title: str;

    can create with `root entry {
        new_todo = here ++> Todo(title=self.title);
        report new_todo;
    }
}

"""List all todo items."""
walker list_todos {
    can list with `root entry {
        for todo in [-->](`?Todo) {
            report todo;
        }
    }
}

"""Mark a todo as complete."""
walker complete_todo {
    has todo_id: str;

    can complete with `root entry {
        for todo in [-->](`?Todo) {
            if str(todo.__jac__.id) == self.todo_id {
                todo.done = True;
                report todo;
            }
        }
    }
}

# Entry point for local testing
with entry {
    root spawn add_todo(title="Learn Jac");
    root spawn add_todo(title="Build an app");

    print("Todos:");
    for todo in (root spawn list_todos()).reports {
        status = "[x]" if todo.done else "[ ]";
        print(f"  {status} {todo.title}");
    }
}
```

---

## What You Learned

| Concept | What It Does |
|---------|--------------|
| `node` | Defines graph data structures |
| `walker` | Defines mobile computations that become API endpoints |
| `has` | Declares attributes (with type annotations) |
| `++>` | Connects nodes in the graph |
| `[-->]` | Queries connected nodes |
| `report` | Returns data from walkers |
| `jac start` | Runs code as an API server |

---

## Next Steps

- **Add a frontend**: See the [Full-Stack Tutorial](../tutorials/fullstack/setup.md) to add React-style UI
- **Add AI features**: See [AI Integration](../tutorials/ai/quickstart.md) to add LLM capabilities
- **Deploy to production**: Use `jac start todo.jac --scale` for Kubernetes deployment
- **Learn more**: Check out [Next Steps](next-steps.md) for learning paths
