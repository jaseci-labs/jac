# Quick Start Guide

Build your first JAC-Client component in minutes.

---

## Project Setup

### 1. Create Project Structure

```
my-jac-app/
├── jac.toml
├── src/
│   └── app.jac
└── package.json
```

### 2. Configure `jac.toml`

```toml
[project]
entry-point = "src/app.jac"
```

### 3. Create `src/app.jac`

```jac
cl {
    def:pub app() -> any {
        return <div>
            <h1>Hello, JAC!</h1>
        </div>;
    }
}
```

### 4. Run Your App

```bash
jac serve src/app.jac
```

Visit `http://localhost:8000/page/app`

---

## Your First Interactive Component

Let's build a counter with state:

```jac
cl import from react { useState }

cl {
    def Counter() -> any {
        [count, setCount] = useState(0);

        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <h2>Counter: {count}</h2>
                <button
                    onClick={lambda: setCount(count + 1)}
                    style={{ "padding": "10px 20px", "fontSize": "16px" }}
                >
                    Increment
                </button>
            </div>
        );
    }

    def:pub app() -> any {
        return <Counter />;
    }
}
```

**What's happening:**

1. `cl import from react { useState }` - Import the useState hook
2. `[count, setCount] = useState(0)` - Create state (no `const` needed)
3. `lambda: setCount(count + 1)` - Arrow function to update state
4. `def:pub app()` - Required entry point that renders our Counter

---

## Adding Multiple Components

```jac
cl import from react { useState }

cl {
    def Button(label: str, color: str, onClick: any) -> any {
        return (
            <button
                onClick={onClick}
                style={{
                    "padding": "10px 20px",
                    "backgroundColor": color,
                    "color": "white",
                    "border": "none",
                    "borderRadius": "5px",
                    "cursor": "pointer",
                    "marginRight": "10px"
                }}
            >
                {label}
            </button>
        );
    }

    def Counter() -> any {
        [count, setCount] = useState(0);

        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <h2>Count: {count}</h2>
                <Button
                    label="Increment"
                    color="#28a745"
                    onClick={lambda: setCount(count + 1)}
                />
                <Button
                    label="Decrement"
                    color="#dc3545"
                    onClick={lambda: setCount(count - 1)}
                />
                <Button
                    label="Reset"
                    color="#007bff"
                    onClick={lambda: setCount(0)}
                />
            </div>
        );
    }

    def:pub app() -> any {
        return <Counter />;
    }
}
```

**Key patterns:**

- Props are defined as direct function parameters: `def Button(label: str, color: str, onClick: any)`
- Access props directly by parameter name: `label`, `color`, `onClick`
- **Note:** You can also access via `props.label`, `props.color`, etc. - both approaches work!
- Components are defined with `def ComponentName() -> any`

---

## Adding Effects

```jac
cl import from react { useState, useEffect }

cl {
    def Timer() -> any {
        [seconds, setSeconds] = useState(0);
        [isRunning, setIsRunning] = useState(False);

        useEffect(lambda -> None {
            if isRunning {
                timer = setInterval(lambda -> None {
                    setSeconds(seconds + 1);
                }, 1000);
                return lambda -> None { clearInterval(timer); };
            }
        }, [isRunning, seconds]);

        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <h2>Timer: {seconds}s</h2>
                <button onClick={lambda: setIsRunning(not isRunning)}>
                    {("Stop") if isRunning else ("Start")}
                </button>
                <button onClick={lambda -> None { setSeconds(0); setIsRunning(False); }}>
                    Reset
                </button>
            </div>
        );
    }

    def:pub app() -> any {
        return <Timer />;
    }
}
```

**Note the differences:**

- `useEffect(lambda -> None { ... }, [deps])` - Effects use lambda syntax
- `(a) if condition else (b)` - Python-style ternary
- `not isRunning` - Use `not` instead of `!`

---

## Handling User Input

```jac
cl import from react { useState }

cl {
    def Greeting() -> any {
        [name, setName] = useState("");

        return (
            <div style={{ "textAlign": "center", "padding": "20px" }}>
                <h2>
                    {("Hello, " + name + "!") if name else ("Enter your name")}
                </h2>
                <input
                    type="text"
                    value={name}
                    onChange={lambda e: any -> None { setName(e.target.value); }}
                    placeholder="Your name..."
                    style={{ "padding": "10px", "fontSize": "16px" }}
                />
            </div>
        );
    }

    def:pub app() -> any {
        return <Greeting />;
    }
}
```

---

## Working with Lists

```jac
cl import from react { useState }

cl {
    def TodoList() -> any {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");

        def addTodo() -> None {
            if input.trim() != "" {
                setTodos(todos.concat([{ "id": Date.now(), "text": input }]));
                setInput("");
            }
        }

        def renderTodo(todo: dict, index: int) -> any {
            return (
                <li key={todo["id"]} style={{ "padding": "5px" }}>
                    {todo["text"]}
                </li>
            );
        }

        return (
            <div style={{ "padding": "20px" }}>
                <h2>Todo List</h2>
                <input
                    value={input}
                    onChange={lambda e: any -> None { setInput(e.target.value); }}
                    placeholder="Add todo..."
                    style={{ "padding": "10px", "marginRight": "10px" }}
                />
                <button onClick={lambda: addTodo()}>Add</button>
                <ul>{todos.map(renderTodo)}</ul>
            </div>
        );
    }

    def:pub app() -> any {
        return <TodoList />;
    }
}
```

**Key patterns:**

- `todos.concat([newItem])` - Add to array (no spread operator)
- Define helper function `renderTodo` for mapping
- `key={todo["id"]}` - Keys work the same as React

---

## Next Steps

Now that you've built your first components:

1. **[Syntax Cheatsheet](03-syntax-cheatsheet.md)** - Quick reference for all syntax
2. **[Core Syntax](../02-core-syntax/)** - Deep dive into syntax differences
3. **[Components](../03-components/)** - Learn component patterns

---

## Common Beginner Mistakes

| Mistake | Fix |
|---------|-----|
| Using `const` or `let` | Just assign: `x = 5` |
| Using `=>` for functions | Use `lambda: expr` or `lambda -> Type {}` |
| Using `? :` for ternary | Use `(a) if condition else (b)` |
| Using `true`/`false` | Use `True`/`False` |
| Using `null` | Use `None` |
| Using `&&` | Use `and` |
| Using `!` | Use `not` |
| Using unquoted object keys | Quote all keys: `{ "key": value }` |
