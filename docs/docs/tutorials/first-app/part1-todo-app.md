# Part 1: Build a Todo App

Build a working full-stack todo app in a single file. No frameworks, no boilerplate -- just Jac.

**Prerequisites:** [Installation](../../quick-guide/install.md) complete, [Hello World](../../quick-guide/hello-world.md) done.

---

## Create the Project

```bash
jac create my-todo --use client --skip
cd my-todo
```

`--skip` skips the interactive prompts after creation. You don't need to run `jac install` separately -- `jac start` handles dependency installation automatically.

Now replace `main.jac` with the code below and create `styles.css` in your project root:

```css
.container { max-width: 500px; margin: 40px auto; font-family: system-ui; padding: 20px; }
.input-row { display: flex; gap: 8px; margin-bottom: 20px; }
.input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 1rem; }
.btn-add { padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }
.todo-item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; gap: 10px; }
.todo-title { flex: 1; }
.todo-done { text-decoration: line-through; color: #888; }
.btn-delete { background: #e53e3e; color: white; border: none; border-radius: 4px; padding: 5px 10px; cursor: pointer; }
.count { text-align: center; color: #888; margin-top: 16px; font-size: 0.9rem; }
```

We'll walk through each piece of `main.jac` below.

---

## Define Your Data

```jac
import from uuid { uuid4 }
cl import "./styles.css";

# A node becomes a persistent data container in the graph when attached to a root node
node Todo {
    has id: str,
        title: str,
        done: bool = False;
}
```

A `node` is a data type that can live in Jac's built-in graph database. Unlike a regular class, nodes can persist across server restarts (when attached to the global `root`) -- no external database setup needed. `has` declares the node's properties with types and optional defaults.

Two imports: `uuid` is a standard Python library (Jac can import any Python package), and `cl import` is a client-side import that loads CSS in the browser.

---

## Create Server Endpoints

```jac
"""Add a todo and return it."""
def:pub add_todo(title: str) -> dict {
    todo = root ++> Todo(id=str(uuid4()), title=title);
    return {"id": todo[0].id, "title": todo[0].title, "done": todo[0].done};
}

"""Get all todos."""
def:pub get_todos -> list {
    return [{"id": t.id, "title": t.title, "done": t.done} for t in [root-->](?:Todo)];
}

"""Toggle a todo's done status."""
def:pub toggle_todo(id: str) -> dict {
    for todo in [root-->](?:Todo) {
        if todo.id == id {
            todo.done = not todo.done;
            return {"id": todo.id, "title": todo.title, "done": todo.done};
        }
    }
    return {};
}

"""Delete a todo."""
def:pub delete_todo(id: str) -> dict {
    for todo in [root-->](?:Todo) {
        if todo.id == id {
            del todo;
            return {"deleted": id};
        }
    }
    return {};
}
```

There's a lot of new syntax here. Let's unpack it:

**`def:pub`** marks a function as public. Jac automatically generates an HTTP endpoint for every `def:pub` function -- you don't write routes, controllers, or serializers. The function *is* the API.

**`root ++> Todo(...)`** creates a new Todo node and connects it to `root` with an edge. `root` is the graph's built-in entry point -- think of it as the top of your data tree. The `++>` operator returns a list, so `todo[0]` grabs the newly created node.

**`[root-->](?:Todo)`** reads as "all nodes connected from root that are Todo nodes." It's a graph query -- the `(?:Type)` syntax filters by node type.

Your data ends up looking like this:

```
root ---> Todo("Buy groceries")
  |-----> Todo("Write tests")
  |-----> Todo("Call dentist")
```

---

## Build the Frontend

```jac
cl def:pub app -> JsxElement {
    has items: list = [],
        text: str = "";

    async can with entry {
        items = await get_todos();
    }

    async def add -> None {
        if text.strip() {
            todo = await add_todo(text.strip());
            items = items.concat([todo]);
            text = "";
        }
    }

    async def toggle(id: str) -> None {
        await toggle_todo(id);
        items = items.map(
            lambda t: any -> any {
                return {"id": t.id, "title": t.title, "done": not t.done}
                if t.id == id else t;
            }
        );
    }

    async def remove(id: str) -> None {
        await delete_todo(id);
        items = items.filter(lambda t: any -> bool { return t.id != id; });
    }

    remaining = len(items.filter(lambda t: any -> bool { return not t.done; }));

    return
        <div class="container">
            <h1>Todo App</h1>
            <div class="input-row">
                <input
                    class="input"
                    value={text}
                    onChange={lambda e: any -> None { text = e.target.value; }}
                    onKeyPress={lambda e: any -> None {
                        if e.key == "Enter" { add(); }
                    }}
                    placeholder="What needs to be done?"
                />
                <button class="btn-add" onClick={add}>Add</button>
            </div>
            {[
                <div key={t.id} class="todo-item">
                    <input
                        type="checkbox"
                        checked={t.done}
                        onChange={lambda -> None { toggle(t.id); }}
                    />
                    <span class={"todo-title " + ("todo-done" if t.done else "")}>
                        {t.title}
                    </span>
                    <button
                        class="btn-delete"
                        onClick={lambda -> None { remove(t.id); }}
                    >
                        X
                    </button>
                </div> for t in items
            ]}
            <div class="count">{remaining} items remaining</div>
        </div>;
}
```

The `cl` prefix means this code runs in the browser, not on the server. `def:pub app` declares the main component that Jac renders.

**`has items: list = []`** declares reactive state. When `items` changes, the UI re-renders -- same idea as React's `useState`, but declared as properties instead of function calls.

**`can with entry`** is a lifecycle ability that runs when the component mounts. It fetches todos from the server on first load.

The key thing to notice: **`await add_todo(text)`** calls the server function as if it were local. Because `add_todo` is `def:pub`, Jac generated an HTTP endpoint on the server and a matching client stub automatically. You never think about HTTP.

The rest is JSX-like syntax: `{[... for t in items]}` renders a list, `lambda` handles events, and `{expression}` embeds values.

---

## Run It

??? note "Complete `main.jac` for copy-paste"

    ```jac
    import from uuid { uuid4 }
    cl import "./styles.css";

    node Todo {
        has id: str,
            title: str,
            done: bool = False;
    }

    """Add a todo and return it."""
    def:pub add_todo(title: str) -> dict {
        todo = root ++> Todo(id=str(uuid4()), title=title);
        return {"id": todo[0].id, "title": todo[0].title, "done": todo[0].done};
    }

    """Get all todos."""
    def:pub get_todos -> list {
        return [{"id": t.id, "title": t.title, "done": t.done} for t in [root-->](?:Todo)];
    }

    """Toggle a todo's done status."""
    def:pub toggle_todo(id: str) -> dict {
        for todo in [root-->](?:Todo) {
            if todo.id == id {
                todo.done = not todo.done;
                return {"id": todo.id, "title": todo.title, "done": todo.done};
            }
        }
        return {};
    }

    """Delete a todo."""
    def:pub delete_todo(id: str) -> dict {
        for todo in [root-->](?:Todo) {
            if todo.id == id {
                del todo;
                return {"deleted": id};
            }
        }
        return {};
    }

    cl def:pub app -> JsxElement {
        has items: list = [],
            text: str = "";

        async can with entry {
            items = await get_todos();
        }

        async def add -> None {
            if text.strip() {
                todo = await add_todo(text.strip());
                items = items.concat([todo]);
                text = "";
            }
        }

        async def toggle(id: str) -> None {
            await toggle_todo(id);
            items = items.map(
                lambda t: any -> any {
                    return {"id": t.id, "title": t.title, "done": not t.done}
                    if t.id == id else t;
                }
            );
        }

        async def remove(id: str) -> None {
            await delete_todo(id);
            items = items.filter(lambda t: any -> bool { return t.id != id; });
        }

        remaining = len(items.filter(lambda t: any -> bool { return not t.done; }));

        return
            <div class="container">
                <h1>Todo App</h1>
                <div class="input-row">
                    <input
                        class="input"
                        value={text}
                        onChange={lambda e: any -> None { text = e.target.value; }}
                        onKeyPress={lambda e: any -> None {
                            if e.key == "Enter" { add(); }
                        }}
                        placeholder="What needs to be done?"
                    />
                    <button class="btn-add" onClick={add}>Add</button>
                </div>
                {[
                    <div key={t.id} class="todo-item">
                        <input
                            type="checkbox"
                            checked={t.done}
                            onChange={lambda -> None { toggle(t.id); }}
                        />
                        <span class={"todo-title " + ("todo-done" if t.done else "")}>
                            {t.title}
                        </span>
                        <button
                            class="btn-delete"
                            onClick={lambda -> None { remove(t.id); }}
                        >
                            X
                        </button>
                    </div> for t in items
                ]}
                <div class="count">{remaining} items remaining</div>
            </div>;
    }
    ```

```bash
jac start main.jac
```

This starts on port 8000 by default. Use `jac start main.jac --port 3000` to pick a different port.

!!! warning "Common issue"
    If you see "Address already in use", another process is on port 8000. Use `--port` to pick a different port, or see [Troubleshooting: Server won't start](../troubleshooting.md#server-wont-start-address-already-in-use).

Open [http://localhost:8000](http://localhost:8000). You should see a clean todo app with an input field and an "Add" button. Try it:

1. Type "Buy groceries" and press Enter -- the todo appears
2. Click the checkbox -- it gets crossed out
3. Click X -- it disappears
4. Stop the server and restart it -- your todos are still there

That last point is important. The data persisted because nodes live in the graph database, not in memory.

---

## What You Learned

You built a full-stack app in a single file with no boilerplate. Here are the Jac concepts you used:

- **`node`** -- persistent data types stored in the graph
- **`def:pub`** -- functions that auto-become HTTP endpoints
- **`root ++>`** -- create nodes and connect them to the graph
- **`[root-->](?:Todo)`** -- query nodes by type
- **`cl def:pub app`** -- client-side component that runs in the browser
- **`has`** -- reactive state that triggers re-renders
- **`can with entry`** -- lifecycle hook (runs on mount)
- **`await func()`** -- call server functions transparently from the client

---

## Next Step

Your todo app works, but every user shares the same data and there's nothing intelligent about it. In [Part 2](part2-ai-features.md), you'll add AI-powered categorization with just a few lines of code.
