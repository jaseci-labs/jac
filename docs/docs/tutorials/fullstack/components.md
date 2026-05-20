# React-Style Components

Jac's client-side code uses JSX syntax (the same HTML-in-code approach popularized by React) to build UI components. Components are functions declared in client-side code -- a `.cl.jac` file or a `to cl:` section -- that return `JsxElement` values. Each prop is a named parameter -- the type-checker validates every JSX call site per attribute -- and components compose just like in React, with conditional rendering, list mapping, and event handling.

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

## Typed props and `children`

Declare **every prop as its own named, typed parameter**. The type-checker keys per-attribute validation on parameter names, so each `<Card title="..." />` call site is checked against the declared types -- unknown props, type mismatches, and missing required props are all caught at `jac check` time.

`children` -- the JSX nested between a component's tags -- is just a regular parameter named `children`. It is not special-cased: React's reconciler fills it in and the compiler destructures it like any other prop. (The only genuinely reserved attribute names are `key` and `ref`.)

```jac
to cl:

def:pub Card(title: str, description: str = "", children: any = None) -> JsxElement {
    return <div className="card">
        <h2>{title}</h2>
        <p>{description}</p>
        {children}
    </div>;
}

def:pub app() -> JsxElement {
    return <Card title="Welcome" description="Hello!">
        <p>This is the card content.</p>
    </Card>;
}
```

!!! warning "`children` must have a default value"
    The prop validator counts only JSX **attributes** toward matched parameters -- nested content does *not* count. A `children` parameter with no default is therefore treated as a *required* prop, and any call site that passes another attribute fails with `error[E1102]: Component 'Card' requires prop 'children'`. Always declare it as `children: any = None`.

There is no `ReactNode`-style union type in Jac, and a children value can be an element, a string, a number, or a list of those -- so `any` is the honest type for a `children` parameter. The parameter type governs only how you use `children` inside the body; it is never checked against the nested content.

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

def:pub TodoList(items: list[dict[str, any]]) -> JsxElement {
    return <ul>
        {[<li key={item["id"]}>{item["text"]}</li> for item in items]}
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

def:pub Card(title: str, children: any = None) -> JsxElement {
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

## Views: Statement-Form Components

A **view** is a component written as a sequence of statements instead of a single `return` expression. `defview Name(params) { ... }` is sugar for `def:pub Name(params) -> JsxElement { ... }` -- same call site, same per-prop type-checking, same compile pipeline. The difference is the body: each top-level JSX element is a *statement* that contributes to the rendered output, so there is no `return <jsx>;` wrapper.

```jac
to cl:

defview Greeting(name: str) {
    <h1>Hello, {name}!</h1>
    <p>Welcome to Jac.</p>
}
```

This is equivalent to the `def`-form component:

```jac
to cl:

def:pub Greeting(name: str) -> JsxElement {
    return <>
        <h1>Hello, {name}!</h1>
        <p>Welcome to Jac.</p>
    </>;
}
```

**Key points:**

- `defview` is sugar for `def:pub ... -> JsxElement` -- a view is always public and always returns `JsxElement`.
- The parameter list is optional: a view with no props can be written `defview Demo { ... }` (no parentheses).
- Only the compound keyword `defview` is reserved -- the bare name `view` is still available for variables, fields, and parameters.
- Top-level JSX elements are collected into a fragment automatically -- no `return` needed.
- A view call site is identical to any other component: `<Greeting name="Alice" />`.
- `def:pub Name -> JsxElement` components keep working unchanged -- `defview` is an additive, opinionated form for new code.

### Control Flow as Content

Inside a view body, every block-bodied construct -- `if`/`elif`/`else`, `for` (both loop forms), `while`, `match`, `switch`, `with`, and `try` -- contributes the JSX in its branches directly to the output. No ternary, no inline comprehension:

```jac
to cl:

defview ItemList(items: list[str]) {
    if len(items) == 0 {
        <p className="empty">Nothing here.</p>
        return;
    }
    <h2>Items</h2>
    for (i, item) in enumerate(items) {
        <li key={i}>{item}</li>
    }
}
```

A bare `return;` (no value) ends the render with whatever was emitted so far -- a clean early-exit guard.

### has-Fields and Handlers

A view body can declare `has`-fields and nested `def` handlers exactly as a `def`-form component does. `has`-fields keep the existing auto-`useState` wiring -- assigning to one rewrites to the generated setter:

```jac
to cl:

defview Counter {
    has count: int = 0;

    def bump {
        count = count + 1;
    }

    <button onClick={bump}>Count: {count}</button>
}
```

### Dynamic Tags

`<@expr />` chooses its element tag from an expression instead of a fixed name. The expression can be an identifier, a dotted access, or a brace-wrapped expression `<@{expr}>`, and resolves to a host-tag string, another view, or a `str | type` value:

```jac
to cl:

defview Box(as_: str, children: any = None) {
    <@as_ className="box">{children}</@as_>
}

defview Demo() {
    <Box as_="article">Inside an article element</Box>
    <Box as_="section">Inside a section element</Box>
}
```

Use `as_`, not `as` -- `as` is reserved in Jac for import aliases.

---

## Separate Component Files

### Header.cl.jac

```jac
# No `to cl:` header needed for .cl.jac files

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
| Define a view | `defview Name(params) { <jsx> ... }` |
| Early-exit guard | bare `return;` inside a view body |
| Dynamic tag | `<@expr>...</@expr>` |
| JSX element | `<div className="x">content</div>` |
| Expression | `{expression}` |
| Click handler | `onClick={lambda -> None { ... }}` |
| Input handler | `onChange={lambda e: ChangeEvent { ... }}` |
| List rendering | `{[<li>{x}</li> for x in items]}` |
| Conditional | `{("A" if condition else "B")}` |
| Children | `def:pub Card(children: any = None) { ... }` then `{children}` |
| Forwarding bundle | `def:pub Wrap(props: dict)` (suppress W5015) |
| Import component | `import from "./File.cl.jac" { Component }` |

---

## Next Steps

- [State Management](state.md) - Reactive state with `has`
- [Backend Integration](backend.md) - Connect to walkers
