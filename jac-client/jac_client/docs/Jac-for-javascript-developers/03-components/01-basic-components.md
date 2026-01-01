# Basic Components

Learn how to create and use components in JAC-Client.

---

## Component Basics

### JavaScript/React vs JAC-Client

**JavaScript/React:**

```jsx
function Greeting() {
  return <h1>Hello, World!</h1>;
}

export default function App() {
  return <Greeting />;
}
```

**JAC-Client:**

```jac
cl {
    def Greeting() -> any {
        return <h1>Hello, World!</h1>;
    }

    def app() -> any {
        return <Greeting />;
    }
}
```

### Key Differences

1. Use `def ComponentName() -> any { }` instead of `function`
2. Components return `any` type
3. `def app()` is the required entry point
4. All components go inside `cl { }` block

---

## The `app()` Entry Point

Every JAC-Client project must have an `app()` function:

```jac
cl {
    def app() -> any {
        return <div>
            <h1>My App</h1>
            <p>Welcome!</p>
        </div>;
    }
}
```

**Requirements:**

- Function must be named `app` (lowercase)
- Must be inside `cl { }` block
- Must return JSX

---

## Creating Components

### Simple Component

```jac
cl {
    def Header() -> any {
        return (
            <header>
                <h1>My Website</h1>
                <nav>
                    <a href="/">Home</a>
                    <a href="/about">About</a>
                </nav>
            </header>
        );
    }

    def app() -> any {
        return (
            <div>
                <Header />
                <main>Content here</main>
            </div>
        );
    }
}
```

### Component with State

```jac
cl import from react { useState }

cl {
    def Counter() -> any {
        [count, setCount] = useState(0);

        return (
            <div>
                <p>Count: {count}</p>
                <button onClick={lambda: setCount(count + 1)}>
                    Increment
                </button>
            </div>
        );
    }

    def app() -> any {
        return <Counter />;
    }
}
```

---

## Component Naming

- Use **PascalCase** for component names: `UserProfile`, `TodoList`, `NavBar`
- Component names must start with uppercase (same as React)

```jac
# Good
def UserCard() -> any { }
def TodoList() -> any { }
def NavBar() -> any { }

# Bad - won't work as components
def userCard() -> any { }
def todo_list() -> any { }
```

---

## Multiple Components

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
                    "borderRadius": "5px"
                }}
            >
                {label}
            </button>
        );
    }

    def Counter() -> any {
        [count, setCount] = useState(0);

        return (
            <div>
                <h2>Count: {count}</h2>
                <Button
                    label="+"
                    color="#28a745"
                    onClick={lambda: setCount(count + 1)}
                />
                <Button
                    label="-"
                    color="#dc3545"
                    onClick={lambda: setCount(count - 1)}
                />
            </div>
        );
    }

    def app() -> any {
        return (
            <div style={{ "padding": "20px" }}>
                <h1>My App</h1>
                <Counter />
            </div>
        );
    }
}
```

---

## Returning JSX

### Single Element

```jac
def Simple() -> any {
    return <h1>Hello</h1>;
}
```

### Multiple Elements (Use Parentheses)

```jac
def Complex() -> any {
    return (
        <div>
            <h1>Title</h1>
            <p>Description</p>
        </div>
    );
}
```

### Fragments

```jac
# Return multiple elements without a wrapper
def Fragment() -> any {
    return (
        <>
            <h1>Title</h1>
            <p>Description</p>
        </>
    );
}
```

### Return Nothing

```jac
def MaybeShow(visible: bool) -> any {
    if not visible {
        return <></>;  # Return empty fragment
    }

    return <div>Content</div>;
}
```

---

## Component Organization

### Same File

```jac
cl {
    # Helper components first
    def Header() -> any { ... }
    def Footer() -> any { ... }
    def Sidebar() -> any { ... }

    # Main component last
    def app() -> any {
        return (
            <div>
                <Header />
                <Sidebar />
                <Footer />
            </div>
        );
    }
}
```

### Separate Files

**components/Header.jac:**

```jac
cl {
    def:pub Header() -> any {
        return <header>Header</header>;
    }
}
```

**app.jac:**

```jac
cl import from .components.Header { Header }

cl {
    def app() -> any {
        return (
            <div>
                <Header />
                <main>Content</main>
            </div>
        );
    }
}
```

---

## Exporting Components

Use `:pub` to export components:

```jac
# components/Button.jac

cl {
    # Exported - can be imported
    def:pub Button(label: str) -> any {
        return <button>{label}</button>;
    }

    # Private - only used in this file
    def ButtonIcon(icon: str) -> any {
        return <span>{icon}</span>;
    }
}
```

---

## Summary

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Define component | `function Comp() {}` | `def Comp() -> any {}` |
| Entry point | `App()` | `app()` |
| Wrap code | N/A | `cl { }` |
| Export | `export function` | `def:pub` |
| Fragment | `<></>` | `<></>` |
| Return null | `return null` | `return <></>` |

---

## Next

- [Props](02-props.md) - Passing data to components
