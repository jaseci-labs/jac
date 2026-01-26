# Your First Full-Stack AI App

Build a complete AI-powered todo app through three phases. Each phase is runnable - you'll see your app evolve from a basic fullstack app to one with AI and user authentication.

---

## Phase 1: Functions & Frontend

Start with the simplest full-stack app: functions for server logic, minimal UI in one file.

Create a project:

```bash
jac create my-todo --use client --skip
cd my-todo
```

Create `styles.css` in your project:

```css
.container { max-width: 400px; margin: 40px auto; font-family: system-ui; padding: 20px; }
.input-row { display: flex; gap: 8px; margin-bottom: 20px; }
.input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
.btn-add { padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer; }
.todo-item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; }
.todo-title { flex: 1; margin-left: 10px; }
.todo-done { text-decoration: line-through; color: #888; }
.btn-delete { background: #f44336; color: white; border: none; border-radius: 4px; padding: 5px 10px; cursor: pointer; }
.category { padding: 2px 8px; background: #e0e0e0; border-radius: 12px; font-size: 12px; margin-right: 10px; }
```

Replace `main.jac` with:

```jac
import from uuid { uuid4 }
cl import "./styles.css";

# Data stored in graph nodes (persists across restarts)
node Todo {
    has id: str,
        title: str,
        done: bool = False;
}

# Server functions - def:pub creates HTTP endpoints automatically
"""Add a todo and return it."""
def:pub add_todo(title: str) -> dict {
    todo = root ++> Todo(id=str(uuid4()), title=title);
    return {"id": todo[0].id, "title": todo[0].title, "done": todo[0].done};
}

"""Get all todos."""
def:pub get_todos -> list {
    return [{"id": t.id, "title": t.title, "done": t.done} for t in [root-->](`?Todo)];
}

"""Toggle a todo's done status."""
def:pub toggle_todo(id: str) -> dict {
    for todo in [root-->](`?Todo) {
        if todo.id == id {
            todo.done = not todo.done;
            return {"id": todo.id, "title": todo.title, "done": todo.done};
        }
    }
    return {};
}

"""Delete a todo."""
def:pub delete_todo(id: str) -> dict {
    for todo in [root-->](`?Todo) {
        if todo.id == id {
            del todo;
            return {"deleted": id};
        }
    }
    return {};
}

# Frontend - minimal UI in the same file
cl def:pub app -> any {
    has items: list = [],
        text: str = "";

    async can with entry {
        items = await get_todos();
    }

    async def add -> None {
        if text.trim() {
            todo = await add_todo(text.trim());
            items = items.concat([todo]);
            text = "";
        }
    }

    async def toggle(id: str) -> None {
        await toggle_todo(id);
        items = items.map(
            lambda t: any  -> any { return {
                "id": t.id,
                "title": t.title,
                "done": not t.done
            }
            if t.id == id
            else t; }
        );
    }

    async def remove(id: str) -> None {
        await delete_todo(id);
        items = items.filter(lambda t: any  -> bool { return t.id != id; });
    }

    return
        <div class="container">
            <h1>
                Todo App
            </h1>
            <div class="input-row">
                <input
                    class="input"
                    value={text}
                    onChange={lambda e: any  -> None { text = e.target.value;}}
                    onKeyPress={lambda e: any  -> None { if e.key == "Enter" {
                        add();
                    }}}
                    placeholder="What needs to be done?"
                />
                <button class="btn-add" onClick={add}>
                    Add
                </button>
            </div>
            {[<div key={t.id} class="todo-item">
                <input
                    type="checkbox"
                    checked={t.done}
                    onChange={lambda -> None { toggle(t.id);}}
                />
                <span class={"todo-title " + ("todo-done" if t.done else "")}>
                    {t.title}
                </span>
                <button
                    class="btn-delete"
                    onClick={lambda -> None { remove(t.id);}}
                >
                    X
                </button>
            </div> for t in items]}
        </div>;
}
```

Run it:

```bash
jac start main.jac
```

Open http://localhost:8000 - you have a working app!

**What you learned:**

| Concept | Example |
|---------|---------|
| `node Todo` | Graph node - persistent data container |
| `def:pub add_todo` | Public function - auto HTTP endpoint |
| `root ++> Todo()` | Create node connected to root |
| `[root -->](\`?Todo)` | Query all Todo nodes from root |
| `await func()` | Call server function from client (automatic HTTP) |
| `cl { }` | Client-side code block |
| `has x: type` | Reactive state (like useState) |

---

## Phase 2: Add AI

Now add AI-powered categorization with one line of code.

Update `main.jac` - just add the AI parts:

```jac
import from uuid { uuid4 }
import from byllm { Model }

glob llm = Model(model_name="claude-sonnet-4-20250514");

node Todo {
    has id: str;
    has title: str;
    has done: bool = False;
    has category: str = "other";  # NEW: AI-assigned category
}

"""Categorize a todo. Returns: work, personal, shopping, health, or other."""
def categorize(title: str) -> str by llm();

"""Add a todo with AI categorization."""
def:pub add_todo(title: str) -> dict {
    category = categorize(title);  # NEW: AI categorizes
    todo = root ++> Todo(id=str(uuid4()), title=title, category=category);
    return {"id": todo[0].id, "title": todo[0].title, "done": todo[0].done, "category": todo[0].category};
}

"""Get all todos."""
def:pub get_todos() -> list {
    return [{"id": t.id, "title": t.title, "done": t.done, "category": t.category} for t in [root -->](`?Todo)];
}

"""Toggle a todo's done status."""
def:pub toggle_todo(id: str) -> dict {
    for todo in [root -->](`?Todo) {
        if todo.id == id {
            todo.done = not todo.done;
            return {"id": todo.id, "title": todo.title, "done": todo.done, "category": todo.category};
        }
    }
    return {};
}

"""Delete a todo."""
def:pub delete_todo(id: str) -> dict {
    for todo in [root -->](`?Todo) {
        if todo.id == id {
            del todo;
            return {"deleted": id};
        }
    }
    return {};
}

cl {
    import from react { useEffect }
    import "./styles.css";

    def:pub app -> any {
        has items: list = [];
        has text: str = "";

        useEffect(lambda -> None {
            async def load -> None { items = await get_todos(); }
            load();
        }, []);

        async def add -> None {
            if text.trim() {
                todo = await add_todo(text.trim());
                items = items.concat([todo]);
                text = "";
            }
        }

        async def toggle(id: str) -> None {
            await toggle_todo(id);
            items = items.map(lambda t: any -> any {
                return {"id": t.id, "title": t.title, "done": not t.done, "category": t.category} if t.id == id else t;
            });
        }

        async def remove(id: str) -> None {
            await delete_todo(id);
            items = items.filter(lambda t: any -> bool { return t.id != id; });
        }

        return <div class="container">
            <h1>AI Todo App</h1>
            <div class="input-row">
                <input class="input" value={text} onChange={lambda e: any -> None { text = e.target.value; }}
                    onKeyPress={lambda e: any -> None { if e.key == "Enter" { add(); }}}
                    placeholder="What needs to be done?" />
                <button class="btn-add" onClick={add}>Add</button>
            </div>
            {[<div key={t.id} class="todo-item">
                <input type="checkbox" checked={t.done} onChange={lambda -> None { toggle(t.id); }} />
                <span class={"todo-title " + ("todo-done" if t.done else "")}>{t.title}</span>
                <span class="category">{t.category}</span>
                <button class="btn-delete" onClick={lambda -> None { remove(t.id); }}>X</button>
            </div> for t in items]}
        </div>;
    }
}
```

Set your API key and run:

```bash
export ANTHROPIC_API_KEY="your-key"
jac start main.jac
```

Add "Buy groceries" - it auto-categorizes as "shopping"!

**What you learned:**

| Concept | Example |
|---------|---------|
| `by llm()` | AI generates function body from docstring |
| `glob llm` | Configure the LLM model |

---

## Phase 3: Walkers & Per-User Data

Refactor to **walkers** - Jac's native pattern for graph operations - and add per-user isolation.

**Walkers** are code that moves through the graph, triggering abilities as they enter nodes. Combined with `walker:priv`, each user gets their own data!

Update `main.jac`:

```jac
import from uuid { uuid4 }
import from byllm { Model }

glob llm = Model(model_name="claude-sonnet-4-20250514");

node Todo {
    has id: str;
    has title: str;
    has done: bool = False;
    has category: str = "other";
}

"""Categorize a todo. Returns: work, personal, shopping, health, or other."""
def categorize(title: str) -> str by llm();

# walker:priv means each user has their own root node
walker:priv AddTodo {
    has title: str;

    can create with `root entry {
        category = categorize(self.title);
        new_todo = here ++> Todo(id=str(uuid4()), title=self.title, category=category);
        report {"id": new_todo[0].id, "title": new_todo[0].title, "done": new_todo[0].done, "category": new_todo[0].category};
    }
}

walker:priv ListTodos {
    has todos: list = [];

    can collect with `root entry { visit [-->](`?Todo); }
    can gather with Todo entry {
        self.todos.append({"id": here.id, "title": here.title, "done": here.done, "category": here.category});
    }
    can report_all with `root exit { report self.todos; }
}

walker:priv ToggleTodo {
    has todo_id: str;

    can find with `root entry { visit [-->](`?Todo); }
    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.done = not here.done;
            report {"id": here.id, "title": here.title, "done": here.done, "category": here.category};
        }
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can find with `root entry { visit [-->](`?Todo); }
    can remove with Todo entry {
        if here.id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}

cl {
    import from react { useEffect }
    import from "@jac-client/utils" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
    import "./styles.css";

    def:pub app -> any {
        has items: list = [];
        has text: str = "";
        has isLoggedIn: bool = False;
        has username: str = "";
        has password: str = "";
        has isSignup: bool = False;
        has error: str = "";

        useEffect(lambda -> None { isLoggedIn = jacIsLoggedIn(); }, []);

        useEffect(lambda -> None {
            if isLoggedIn {
                async def load -> None {
                    result = root spawn ListTodos();
                    items = result.reports[0] if result.reports else [];
                }
                load();
            }
        }, [isLoggedIn]);

        async def handleAuth -> None {
            error = "";
            if isSignup {
                result = await jacSignup(username, password);
                if result["success"] { isLoggedIn = True; }
                else { error = result["error"] if result["error"] else "Signup failed"; }
            } else {
                success = await jacLogin(username, password);
                if success { isLoggedIn = True; }
                else { error = "Invalid credentials"; }
            }
        }

        def handleLogout -> None {
            jacLogout();
            isLoggedIn = False;
            items = [];
        }

        async def add -> None {
            if text.trim() {
                result = root spawn AddTodo(title=text.trim());
                items = items.concat([result.reports[0]]);
                text = "";
            }
        }

        async def toggle(id: str) -> None {
            result = root spawn ToggleTodo(todo_id=id);
            items = items.map(lambda t: any -> any {
                return result.reports[0] if t.id == id else t;
            });
        }

        async def remove(id: str) -> None {
            root spawn DeleteTodo(todo_id=id);
            items = items.filter(lambda t: any -> bool { return t.id != id; });
        }

        if not isLoggedIn {
            return <div class="container">
                <h1>{("Sign Up" if isSignup else "Log In")}</h1>
                {(<div style={{"color": "red", "marginBottom": "10px"}}>{error}</div>) if error else None}
                <input class="input" value={username} onChange={lambda e: any -> None { username = e.target.value; }}
                    placeholder="Username" style={{"marginBottom": "10px", "width": "100%"}} />
                <input class="input" type="password" value={password} onChange={lambda e: any -> None { password = e.target.value; }}
                    placeholder="Password" style={{"marginBottom": "10px", "width": "100%"}} />
                <button class="btn-add" onClick={handleAuth} style={{"width": "100%", "marginBottom": "10px"}}>
                    {("Sign Up" if isSignup else "Log In")}
                </button>
                <div style={{"textAlign": "center"}}>
                    <span onClick={lambda -> None { isSignup = not isSignup; error = ""; }} style={{"cursor": "pointer", "color": "#4CAF50"}}>
                        {("Already have an account? Log In" if isSignup else "Need an account? Sign Up")}
                    </span>
                </div>
            </div>;
        }

        return <div class="container">
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "20px"}}>
                <h1 style={{"margin": "0"}}>AI Todo App</h1>
                <button onClick={handleLogout} style={{"padding": "8px 16px", "background": "#f0f0f0", "border": "1px solid #ddd", "borderRadius": "4px", "cursor": "pointer"}}>Log Out</button>
            </div>
            <div class="input-row">
                <input class="input" value={text} onChange={lambda e: any -> None { text = e.target.value; }}
                    onKeyPress={lambda e: any -> None { if e.key == "Enter" { add(); }}}
                    placeholder="What needs to be done?" />
                <button class="btn-add" onClick={add}>Add</button>
            </div>
            {[<div key={t.id} class="todo-item">
                <input type="checkbox" checked={t.done} onChange={lambda -> None { toggle(t.id); }} />
                <span class={"todo-title " + ("todo-done" if t.done else "")}>{t.title}</span>
                <span class="category">{t.category}</span>
                <button class="btn-delete" onClick={lambda -> None { remove(t.id); }}>X</button>
            </div> for t in items]}
        </div>;
    }
}
```

Run it:

```bash
jac start main.jac
```

Now create accounts and see each user has their own todo list!

**What changed:**

| Before (Functions) | After (Walkers) |
|--------------------|-----------------|
| `def:pub add_todo()` | `walker:priv AddTodo { }` |
| `await add_todo(x)` | `root spawn AddTodo(x)` |
| Shared data | Per-user data isolation |
| No auth needed | Login/signup required |

**New concepts:**

| Concept | Purpose |
|---------|---------|
| `walker:priv` | Each authenticated user gets their own root node |
| `visit [-->]` | Walker moves to connected nodes |
| `with Todo entry` | Ability triggered when entering Todo node |
| `root spawn Walker()` | Start walker at graph root |
| `report` | Return data from walker |
| `jacLogin/jacSignup` | Built-in authentication utilities |

---

## Summary

You built the same app three ways:

| Phase | Approach | What You Learned |
|-------|----------|------------------|
| 1 | Functions + Nodes | Graph storage, function endpoints, frontend |
| 2 | + AI | Adding `by llm()` for intelligent features |
| 3 | Walkers + Auth | Graph traversal, per-user isolation |

**When to use each:**

- **Functions (`def:pub`)**: Simple CRUD operations, shared data
- **Walkers**: Complex graph traversals, per-user isolation with `walker:priv`

---

## Next Steps

- **Deploy**: `jac start main.jac --scale` for Kubernetes
- **Advanced AI**: Structured outputs, agents - see [ByLLM Guide](../tutorials/ai/quickstart.md)
- **Graph patterns**: Edges, complex traversals - see [OSP Guide](../tutorials/language/osp.md)
