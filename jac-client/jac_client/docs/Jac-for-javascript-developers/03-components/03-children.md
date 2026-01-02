# Children and Composition

Learn how to compose components and pass children in Jac.

---

## Children Basics

### JavaScript/React

```jsx
function Card({ children }) {
  return <div className="card">{children}</div>;
}

<Card>
  <h1>Title</h1>
  <p>Content</p>
</Card>;
```

### Jac

```jac
def Card(children: any) -> any {
    return (
        <div style={{ "border": "1px solid #ccc", "padding": "15px" }}>
            {children}
        </div>
    );
}

<Card>
    <h1>Title</h1>
    <p>Content</p>
</Card>
```

Children are passed as a direct parameter. **Note:** You can also access as `props.children` if needed.

---

## Wrapper Components

### Layout Wrapper

```jac
def PageLayout(children: any) -> any {
    return (
        <div style={{ "maxWidth": "1200px", "margin": "0 auto" }}>
            <header style={{ "padding": "20px", "backgroundColor": "#f5f5f5" }}>
                <h1>My App</h1>
            </header>
            <main style={{ "padding": "20px" }}>
                {children}
            </main>
            <footer style={{ "padding": "20px", "backgroundColor": "#333", "color": "white" }}>
                Footer
            </footer>
        </div>
    );
}

# Usage
def app() -> any {
    return (
        <PageLayout>
            <h2>Welcome</h2>
            <p>This is the content area.</p>
        </PageLayout>
    );
}
```

### Card Wrapper with Title

```jac
def Card(title: str, children: any) -> any {
    return (
        <div style={{
            "backgroundColor": "white",
            "borderRadius": "8px",
            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)",
            "padding": "20px",
            "marginBottom": "20px"
        }}>
            {title and <h3>{title}</h3>}
            {children}
        </div>
    );
}

# Usage
<Card title="User Profile">
    <p>Name: John Doe</p>
    <p>Email: john@example.com</p>
</Card>
```

---

## Conditional Children

```jac
def Modal(isOpen: bool, onClose: any, children: any) -> any {
    if not isOpen {
        return <></>;
    }

    return (
        <div style={{
            "position": "fixed",
            "top": "0",
            "left": "0",
            "right": "0",
            "bottom": "0",
            "backgroundColor": "rgba(0,0,0,0.5)",
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center"
        }}>
            <div style={{
                "backgroundColor": "white",
                "padding": "20px",
                "borderRadius": "8px",
                "minWidth": "300px"
            }}>
                <button
                    onClick={onClose}
                    style={{ "float": "right" }}
                >
                    X
                </button>
                {children}
            </div>
        </div>
    );
}

# Usage
def app() -> any {
    [isOpen, setIsOpen] = useState(False);

    return (
        <div>
            <button onClick={lambda: setIsOpen(True)}>Open Modal</button>

            <Modal isOpen={isOpen} onClose={lambda: setIsOpen(False)}>
                <h2>Modal Title</h2>
                <p>Modal content goes here.</p>
            </Modal>
        </div>
    );
}
```

---

## Multiple Children Slots

### Using Props for Named Slots

```jac
def Layout(header: any, footer: any, children: any) -> any {
    return (
        <div style={{ "display": "grid", "gridTemplateRows": "auto 1fr auto" }}>
            <header>{header}</header>
            <main>{children}</main>
            <footer>{footer}</footer>
        </div>
    );
}

# Usage
<Layout
    header={<nav>Navigation</nav>}
    footer={<p>Copyright 2026</p>}
>
    <article>Main content</article>
</Layout>
```

---

## Composing Components

### Small, Focused Components

```jac
cl import from react { useState }

cl {
    # Small, reusable button
    def IconButton(icon: str, label: str, onClick: any, color: str) -> any {
        buttonColor = color or "#007bff";
        return (
            <button
                onClick={onClick}
                style={{
                    "padding": "8px 12px",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer",
                    "backgroundColor": buttonColor,
                    "color": "white"
                }}
            >
                {icon} {label}
            </button>
        );
    }

    # Composed toolbar
    def Toolbar(children: any) -> any {
        return (
            <div style={{ "display": "flex", "gap": "10px", "marginBottom": "20px" }}>
                {children}
            </div>
        );
    }

    # Usage
    def Editor() -> any {
        [content, setContent] = useState("");

        return (
            <div>
                <Toolbar>
                    <IconButton icon="B" label="Bold" color="#007bff" onClick={lambda: console.log("bold")} />
                    <IconButton icon="I" label="Italic" color="#007bff" onClick={lambda: console.log("italic")} />
                    <IconButton icon="U" label="Underline" color="#007bff" onClick={lambda: console.log("underline")} />
                </Toolbar>
                <textarea
                    value={content}
                    onChange={lambda e: any -> None { setContent(e.target.value); }}
                    style={{ "width": "100%", "height": "200px" }}
                />
            </div>
        );
    }

    def app() -> any {
        return <Editor />;
    }
}
```

---

## Higher-Order Components Pattern

### Wrapping Components

```jac
def withLoading(WrappedComponent: any) -> any {
    def WithLoadingComponent(props: dict) -> any {
        if props["isLoading"] {
            return <p>Loading...</p>;
        }
        return <WrappedComponent {...props} />;
    }
    return WithLoadingComponent;
}

# Note: This pattern is less common in Jac
# Prefer composition with children instead
```

---

## Render Props Pattern

```jac
def MouseTracker(render: any) -> any {
    [position, setPosition] = useState({ "x": 0, "y": 0 });

    def handleMouseMove(e: any) -> None {
        setPosition({ "x": e.clientX, "y": e.clientY });
    }

    return (
        <div
            onMouseMove={handleMouseMove}
            style={{ "height": "100vh" }}
        >
            {render(position)}
        </div>
    );
}

# Usage
<MouseTracker render={lambda pos: dict -> any {
    return <p>Mouse: {pos["x"]}, {pos["y"]}</p>;
}} />
```

---

## Component List Patterns

### Mapping Children Alternatives

```jac
def List(items: list) -> any {
    itemList = items or [];

    def renderItem(item: dict, index: int) -> any {
        return (
            <li key={item["id"]} style={{ "padding": "10px" }}>
                {item["name"]}
            </li>
        );
    }

    return <ul>{itemList.map(renderItem)}</ul>;
}

# Usage
<List items={[
    { "id": 1, "name": "Item 1" },
    { "id": 2, "name": "Item 2" },
    { "id": 3, "name": "Item 3" }
]} />
```

### Custom Item Renderer

```jac
def List(items: list, renderItem: any) -> any {
    itemList = items or [];

    def defaultRender(item: any, index: int) -> any {
        return <li key={index}>{item}</li>;
    }

    renderer = renderItem or defaultRender;

    return <ul>{itemList.map(renderer)}</ul>;
}

# Usage with custom renderer
<List
    items={users}
    renderItem={lambda user: dict, index: int -> any {
        return (
            <li key={user["id"]}>
                <strong>{user["name"]}</strong> - {user["email"]}
            </li>
        );
    }}
/>
```

---

## Summary

| Pattern            | Description                         |
| ------------------ | ----------------------------------- |
| `children: any`    | Children passed as direct parameter |
| `props.children`   | Alternative access via props        |
| Named slots        | Pass components as separate props   |
| Wrapper components | Use children for content            |
| Conditional render | Show/hide based on parameters       |
| Composition        | Build complex from simple           |

---

## Next

- [JSX in JAC](04-jsx-in-jac.md) - JSX syntax differences
