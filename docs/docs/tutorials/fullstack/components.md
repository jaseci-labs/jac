# React-Style Components

Jac's client-side code uses JSX syntax (the same HTML-in-code approach popularized by React) to build UI components. Components are functions declared in client-side code -- a `.cl.jac` file or a `cl { }` block -- that return `JsxElement` values. Each prop is a named parameter -- the type-checker validates every JSX call site per attribute -- and components compose just like in React, with conditional rendering, list mapping, and event handling.

The key difference from a standard React setup: there's no separate JavaScript project, no webpack configuration, and no build toolchain to manage. You write components in Jac syntax, the compiler generates optimized JavaScript, and the dev server bundles and serves it automatically.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md)
> - Time: ~30 minutes

---

## Basic Component

```jac
cl {
    def:pub Greeting(name: str) -> JsxElement {
        return <h1>Hello, {name}!</h1>;
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
- Each prop is a named parameter -- `<Greeting name="Alice" />` is type-checked against the `name: str` declaration
- Self-closing tags: `<Component />`

---

## Typed props and `children`

Declare **every prop as its own named, typed parameter**. The type-checker keys per-attribute validation on parameter names, so each `<Card title="..." />` call site is checked against the declared types -- unknown props, type mismatches, and missing required props are all caught at `jac check` time.

`children` -- the JSX nested between a component's tags -- is just a regular parameter named `children`. It is not special-cased: React's reconciler fills it in and the compiler destructures it like any other prop. (The only genuinely reserved attribute names are `key` and `ref`.)

```jac
cl {
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
}
```

!!! warning "`children` must have a default value"
    The prop validator counts only JSX **attributes** toward matched parameters -- nested content does *not* count. A `children` parameter with no default is therefore treated as a *required* prop, and any call site that passes another attribute fails with `error[E1102]: Component 'Card' requires prop 'children'`. Always declare it as `children: any = None`.

There is no `ReactNode`-style union type in Jac, and a children value can be an element, a string, a number, or a list of those -- so `any` is the accurate type for a `children` parameter. The parameter type governs only how you use `children` inside the body; it is never checked against the nested content.

**`{name}` attribute shorthand:** when a prop's value is a variable of the same name, `<Card {title} {onClose} />` is sugar for `<Card title={title} onClose={onClose} />`. Each shorthand attribute is still validated per-prop against the component signature. This is distinct from the `{**props}` spread (above), which forwards an entire object instead of a single named attribute.

---

## Forwarding the props bundle (advanced)

`props` is a Jac keyword that names the call-site argument object as a whole, the same way `self` names the receiver. A component declared with a single parameter literally named `props` receives the object verbatim instead of having each prop destructured into its own local:

```jac
cl {
    # jac:ignore[W5015]
    def:pub PassThrough(props: dict) -> JsxElement {
        return <Inner {**props} />;
    }
}
```

This shape is useful for higher-order components, wrappers, and forwarding helpers, but it has a real cost: the type-checker keys per-prop validation on parameter *names*, so a `props`-bundle signature cannot validate `<PassThrough title="..." />` per attribute. The compiler emits **W5015** on every single-`props` definition for that reason -- suppress it inline (`# jac:ignore[W5015]`) only when the forwarding behavior is intentional.

**Default to direct named parameters.** Reach for `props: dict` only when you genuinely need the unstructured bundle.

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
    def:pub Status(active: bool) -> JsxElement {
        return <span>
            {("Active" if active else "Inactive")}
        </span>;
    }
}
```

### Logical AND

```jac
cl {
    def:pub Notification(count: int) -> JsxElement {
        return <div>
            {count > 0 and <span>You have {count} messages</span>}
        </div>;
    }
}
```

### If Statement

```jac
cl {
    def:pub UserGreeting(isLoggedIn: bool) -> JsxElement {
        if isLoggedIn {
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
            onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
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

        def handle_submit(e: FormEvent) -> None {
            e.preventDefault();
            print(f"Login: {username}");
        }

        return <form onSubmit={lambda (e: FormEvent) { handle_submit(e); }}>
            <input
                value={username}
                onChange={lambda (e: ChangeEvent) { username = e.target.value; }}
            />
            <input
                type="password"
                value={password}
                onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
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

## JSX Slots: Control Flow as Children

A component is just `def:pub Name(...) -> JsxElement { return <jsx>; }`. The interesting work happens inside the JSX itself, where every `{...}` is a **slot** -- a place where Jac code computes a child. Slots come in two shapes:

- **Expression slot** (the usual case): `{name}`, `{user.profile.email}`, `{<Badge />}` -- whatever's inside renders directly.
- **Statement slot**: when a slot begins with a statement keyword (`if`, `for`, `while`, `match`, `switch`, `with`, `try`, `return`), it switches into template mode. Each JSX statement inside the slot is appended to the element's children; control flow yields the JSX in its branches.

The two forms share the same `{...}` syntax -- the compiler decides which shape applies from the body's first token.

```jac
cl {
    def:pub Greeting(name: str) -> JsxElement {
        return <div class="card">
            {if name == "" {
                <p>Hello, stranger</p>
            } else {
                <h1>Hello, {name}</h1>
                <p>Welcome back.</p>
            }}
        </div>;
    }
}
```

**Key points:**

- `{...}` slots replace inline comprehensions and nested ternaries -- the same `if`/`for`/`while`/etc. you write at function-body level works as a child.
- `skip;` inside a statement slot is the **guard** form: rendering stops, the children accumulated so far become the slot's value. Bare `return;` inside a slot is rejected (E2020) because it reads like a function-exit but only exits the slot.
- A statement slot with no JSX renders to an empty fragment. Mix as needed: `<header>` and `<footer>` sit beside a `{for ... { ... }}` slot in the same parent.
- The slot's bracketed shape is what disambiguates the keyword -- bare `for example` in JSX text remains plain text.

### `for` and `while` loops

`for it in items { <Row item={it} /> }` inside a slot lowers to a `JS` `for` loop that pushes each `<Row>` to the element's children -- not a comprehension over a `.map()`. Same shape for the C-style `for x = 0; x < n; x += 1 { ... }` form and for `while`.

```jac
cl {
    def:pub ItemList(items: list[str]) -> JsxElement {
        return <>
            {if len(items) == 0 {
                <p class="empty">Nothing here.</p>
                skip;
            }}
            <h2>Items</h2>
            {for (i, item) in enumerate(items) {
                <li key={i}>{item}</li>
            }}
        </>;
    }
}
```

Loop slots that emit keyless JSX get a warning -- `W2019` for a `while` loop and `W2021` for a `for` loop. Siblings produced by a loop need a stable `key=` (as in the `<li key={i}>` above) so a re-render keeps their identity.

### `has`-fields and Handlers

A `def:pub -> JsxElement` body can declare `has`-fields and nested `def` handlers exactly like a regular component. `has`-fields keep the auto-`useState` wiring -- assigning to one rewrites to the generated setter:

```jac
cl {
    def:pub Counter() -> JsxElement {
        has count: int = 0;

        def bump {
            count = count + 1;
        }

        return <button onClick={bump}>Count: {count}</button>;
    }
}
```

Declare `has`-fields at the component scope, never inside a `{...}` slot body. A slot body is a statement template that re-runs on every render, so a `has` there would compile to a conditional `useState` and violate React's rules of hooks -- the compiler rejects it with `E2024`.

Inside a handler body (an ordinary function, not a slot), `skip;` is a plain early `return` -- the same return-family semantics it has everywhere else. Use it for guard clauses:

```jac
def handle_submit {
    if len(value) == 0 {
        skip;   # early return -- lowers to `return;`, not `continue`
    }
    value = "submitted";
}
```

Don't confuse this with the slot-guard form above: in a slot, `skip;` yields the children accumulated so far; in a function body it simply exits the function.

### Dynamic Tags

`<@expr />` chooses its element tag from an expression instead of a fixed name. The expression can be an identifier, a dotted access, or a brace-wrapped expression `<@{expr}>`, and resolves to a host-tag string, another component, or a `str | type` value:

```jac
cl {
    def:pub Box(as_: str, children: any = None) -> JsxElement {
        return <@as_ className="box">{children}</@as_>;
    }

    def:pub Demo() -> JsxElement {
        return <>
            <Box as_="article">Inside an article element</Box>
            <Box as_="section">Inside a section element</Box>
        </>;
    }
}
```

Use `as_`, not `as` -- `as` is reserved in Jac for import aliases.

### `try` with `awaiting`: Suspense-shaped fallback

A `try` slot can take an `awaiting` clause that names what to render while the work inside is still in flight. The cl-target compiler wraps the slot in a `<JacAwaiting>` element from `@jac/runtime` -- a thin shim over `React.Suspense` -- so the `awaiting` body renders during the dispatched-but-not-joined window and the `try` body's content takes over once the underlying async work settles.

```jac
cl {
    def:pub UserCardSkeleton() -> JsxElement {
        return <div class="card skeleton"><p>Loading user…</p></div>;
    }

    def:pub UserCardView(user: User) -> JsxElement {
        return <div class="card"><h2>{user.name}</h2><p>{user.bio}</p></div>;
    }

    def:pub UserPanel(user: User) -> JsxElement {
        return <section class="panel">
            {try {
                <UserCardView user={user}/>
            } awaiting {
                <UserCardSkeleton/>
            }}
        </section>;
    }
}
```

The `try` body needs a Suspense-aware data primitive (today: a `use(promise)` call or a Suspense-integrated fetcher inside the rendered subtree) for the fallback to actually fire. The wrapper is the language-level integration point -- once the `flow`/`wait` story plugs into `use()`, the same source picks up real async behavior with no call-site change.

Add an `except` arm to name the error state alongside the loading state. The slot then lowers to a `<JacClientErrorBoundary fallback={...}>` **wrapping** the `<JacAwaiting>` node, so a throw anywhere in the resolved `try` body is caught and the `except` body renders instead:

```jac
cl {
    def:pub UserPanel(user: User) -> JsxElement {
        return <section class="panel">
            {try {
                <UserCardView user={user}/>
            } awaiting {
                <UserCardSkeleton/>
            } except Exception {
                <div class="card error">Couldn't load this user.</div>
            }}
        </section>;
    }
}
```

`JacClientErrorBoundary` is auto-imported from `@jac/runtime` -- the same boundary jac-client installs at the app root. Because a JS error boundary catches every error regardless of the declared type, per-type dispatch and the optional `except ... as <name>` binding are not modeled; the `except` bodies are concatenated in source order into the boundary's fallback.

**Notes:**

- `awaiting` is a clause of `try`; bare `awaiting { ... }` is a parse error.
- `finally` alongside `awaiting` is rejected (`E2022`) -- the cleanup timing relative to the in-flight window is ambiguous.
- `except` arms render through a synthesized `<JacClientErrorBoundary>` that wraps the `<JacAwaiting>` (cl target). An `except` without an `awaiting` clause stays an ordinary `try`/`except`.
- On `sv` and `na` targets the `awaiting` body is silently dropped with a `W2020` warning; the construct compiles as an ordinary `try` until the streaming-SSR and native-thread lowerings land.

### Raw HTML: `unsafe_html`

By default `{value}` is rendered as escaped text. The `unsafe_html(x)` ambient builtin returns a sentinel that the client runtime renders as raw HTML (via `dangerouslySetInnerHTML` on React, `innerHTML` on bare-serve). Use it only with content you trust -- the name is the security review hint at the call site:

```jac
cl {
    def:pub Comment(c: dict) -> JsxElement {
        return <article>
            <h3>{c["author"]}</h3>
            <div class="body">{unsafe_html(c["trusted_html"])}</div>
        </article>;
    }
}
```

---

## Separate Component Files

### Header.cl.jac

```jac
# No `cl { }` block needed for .cl.jac files

def:pub Header(title: str) -> JsxElement {
    return <header>
        <h1>{title}</h1>
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
    import "./styles.css";

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

### Scoped Styles (`.style.css`)

Drop a `.style.css` file with the **same base name** as a component and its
classes are auto-scoped to that component -- no import, no naming collisions.
The compiler hashes each declared class, rewrites the CSS, and rewrites the
matching `className` references to agree.

```jac
# Card.cl.jac
def:pub Card(title: str) -> JsxElement {
    return <div className="card">
        <h2 className="card-title">{title}</h2>
    </div>;
}
```

```css
/* Card.style.css -- paired by base name, no import required */
.card {
    padding: 1rem;
    border: 1px solid #ccc;
}
.card-title { font-weight: 600; }

/* :global(...) opts a selector out of scoping */
:global(body) { margin: 0; }
```

At compile time `className="card"` becomes `className="card-1419142b"` and
the CSS selector is hashed to match, so another component can declare its own
`.card` without conflict. Tokens not declared in the annex (like Tailwind
utilities) pass through unchanged. See the
[jac-client reference](../../reference/plugins/jac-client.md#scoped-css-stylecss-annexes)
for the full contract.

---

## Key Takeaways

| Concept | Syntax |
|---------|--------|
| Define component | `def:pub Name(title: str, count: int) -> JsxElement { }` |
| Statement slot | `{for x in xs { <li>{x}</li> }}` inside a JSX element |
| Early-exit guard | `skip;` inside a statement slot |
| Suspense fallback | `{try { <Resolved/> } awaiting { <Loading/> }}` (cl only) |
| Suspense + error fallback | `{try { <Resolved/> } awaiting { <Loading/> } except Exception { <Err/> }}` (cl only) |
| Raw HTML opt-in | `{unsafe_html(trusted_html)}` |
| Dynamic tag | `<@expr>...</@expr>` |
| JSX element | `<div className="x">content</div>` |
| Expression | `{expression}` |
| Click handler | `onClick={lambda -> None { ... }}` |
| Input handler | `onChange={lambda (e: ChangeEvent) { ... }}` |
| List rendering | `{[<li>{x}</li> for x in items]}` |
| Conditional | `{("A" if condition else "B")}` |
| Children | `def:pub Card(children: any = None) { ... }` then `{children}` |
| Forwarding bundle | `def:pub Wrap(props: dict)` (suppress W5015) |
| Import component | `import from "./File.cl.jac" { Component }` |

---

## Next Steps

- [State Management](state.md) - Reactive state with `has`
- [Backend Integration](backend.md) - Connect to walkers
