# Part 2: Add AI Features

Your todo app works, but it's not very smart. Let's fix that -- you'll add AI-powered categorization so every todo automatically gets labeled as "work", "shopping", "health", and so on. It takes about five lines of new code.

**Prerequisites:** Complete [Part 1](part1-todo-app.md) first.

!!! tip "Starting fresh"
    If you have leftover data from Part 1, delete the `.jac/data/` directory before running Part 2. The schema changes in this part (adding `category`) may conflict with old Todo nodes.

---

## Set Up Your API Key

Jac's AI features use an LLM under the hood. You need an API key from Anthropic (or OpenAI, or Google). Set it as an environment variable:

```bash
export ANTHROPIC_API_KEY="your-key-here"
```

!!! warning "Common issue"
    If you get "API key not found" errors, make sure the environment variable is set in the same terminal where you run `jac`. If adding a todo silently fails (nothing happens), check the terminal running `jac start` for error messages -- a missing or invalid API key causes a server error. See [Troubleshooting: API key issues](../troubleshooting.md#api-key-not-found).

---

## Configure the LLM

Add the byllm import and model configuration to the top of your `main.jac`, right after the existing imports:

```jac
import from uuid { uuid4 }
import from byllm.lib { Model }
cl import "./styles.css";

glob llm = Model(model_name="claude-sonnet-4-20250514");
```

`import from byllm.lib { Model }` loads Jac's AI plugin. `glob llm = Model(...)` initializes the model at module level -- `glob` is Jac's way of declaring a global variable.

---

## Define a Category Enum

Add this after the `glob llm` line:

```jac
enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }
```

An `enum` constrains the AI to return *exactly* one of these values. Without it, the LLM might return "shopping", "Shopping", "groceries", or "grocery shopping" -- all meaning the same thing. The enum eliminates that ambiguity.

---

## Create the AI Function

Here's the key feature. Add this after the enum:

```jac
def categorize(title: str) -> Category by llm();
```

That's the entire function. There's no body -- `by llm()` tells Jac to have the LLM generate the return value. The compiler extracts semantics from the code itself:

- The **function name** -- `categorize` tells the LLM what to do
- The **parameter names and types** -- `title: str` is what the LLM receives
- The **return type** -- `Category` constrains the output to one of the enum values

The function name, parameter names, and types are the specification. The LLM fulfills it.

---

## Wire It Into the Todo Flow

Two changes. First, add a `category` field to the Todo node:

```jac
node Todo {
    has id: str,
        title: str,
        done: bool = False,
        category: str = "other";
}
```

Then update `add_todo` to call the AI:

```jac
"""Add a todo with AI categorization."""
def:pub add_todo(title: str) -> dict {
    category = str(categorize(title)).split(".")[-1].lower();
    todo = root ++> Todo(id=str(uuid4()), title=title, category=category);
    return {
        "id": todo[0].id, "title": todo[0].title,
        "done": todo[0].done, "category": todo[0].category
    };
}
```

The `str(categorize(title)).split(".")[-1].lower()` converts `Category.SHOPPING` to `"shopping"` for clean display.

---

## Update the Other Endpoints

Add `"category"` to the return values of `get_todos` and `toggle_todo`:

```jac
"""Get all todos."""
def:pub get_todos -> list {
    return [
        {"id": t.id, "title": t.title, "done": t.done, "category": t.category}
        for t in [root-->](`?Todo)
    ];
}

"""Toggle a todo's done status."""
def:pub toggle_todo(id: str) -> dict {
    for todo in [root-->](`?Todo) {
        if todo.id == id {
            todo.done = not todo.done;
            return {
                "id": todo.id, "title": todo.title,
                "done": todo.done, "category": todo.category
            };
        }
    }
    return {};
}
```

`delete_todo` doesn't need changes -- it doesn't return todo data.

---

## Update the Frontend

Two small changes in the `app` component. In the `toggle` method, include `category` in the mapped object:

```jac
    async def toggle(id: str) -> None {
        await toggle_todo(id);
        items = items.map(
            lambda t: any -> any {
                return {
                    "id": t.id, "title": t.title,
                    "done": not t.done, "category": t.category
                }
                if t.id == id else t;
            }
        );
    }
```

And in the todo list rendering, add a category badge after the title span:

```html
                    <span class={"todo-title " + ("todo-done" if t.done else "")}>
                        {t.title}
                    </span>
                    <span class="category">{t.category}</span>
```

---

## Add Category Styling

Add one line to `styles.css`:

```css
.category { padding: 2px 8px; background: #e0e0e0; border-radius: 12px; font-size: 12px; margin-right: 10px; }
```

---

## Run It

??? note "Complete `main.jac` for copy-paste"

    ```jac
    import from uuid { uuid4 }
    import from byllm.lib { Model }
    cl import "./styles.css";

    glob llm = Model(model_name="claude-sonnet-4-20250514");

    enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

    node Todo {
        has id: str,
            title: str,
            done: bool = False,
            category: str = "other";
    }

    """Categorize a todo based on its title."""
    def categorize(title: str) -> Category by llm();

    """Add a todo with AI categorization."""
    def:pub add_todo(title: str) -> dict {
        category = str(categorize(title)).split(".")[-1].lower();
        todo = root ++> Todo(id=str(uuid4()), title=title, category=category);
        return {
            "id": todo[0].id, "title": todo[0].title,
            "done": todo[0].done, "category": todo[0].category
        };
    }

    """Get all todos."""
    def:pub get_todos -> list {
        return [
            {"id": t.id, "title": t.title, "done": t.done, "category": t.category}
            for t in [root-->](`?Todo)
        ];
    }

    """Toggle a todo's done status."""
    def:pub toggle_todo(id: str) -> dict {
        for todo in [root-->](`?Todo) {
            if todo.id == id {
                todo.done = not todo.done;
                return {
                    "id": todo.id, "title": todo.title,
                    "done": todo.done, "category": todo.category
                };
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
                lambda t: any -> any {
                    return {
                        "id": t.id, "title": t.title,
                        "done": not t.done, "category": t.category
                    }
                    if t.id == id else t;
                }
            );
        }

        async def remove(id: str) -> None {
            await delete_todo(id);
            items = items.filter(lambda t: any -> bool { return t.id != id; });
        }

        remaining = items.filter(lambda t: any -> bool { return not t.done; }).length;

        return
            <div class="container">
                <h1>AI Todo App</h1>
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
                        <span class="category">{t.category}</span>
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
export ANTHROPIC_API_KEY="your-key"
jac start main.jac
```

!!! warning "Common issue"
    If you see "Address already in use", use `--port` to pick a different port: `jac start main.jac --port 3000`.

Open [http://localhost:8000](http://localhost:8000). The app looks the same as before, but now when you add a todo it takes a moment longer -- the LLM is categorizing it behind the scenes. Try it:

1. Add "Buy groceries" -- it appears with a "shopping" badge
2. Add "Schedule dentist appointment" -- tagged as "health"
3. Add "Review pull requests" -- tagged as "work"
4. Add "Call mom" -- tagged as "personal"

The AI can only pick from `WORK`, `PERSONAL`, `SHOPPING`, `HEALTH`, or `OTHER` -- the enum guarantees consistent output every time.

---

## What You Learned

You added AI to your app with minimal code changes:

- **`import from byllm.lib { Model }`** -- load Jac's AI plugin
- **`glob llm = Model(...)`** -- initialize the LLM at module level
- **`enum Category`** -- constrain AI output to specific values
- **`def categorize(...) -> Category by llm()`** -- let the LLM generate a function's return value from its name, parameter names, and types
- **Jac's type system is the LLM's output schema** -- define your types, name things clearly, and `by llm()` handles the rest. Use `sem` to add meaning beyond what names and types convey

---

## Next Step

Your app now has AI, but there's still a problem: every user shares the same todos. In [Part 3](part3-multi-user.md), you'll introduce **walkers** for per-user data isolation, add **authentication**, build an AI-powered **meal planner** with structured outputs, and organize the project into **multiple files**.

**Want to go deeper on AI?** See the [byLLM Quickstart](../ai/quickstart.md) for standalone examples and the [byLLM Reference](../../reference/plugins/byllm.md) for full API docs.
