# Day Planner 3: Building the Backend API

**Outcome:** Building the Backend API. **Prerequisite:** complete [lesson 2](day-planner-02-nodes.md) or restore its complete-code checkpoint.

Work through the examples in order. Partial snippets extend the current file; blocks labeled complete contain the replacement file for that stage.

## Part 3: Building the Backend API

This lesson adds HTTP endpoints to create, list, update, and delete tasks. Jac derives their request and response schemas from the function declarations.

**Create the Project**

```bash
jac create day-planner --kind web-app
cd day-planner
```

!!! note "Choose a project with a server"
    The `web-app` project includes both a server and a client. Jac uses its managed JavaScript toolchain for frontend bundling; allow dependency installation to finish before starting the app.

You can delete the scaffolded `main.jac` and the `components/` directory -- you'll replace them with the code below. Also create an empty `styles.css` file next to `main.jac` (we'll fill it in Part 4).

**Node Identity with `jid()`**

In Part 2, you learned that every node has a built-in unique identifier. The `jid()` function returns this identifier as a string -- no external libraries or manual ID management needed:

<!-- jac-skip -->
```jac
task = root ++> Task(title="Buy groceries");
print(jid(task));  # e.g., "1be2c28fc5924de28c55f68cc5ccaeb6"
```

You'll use `jid()` in the endpoints below to identify tasks across API calls.

!!! info "Python Imports"
    Jac has full interoperability with the Python ecosystem. The syntax is `import from module { names }` -- you can import anything from the standard library or PyPI. You'll see this in action in Part 5 when we import the AI library.

**def:pub -- Functions as Endpoints**

In a served application, `def:pub` exposes a server function as an HTTP endpoint with generated request parsing, response serialization, and API documentation:

```jac
"""Add a task and return it."""
def:pub add_task(title: str) -> Task {
    task = root ++> Task(title=title);
    return task;
}
```

That single annotation transforms the function into two things simultaneously:

- A server-side function you can call from Jac code
- An HTTP endpoint that clients can call over the network

Consider what this replaces in a traditional web framework: you'd need a route decorator, a request parser to extract `title` from the request body, serialization logic to convert the response to JSON, and error handling for malformed requests. In Jac, the function signature *is* the API contract. The function's parameters define the request schema, and its return type defines the response format. When the return type is a typed object like `Task`, the runtime automatically serializes all its fields -- no manual dict construction needed. And on the client side, the returned object arrives as a proper typed instance: you access `task.title` and `task.done` directly, not dictionary keys. This **typed interop** works for all `obj`, `node`, and `enum` types that cross the client-server boundary.

**Building the CRUD Endpoints**

With that understanding, here are all four CRUD (Create, Read, Update, Delete) operations for managing tasks:

```jac
node Task {
    has title: str,
        done: bool = False;
}

"""Add a task and return it."""
def:pub add_task(title: str) -> Task {
    task = root ++> Task(title=title);
    return task;
}

"""Get all tasks."""
def:pub get_tasks -> list[Task] {
    return [root-->][?:Task];
}

"""Toggle a task's done status."""
def:pub toggle_task(id: str) -> Task | None {
    for task in [root-->][?:Task] {
        if jid(task) == id {
            task.done = not task.done;
            return task;
        }
    }
    return None;
}

"""Delete a task."""
def:pub delete_task(id: str) -> dict[str, str] {
    for task in [root-->][?:Task] {
        if jid(task) == id {
            del task;
            return {"deleted": id};
        }
    }
    return {};
}
```

Before moving on, let's examine the new patterns used in this code. These are foundational data structures you'll use throughout the rest of the tutorial.

**Collections**

**Lists** work like Python -- create with `[]`, access by index, iterate with `for`:

<!-- jac-skip -->
```jac
tasks = ["Buy groceries", "Go running", "Read a book"];
first = tasks[0];          # "Buy groceries"
last = tasks[-1];          # "Read a book"
length = len(tasks);       # 3
tasks.append("Cook dinner");
```

**Dictionaries** use `{"key": value}` syntax:

<!-- jac-skip -->
```jac
task_data = {"id": "1", "title": "Buy groceries", "done": False};
print(task_data["title"]);  # "Buy groceries"
task_data["done"] = True;   # Update a value
```

**List comprehensions** build lists in a single expression:

<!-- jac-skip -->
```jac
# Extract titles from all Task nodes
[t.title for t in [root-->][?:Task]]

# With a filter condition
[t.title for t in [root-->][?:Task] if not t.done]
```

**Run It**

Even without a frontend, you can start the server and interact with your API right away. This is a good practice for verifying your backend logic works correctly before adding UI complexity:

!!! note
    `main.jac` is the default entry point. Since this project uses `main.jac`, you can omit the filename entirely. Both forms below are equivalent.

```bash
jac run main.jac
# or: jac run
```

The server starts on port 8000 by default. Use `--port 3000` to pick a different port.

Open [http://localhost:8000/docs](http://localhost:8000/docs) to see Swagger UI with all your endpoints listed. You can test each one interactively -- expand an endpoint, click "Try it out", fill in the parameters, and hit "Execute." This is a great way to verify your backend works before building a frontend.

You can also visit [http://localhost:8000/graph](http://localhost:8000/graph) to see a visual representation of the data graph attached to `root`. Right now it will be empty, but once you add tasks (try it from the Swagger UI!), you'll see them appear as nodes connected to `root`.

!!! info "`jac` vs `jac run`"
    In Parts 1-2 we used `jac <file>` to run scripts. `jac run <file>` launches a web server that serves `def:pub` endpoints and any frontend components. Use `jac` for scripts, `jac run` for web apps.

!!! warning "Common issue"
    If you see "Address already in use", another process is on that port. Use `--port` to pick a different one.

**What You Learned**

- **`def:pub`** -- functions that auto-become HTTP endpoints
- **`jid(node)`** -- get the unique identifier of any node (no manual ID management needed)
- **List comprehensions** -- `[expr for x in list]` and `[expr for x in list if cond]`
- **Dictionaries** -- `{"key": value}` for structured data
- **`jac run`** -- run the web server

!!! example "Try It Yourself"
    Add a `get_pending_tasks` endpoint that returns only tasks where `done` is `False`. Hint: add an `if not t.done` condition to the list comprehension from `get_tasks`.

---

## Checkpoint

Run the development server with the complete backend shown in this lesson. Use its API documentation to create a task, list it, update it, and delete it. Confirm each change in a subsequent list response.

[Lesson overview](build-ai-day-planner.md) · [Previous lesson](day-planner-02-nodes.md) · [Next lesson](day-planner-04-frontend.md)
