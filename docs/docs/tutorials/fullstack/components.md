# React-Style Components

Build reusable UI components with JSX syntax.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md)
> - Time: ~30 minutes

---

## Basic Component

```jac
cl {
    def:pub Greeting(props: dict) -> JsxElement {
        return <h1>Hello, {props.name}!</h1>;
    }

    def:pub app() -> JsxElement {
        return <div>
            <Greeting name="Alice" />
            <Greeting name="Bob" />
        </div>;
    }
}
```

**Key points:**

- Components are functions returning JSX
- `def:pub` exports the component
- `props` contains passed attributes
- Self-closing tags: `<Component />`

---

## JSX Syntax

### HTML Elements

```jac
cl {
    def:pub MyComponent() -> JsxElement {
        return <div className="container">
            <h1>Title</h1>
            <p>Paragraph text</p>
            <a href="/about">Link</a>
            <img src="/logo.png" alt="Logo" />
        </div>;
    }
}
```

**Note:** Use `className` not `class` (like React).

### JavaScript Expressions

```jac
cl {
    def:pub MyComponent() -> JsxElement {
        name = "World";
        items = [1, 2, 3];

        return <div>
            <p>Hello, {name}!</p>
            <p>Sum: {1 + 2 + 3}</p>
            <p>Items: {len(items)}</p>
        </div>;
    }
}
```

Use `{ }` to embed any Jac expression.

---

## Conditional Rendering

### Ternary Operator

```jac
cl {
    def:pub Status(props: dict) -> JsxElement {
        return <span>
            {("Active" if props.active else "Inactive")}
        </span>;
    }
}
```

### Logical AND

```jac
cl {
    def:pub Notification(props: dict) -> JsxElement {
        return <div>
            {props.count > 0 and <span>You have {props.count} messages</span>}
        </div>;
    }
}
```

### If Statement

```jac
cl {
    def:pub UserGreeting(props: dict) -> JsxElement {
        if props.isLoggedIn {
            return <h1>Welcome back!</h1>;
        }
        return <h1>Please sign in</h1>;
    }
}
```

---

## Lists and Iteration

```jac
cl {
    def:pub TodoList(props: dict) -> JsxElement {
        return <ul>
            {props.items.map(lambda item: any -> any {
                return <li key={item.id}>{item.text}</li>;
            })}
        </ul>;
    }

    def:pub app() -> JsxElement {
        todos = [
            {"id": 1, "text": "Learn Jac"},
            {"id": 2, "text": "Build app"},
            {"id": 3, "text": "Deploy"}
        ];

        return <TodoList items={todos} />;
    }
}
```

**Important:** Always provide a `key` prop for list items.

---

## Event Handling

### Click Events

```jac
cl {
    def:pub Button() -> JsxElement {
        def handle_click() -> None {
            print("Button clicked!");
        }

        return <button onClick={lambda -> None { handle_click(); }}>
            Click me
        </button>;
    }
}
```

### Input Events

```jac
cl {
    def:pub SearchBox() -> JsxElement {
        has query: str = "";

        return <input
            type="text"
            value={query}
            onChange={lambda e: any -> None { query = e.target.value; }}
            placeholder="Search..."
        />;
    }
}
```

### Form Submit

```jac
cl {
    def:pub LoginForm() -> JsxElement {
        has username: str = "";
        has password: str = "";

        def handle_submit(e: any) -> None {
            e.preventDefault();
            print(f"Login: {username}");
        }

        return <form onSubmit={lambda e: any -> None { handle_submit(e); }}>
            <input
                value={username}
                onChange={lambda e: any -> None { username = e.target.value; }}
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { password = e.target.value; }}
            />
            <button type="submit">Login</button>
        </form>;
    }
}
```

---

## Component Composition

### Children

```jac
cl {
    def:pub Card(props: dict) -> JsxElement {
        return <div className="card">
            <div className="card-header">{props.title}</div>
            <div className="card-body">{props.children}</div>
        </div>;
    }

    def:pub app() -> JsxElement {
        return <Card title="Welcome">
            <p>This is the card content.</p>
            <button>Action</button>
        </Card>;
    }
}
```

### Nested Components

```jac
cl {
    def:pub Header() -> JsxElement {
        return <header>
            <h1>My App</h1>
            <Nav />
        </header>;
    }

    def:pub Nav() -> JsxElement {
        return <nav>
            <a href="/">Home</a>
            <a href="/about">About</a>
        </nav>;
    }

    def:pub Footer() -> JsxElement {
        return <footer>© 2024</footer>;
    }

    def:pub app() -> JsxElement {
        return <div>
            <Header />
            <main>Content here</main>
            <Footer />
        </div>;
    }
}
```

---

## Separate Component Files

### Header.cl.jac

```jac
# No cl { } needed for .cl.jac files

def:pub Header(props: dict) -> JsxElement {
    return <header>
        <h1>{props.title}</h1>
    </header>;
}
```

### main.jac

```jac
cl {
    import from "./Header.cl.jac" { Header }

    def:pub app() -> JsxElement {
        return <div>
            <Header title="My App" />
            <main>Content</main>
        </div>;
    }
}
```

---

## TypeScript Components

You can use TypeScript components:

### Button.tsx

```typescript
interface ButtonProps {
  label: string;
  onClick: () => void;
}

export function Button({ label, onClick }: ButtonProps) {
  return <button onClick={onClick}>{label}</button>;
}
```

### main.jac

```jac
cl {
    import from "./Button.tsx" { Button }

    def:pub app() -> JsxElement {
        return <Button
            label="Click me"
            onClick={lambda -> None { print("Clicked!"); }}
        />;
    }
}
```

---

## Styling Components

### Inline Styles

```jac
cl {
    def:pub StyledBox() -> JsxElement {
        return <div style={{
            "backgroundColor": "#f0f0f0",
            "padding": "20px",
            "borderRadius": "8px",
            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
        }}>
            Styled content
        </div>;
    }
}
```

### CSS Classes

```jac
cl {
    import ".styles.css";

    def:pub app() -> JsxElement {
        return <div className="container">
            <h1 className="title">Hello</h1>
        </div>;
    }
}
```

```css
/* .styles.css */
.container {
    max-width: 800px;
    margin: 0 auto;
}
.title {
    color: #333;
}
```

---

## Key Takeaways

| Concept | Syntax |
|---------|--------|
| Define component | `def:pub Name(props: dict) -> JsxElement { }` |
| JSX element | `<div className="x">content</div>` |
| Expression | `{expression}` |
| Event handler | `onClick={lambda -> None { ... }}` |
| List rendering | `{items.map(lambda x -> any { <li>{x}</li> })}` |
| Conditional | `{condition ? <A /> : <B />}` |
| Children | `{props.children}` |
| Import component | `import from "./File.cl.jac" { Component }` |

---

## Next Steps

- [State Management](state.md) - Reactive state with `has`
- [Backend Integration](backend.md) - Connect to walkers
