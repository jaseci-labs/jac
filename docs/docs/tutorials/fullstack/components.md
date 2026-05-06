# React-Style Components

Jac's client-side code uses JSX syntax (the same HTML-in-code approach popularized by React) to build UI components. Components are functions declared inside `cl { }` blocks that return `JsxElement` values. Each prop is a named parameter -- the type-checker validates every JSX call site per attribute -- and components compose just like in React, with conditional rendering, list mapping, and event handling.

The key difference from a standard React setup: there's no separate JavaScript project, no webpack configuration, and no build toolchain to manage. You write components in Jac syntax, the compiler generates optimized JavaScript, and the dev server bundles and serves it automatically.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md)
> - Time: ~30 minutes

---

## Basic Component

```jac
to cl:

def:pub Greeting(name: str) -> JsxElement {
    return <h1>Hello, {name}!</h1>;
}

def:pub app() -> JsxElement {
    return <div>
        <Greeting name="Alice" />
        <Greeting name="Bob" />
    </div>;
}
```

**Key points:**

- Components are functions returning JSX
- `def:pub` exports the component
- Each prop is a named parameter -- `<Greeting name="Alice" />` is type-checked against the `name: str` declaration
- Self-closing tags: `<Component />`

---

## Forwarding the props bundle (advanced)

`props` is a Jac keyword that names the call-site argument object as a whole, the same way `self` names the receiver. A component declared with a single parameter literally named `props` receives the object verbatim instead of having each prop destructured into its own local:

```jac
to cl:

# jac:ignore[W5015]
def:pub PassThrough(props: dict) -> JsxElement {
    return <Inner {**props} />;
}
```

This shape is useful for higher-order components, wrappers, and forwarding helpers, but it has a real cost: the type-checker keys per-prop validation on parameter *names*, so a `props`-bundle signature cannot validate `<PassThrough title="..." />` per attribute. The compiler emits **W5015** on every single-`props` definition for that reason -- suppress it inline (`# jac:ignore[W5015]`) only when the forwarding behavior is intentional.

**Default to direct named parameters.** Reach for `props: dict` only when you genuinely need the unstructured bundle.

---

## JSX Syntax

### HTML Elements

```jac
to cl:

def:pub MyComponent() -> JsxElement {
    return <div className="container">
        <h1>Title</h1>
        <p>Paragraph text</p>
        <a href="/about">Link</a>
        <img src="/logo.png" alt="Logo" />
    </div>;
}
```

**Note:** Use `className` not `class` (like React).

### JavaScript Expressions

```jac
to cl:

def:pub MyComponent() -> JsxElement {
    name = "World";
    items = [1, 2, 3];

    return <div>
        <p>Hello, {name}!</p>
        <p>Sum: {1 + 2 + 3}</p>
        <p>Items: {len(items)}</p>
    </div>;
}
```

Use `{ }` to embed any Jac expression.

---

## Conditional Rendering

### Ternary Operator

```jac
to cl:

def:pub Status(active: bool) -> JsxElement {
    return <span>
        {("Active" if active else "Inactive")}
    </span>;
}
```

### Logical AND

```jac
to cl:

def:pub Notification(count: int) -> JsxElement {
    return <div>
        {count > 0 and <span>You have {count} messages</span>}
    </div>;
}
```

### If Statement

```jac
to cl:

def:pub UserGreeting(isLoggedIn: bool) -> JsxElement {
    if isLoggedIn {
        return <h1>Welcome back!</h1>;
    }
    return <h1>Please sign in</h1>;
}
```

---

## Lists and Iteration

```jac
to cl:

def:pub TodoList(items: list[dict]) -> JsxElement {
    return <ul>
        {[<li key={item.id}>{item.text}</li> for item in items]}
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
```

**Important:** Always provide a `key` prop for list items.

---

## Event Handling

### Click Events

```jac
to cl:

def:pub Button() -> JsxElement {
    def handle_click() -> None {
        print("Button clicked!");
    }

    return <button onClick={lambda -> None { handle_click(); }}>
        Click me
    </button>;
}
```

### Input Events

```jac
to cl:

def:pub SearchBox() -> JsxElement {
    has query: str = "";

    return <input
        type="text"
        value={query}
        onChange={lambda e: ChangeEvent { query = e.target.value; }}
        placeholder="Search..."
    />;
}
```

### Form Submit

```jac
to cl:

def:pub LoginForm() -> JsxElement {
    has username: str = "";
    has password: str = "";

    def handle_submit(e: FormEvent) -> None {
        e.preventDefault();
        print(f"Login: {username}");
    }

    return <form onSubmit={lambda e: FormEvent { handle_submit(e); }}>
        <input
            value={username}
            onChange={lambda e: ChangeEvent { username = e.target.value; }}
        />
        <input
            type="password"
            value={password}
            onChange={lambda e: ChangeEvent { password = e.target.value; }}
        />
        <button type="submit">Login</button>
    </form>;
}
```

---

## Component Composition

### Children

```jac
to cl:

def:pub Card(title: str, children: Any) -> JsxElement {
    return <div className="card">
        <div className="card-header">{title}</div>
        <div className="card-body">{children}</div>
    </div>;
}

def:pub app() -> JsxElement {
    return <Card title="Welcome">
        <p>This is the card content.</p>
        <button>Action</button>
    </Card>;
}
```

### Nested Components

```jac
to cl:

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
```

---

## Separate Component Files

### Header.cl.jac

```jac
# No cl { } needed for .cl.jac files

def:pub Header(title: str) -> JsxElement {
    return <header>
        <h1>{title}</h1>
    </header>;
}
```

### main.jac

```jac
to cl:

import from "./Header.cl.jac" { Header }

def:pub app() -> JsxElement {
    return <div>
        <Header title="My App" />
        <main>Content</main>
    </div>;
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
to cl:

import from "./Button.tsx" { Button }

def:pub app() -> JsxElement {
    return <Button
        label="Click me"
        onClick={lambda -> None { print("Clicked!"); }}
    />;
}
```

---

## Styling Components

### Inline Styles

```jac
to cl:

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
```

### CSS Classes

```jac
to cl:

import "./styles.css";

def:pub app() -> JsxElement {
    return <div className="container">
        <h1 className="title">Hello</h1>
    </div>;
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
| Define component | `def:pub Name(title: str, count: int) -> JsxElement { }` |
| JSX element | `<div className="x">content</div>` |
| Expression | `{expression}` |
| Click handler | `onClick={lambda -> None { ... }}` |
| Input handler | `onChange={lambda e: ChangeEvent { ... }}` |
| List rendering | `{[<li>{x}</li> for x in items]}` |
| Conditional | `{("A" if condition else "B")}` |
| Children | `def:pub Card(children: Any) { ... }` then `{children}` |
| Forwarding bundle | `def:pub Wrap(props: dict)` (suppress W5015) |
| Import component | `import from "./File.cl.jac" { Component }` |

---

## Next Steps

- [State Management](state.md) - Reactive state with `has`
- [Backend Integration](backend.md) - Connect to walkers
