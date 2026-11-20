# Day Planner 4: A Reactive Frontend

**Outcome:** A Reactive Frontend. **Prerequisite:** complete [lesson 3](day-planner-03-backend.md) or restore its complete-code checkpoint.

Work through the examples in order. Partial snippets extend the current file; blocks labeled complete contain the replacement file for that stage.

## Part 4: A Reactive Frontend

So far, you've been working entirely on the server side. Now you'll learn how Jac handles the frontend. Unlike most backend languages that require a separate JavaScript project for the UI, Jac can render full UIs in the browser using JSX syntax -- similar to React, but without requiring a separate JavaScript toolchain or build system.

**How code becomes client code**

You never label browser code in Jac -- the compiler *infers* it. Declarations whose syntax is client-only (JSX, npm imports, asset imports) are compiled to JavaScript and run in the **browser**, not on the server:

```jac
import "./styles.css";
```

A string-path import like this is a client signal -- CSS only means something in a browser -- so this line and the code that uses it join the client bundle automatically. Add it at the top of your `main.jac`.

**Building the Component**

A `cl def:pub` function returning `JsxElement` is a UI component:

```jac
def:pub app -> JsxElement {
    has tasks: list = [],
        task_text: str = "";

    # ... methods and render tree ...
}
```

Notice the `has` keyword appearing again -- you first saw it in `obj` and `node` declarations. Inside a component, `has` declares **reactive state**. When any of these values change, the UI automatically re-renders to reflect the new data. If you're familiar with React, this is the same concept as `useState`, but expressed as simple property declarations rather than hook function calls.

??? info "You can also use React's `useState` directly"
    Since Jac's client-side code compiles to JavaScript that runs in a React context, you can import and use `useState` from React directly if you prefer:

    ```jac
    import from react { useState }

    def:pub app -> JsxElement {
        (tasks, set_tasks) = useState([]);
        (task_text, set_task_text) = useState("");

        # Use set_tasks([...]) and set_task_text("...") to update state
    }
    ```

    The `has` syntax is Jac's idiomatic approach -- it's more concise and handles the getter/setter pattern for you behind the scenes. But if you're coming from React and prefer the explicit `useState` hook, it works just the same.

**Lifecycle Hooks**

**`can with entry`** runs when the component first mounts (like React's `useEffect` on mount):

```jac
    async can with entry {
        tasks = await get_tasks();
    }
```

This fetches all tasks from the server when the page loads.

??? info "You can also use React's `useEffect` directly"
    If you prefer React's hooks, you can import and use `useEffect` directly:

    ```jac
    import from react { useEffect }

    def:pub app -> JsxElement {
        # ...

        useEffect(lambda {
            async def load {
                tasks = await get_tasks();
            }
            load();
        }, []);
    }
    ```

    The `can with entry` syntax is Jac's shorthand for a `useEffect` with an empty dependency array (run once on mount). For more advanced cases like watching specific dependencies, you can use `useEffect` directly with the appropriate dependency list.

**Lambdas**

Before building the UI, you need to understand **lambdas** -- Jac's anonymous functions. These are essential for event handlers in JSX, where you need to pass small inline functions to respond to user actions like clicks and key presses:

<!-- jac-skip -->
```jac
# Lambda with typed parameters
double = lambda (x: int) -> int { return x * 2; };

# Lambda with no parameters
say_hi = lambda -> str { return "hi"; };
```

The syntax is `lambda (params) -> return_type { body }`. In JSX, you'll use them inline to handle user events:

<!-- jac-skip -->
```jac
onChange={lambda (e: ChangeEvent) { task_text = e.target.value; }}
```

**Transparent Server Calls**

This is one of the most important concepts to understand in Jac's full-stack model: **`await add_task(text)`** calls the server function as if it were local code. Behind the scenes, because `add_task` is `def:pub`, Jac generated both an HTTP endpoint on the server *and* a matching typed client stub in the browser automatically. The client stub handles the HTTP request, JSON serialization, and response parsing for you. You never write fetch calls, parse JSON, or handle HTTP status codes -- the boundary between client and server becomes invisible. And because the server declares `-> Task` as the return type, the client receives a proper `Task` object with `.title` and `.done` fields, and you can use `jid(task)` to get its unique identity -- no raw dictionaries or manual ID management.

```jac
    async def add_new_task {
        if task_text.strip() {
            task = await add_task(task_text.strip());
            tasks = tasks + [task];
            task_text = "";
        }
    }
```

**Rendering Lists and Conditionals**

**`{[... for t in tasks]}`** renders a list of elements. Each item needs a unique `key` prop:

<!-- jac-skip -->
```jac
{[
    <div key={jid(t)} class="task-item">
        <span>{t.title}</span>
    </div> for t in tasks
]}
```

**Conditional rendering** uses Jac's ternary expression inside JSX:

<!-- jac-skip -->
```jac
<span class={"task-title " + ("task-done" if t.done else "")}>
    {t.title}
</span>
```

**Building the Frontend Step by Step**

Now that you understand the individual pieces -- reactive state, lifecycle hooks, lambdas, transparent server calls, and JSX rendering -- it's time to assemble them into a working component. Add `import "./styles.css";` after your existing import. Start with the input, add button, and a basic task list:

```jac
def:pub app -> JsxElement {
    has tasks: list = [],
        task_text: str = "";

    async can with entry {
        tasks = await get_tasks();
    }

    async def add_new_task {
        if task_text.strip() {
            task = await add_task(task_text.strip());
            tasks = tasks + [task];
            task_text = "";
        }
    }

    return
        <div class="container">
            <h1>Day Planner</h1>
            <div class="input-row">
                <input
                    class="input"
                    value={task_text}
                    onChange={lambda (e: ChangeEvent) { task_text = e.target.value; }}
                    onKeyPress={lambda (e: KeyboardEvent) {
                        if e.key == "Enter" { add_new_task(); }
                    }}
                    placeholder="What needs to be done today?"
                />
                <button class="btn-add" onClick={add_new_task}>Add</button>
            </div>
            {[
                <div key={jid(t)} class="task-item">
                    <span class="task-title">{t.title}</span>
                </div> for t in tasks
            ]}
        </div>;
}
```

This is already functional -- you can type a task, press Enter, and see it appear. Take a moment to appreciate how the concepts you've learned work together: reactive `has` state re-renders the UI automatically when data changes, the lifecycle hook loads existing data on mount, and `await add_task()` transparently calls the server without any HTTP code.

**Adding Toggle and Delete**

Now add checkboxes, delete buttons, and a task counter. Insert these methods after `add_new_task`, and update the task list rendering:

```jac
def:pub app -> JsxElement {
    has tasks: list = [],
        task_text: str = "";

    async can with entry {
        tasks = await get_tasks();
    }

    async def add_new_task {
        if task_text.strip() {
            task = await add_task(task_text.strip());
            tasks = tasks + [task];
            task_text = "";
        }
    }

    async def toggle(id: str) {
        updated = await toggle_task(id);
        tasks = [updated if jid(t) == id else t for t in tasks];
    }

    async def remove(id: str) {
        await delete_task(id);
        tasks = [t for t in tasks if jid(t) != id];
    }

    remaining = len([t for t in tasks if not t.done]);

    return
        <div class="container">
            <h1>Day Planner</h1>
            <div class="input-row">
                <input
                    class="input"
                    value={task_text}
                    onChange={lambda (e: ChangeEvent) { task_text = e.target.value; }}
                    onKeyPress={lambda (e: KeyboardEvent) {
                        if e.key == "Enter" { add_new_task(); }
                    }}
                    placeholder="What needs to be done today?"
                />
                <button class="btn-add" onClick={add_new_task}>Add</button>
            </div>
            {[
                <div key={jid(t)} class="task-item">
                    <input
                        type="checkbox"
                        checked={t.done}
                        onChange={lambda { toggle(jid(t)); }}
                    />
                    <span class={"task-title " + ("task-done" if t.done else "")}>
                        {t.title}
                    </span>
                    <button
                        class="btn-delete"
                        onClick={lambda { remove(jid(t)); }}
                    >
                        X
                    </button>
                </div> for t in tasks
            ]}
            <div class="count">{remaining} {("task" if remaining == 1 else "tasks")} remaining</div>
        </div>;
}
```

There are several important patterns to understand in this code:

- **List comprehensions** transform and filter lists inline (e.g., `[expr for t in tasks]`, `[t for t in tasks if cond]`). These are the same Python-style comprehensions you may already know, and they're essential for working with reactive state.
- **Replacing items** in a list uses `[updated if jid(t) == id else t for t in tasks]`. Since `toggle_task` returns the updated `Task` object directly, you can swap it in place, which is exactly what immutable state updates require.
- **`tasks + [task]`** creates a new list with the item appended, rather than mutating the existing list. This immutability is important because the reactive system needs to detect that the list has changed.
- **`async`** marks methods that call the server, since network calls are inherently asynchronous.

**Add Styles**

Now fill in `styles.css` in your project root:

```css
.container { max-width: 500px; margin: 40px auto; font-family: system-ui; padding: 20px; }
h1 { text-align: center; margin-bottom: 24px; color: #333; }
.input-row { display: flex; gap: 8px; margin-bottom: 20px; }
.input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 1rem; }
.btn-add { padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }
.task-item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; gap: 10px; }
.task-title { flex: 1; }
.task-done { text-decoration: line-through; color: #888; }
.btn-delete { background: #e53e3e; color: white; border: none; border-radius: 4px; padding: 5px 10px; cursor: pointer; }
.count { text-align: center; color: #888; margin-top: 16px; font-size: 0.9rem; }
```

**Run It**

??? note "Complete `main.jac` for Parts 1–4"

    ```jac
    import "./styles.css";

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

    def:pub app -> JsxElement {
        has tasks: list[Task] = [],
            task_text: str = "";

        async can with entry {
            tasks = await get_tasks();
        }

        async def add_new_task {
            if task_text.strip() {
                task = await add_task(task_text.strip());
                tasks = tasks + [task];
                task_text = "";
            }
        }

        async def toggle(id: str) {
            updated = await toggle_task(id);
            if updated is None { return; }
            tasks = [updated if jid(t) == id else t for t in tasks];
        }

        async def remove(id: str) {
            await delete_task(id);
            tasks = [t for t in tasks if jid(t) != id];
        }

        remaining = len([t for t in tasks if not t.done]);

        return
            <div class="container">
                <h1>Day Planner</h1>
                <div class="input-row">
                    <input
                        class="input"
                        value={task_text}
                        onChange={lambda (e: ChangeEvent) { task_text = e.target.value; }}
                        onKeyPress={lambda (e: KeyboardEvent) {
                            if e.key == "Enter" { add_new_task(); }
                        }}
                        placeholder="What needs to be done today?"
                    />
                    <button class="btn-add" onClick={add_new_task}>Add</button>
                </div>
                {[
                    <div key={jid(t)} class="task-item">
                        <input
                            type="checkbox"
                            checked={t.done}
                            onChange={lambda { toggle(jid(t)); }}
                        />
                        <span class={"task-title " + ("task-done" if t.done else "")}>
                            {t.title}
                        </span>
                        <button
                            class="btn-delete"
                            onClick={lambda { remove(jid(t)); }}
                        >
                            X
                        </button>
                    </div> for t in tasks
                ]}
                <div class="count">{remaining} {("task" if remaining == 1 else "tasks")} remaining</div>
            </div>;
    }
    ```

```bash
jac run main.jac    # builds and serves
```

Open [http://localhost:8000](http://localhost:8000). You should see a clean day planner with an input field and an "Add" button. Try it:

1. Type "Buy groceries" and press Enter -- the task appears
2. Click the checkbox -- it gets crossed out
3. Click X -- it disappears
4. Stop the server and restart it -- your tasks are still there

That last point deserves emphasis. You didn't write any code to save data or load it on startup -- the data persisted automatically because the task nodes are connected to `root` in the graph. This is the persistence model you learned in Part 2 working seamlessly with the full-stack architecture.

!!! tip "Visualize the graph"
    Visit [http://localhost:8000/graph](http://localhost:8000/graph) to see your tasks as nodes connected to `root`. This visual view updates live as you add, toggle, and delete tasks.

**What You Learned**

- **Client placement is inferred** -- JSX, npm imports, and asset imports mark code for the browser; no annotation needed
- **`import "./styles.css";`** -- load CSS (or npm packages) in the browser; the string-path import is itself a client signal
- **`def:pub app -> JsxElement`** -- the main UI component (JSX places it client)
- **`has`** (in components) -- reactive state that triggers re-renders on change
- **`lambda`** -- anonymous functions: `lambda (params) -> type { body }`
- **`can with entry`** -- lifecycle hook that runs on component mount
- **`await func()`** -- transparent server calls from the client (no HTTP code)
- **`async`** -- marks functions that perform asynchronous operations
- **JSX syntax** -- `{expression}`, `{[... for x in list]}`, event handlers with lambdas
- **List comprehensions and `+` operator** -- `[expr for x in list]`, `[x for x in list if cond]`, and `list + [item]` for immutable state updates

> **Deep Dive:** [jac-client Reference](../../reference/plugins/jac-client.md) covers the full frontend API including routing, npm package imports, and advanced component patterns. The [Full-Stack tutorials](../fullstack/setup.md) go deeper on each topic.

!!! example "Try It Yourself"
    Add a "Clear All" button below the task count that deletes every task. You'll need a new `def:pub clear_all_tasks` endpoint on the server and an `async` method in the component that calls it and resets the `tasks` list.

---

## Checkpoint

Use the complete `main.jac` and stylesheet above as the recovery checkpoint. Run the app, add a task, toggle it, and delete it. Reload and verify the expected stored state; inspect the server log if the UI and response disagree.

[Lesson overview](build-ai-day-planner.md) · [Previous lesson](day-planner-03-backend.md) · [Next lesson](day-planner-05-ai.md)
