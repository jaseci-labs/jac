# JSX in JAC

Learn the differences between JSX in JavaScript/React and JAC-Client.

---

## JSX Basics

JSX works mostly the same in JAC-Client as in React, with a few key differences.

### Same as React

```jac
# Elements
<div>Hello</div>
<button>Click me</button>

# Self-closing tags
<img src="image.png" />
<input type="text" />
<br />

# Nesting
<div>
    <h1>Title</h1>
    <p>Paragraph</p>
</div>
```

---

## Expressions in JSX

### JavaScript Expressions

Use curly braces for expressions:

```jac
# Variables
<p>{name}</p>
<p>{count}</p>

# Expressions
<p>{count + 1}</p>
<p>{firstName + " " + lastName}</p>

# Function calls
<p>{formatDate(date)}</p>
<p>{items.length}</p>

# Conditional (ternary)
<p>{("Yes") if isActive else ("No")}</p>
```

---

## Attributes/Props

### String Attributes

```jac
<input type="text" placeholder="Enter name" />
<a href="/about">About</a>
<img src="image.png" alt="Description" />
```

### Dynamic Attributes

```jac
<input value={name} />
<a href={url}>Link</a>
<img src={imageUrl} />
<button disabled={isLoading}>Submit</button>
```

### Boolean Attributes

```jac
# True
<input disabled={True} />
<button hidden={True} />

# False
<input disabled={False} />

# Dynamic
<button disabled={isLoading}>Submit</button>
```

---

## Styling in JSX

### Inline Styles - Key Difference!

Object keys must be quoted strings:

**React:**

```jsx
<div style={{ padding: "10px", backgroundColor: "#fff" }}>
```

**JAC-Client:**

```jac
<div style={{ "padding": "10px", "backgroundColor": "#fff" }}>
```

### Example

```jac
def StyledComponent() -> any {
    buttonStyle = {
        "padding": "10px 20px",
        "backgroundColor": "#007bff",
        "color": "white",
        "border": "none",
        "borderRadius": "5px",
        "cursor": "pointer"
    };

    return <button style={buttonStyle}>Styled Button</button>;
}
```

### Dynamic Styles

```jac
def DynamicStyle(active: bool, children: any) -> any {
    bgColor = ("#28a745") if active else ("#6c757d");

    return (
        <div style={{
            "padding": "15px",
            "backgroundColor": bgColor,
            "color": "white"
        }}>
            {children}
        </div>
    );
}
```

---

## CSS Classes

### className Attribute

```jac
<div className="container">
    <h1 className="title">Hello</h1>
    <p className="text-muted">Description</p>
</div>
```

### Dynamic Classes

```jac
def Button(label: str, primary: bool, large: bool) -> any {
    baseClass = "btn";
    colorClass = ("btn-primary") if primary else ("btn-secondary");
    sizeClass = ("btn-lg") if large else ("btn-sm");

    className = baseClass + " " + colorClass + " " + sizeClass;

    return <button className={className}>{label}</button>;
}
```

### Conditional Classes

```jac
def Tab(label: str, active: bool) -> any {
    className = ("tab active") if active else ("tab");

    return (
        <div className={className}>
            {label}
        </div>
    );
}
```

---

## Event Handlers

### onClick

```jac
# Short form
<button onClick={lambda: handleClick()}>Click</button>

# With event
<button onClick={lambda e: any -> None {
    e.preventDefault();
    handleClick();
}}>Click</button>
```

### onChange

```jac
<input
    value={name}
    onChange={lambda e: any -> None { setName(e.target.value); }}
/>
```

### onSubmit

```jac
<form onSubmit={lambda e: any -> None {
    e.preventDefault();
    handleSubmit();
}}>
    <button type="submit">Submit</button>
</form>
```

### Other Events

```jac
<input onFocus={lambda: console.log("focused")} />
<input onBlur={lambda: console.log("blurred")} />
<div onMouseEnter={lambda: setHovered(True)} />
<div onMouseLeave={lambda: setHovered(False)} />
<input onKeyDown={lambda e: any -> None { handleKey(e); }} />
```

---

## Conditional Rendering in JSX

### Ternary (Python Style!)

```jac
# Simple text
<p>{("Active") if isActive else ("Inactive")}</p>

# Components - WRAP IN PARENTHESES!
{(<Dashboard />) if isLoggedIn else (<Login />)}

# Nested
<p>{("A") if score >= 90 else (("B") if score >= 80 else ("C"))}</p>
```

### Logical AND

```jac
{isLoggedIn and <Dashboard />}
{count > 0 and <p>Count: {count}</p>}
{items.length > 0 and <ItemList items={items} />}
```

### Logical OR

```jac
{username or "Guest"}
{data or "No data available"}
```

---

## Lists in JSX

### Using map

```jac
def renderItem(item: dict, index: int) -> any {
    return <li key={item["id"]}>{item["name"]}</li>;
}

<ul>{items.map(renderItem)}</ul>
```

### Inline Map

```jac
<ul>
    {items.map(lambda item: dict, index: int -> any {
        return <li key={item["id"]}>{item["name"]}</li>;
    })}
</ul>
```

### Keys

Always provide unique keys:

```jac
# Good - unique ID
<li key={item["id"]}>{item["name"]}</li>

# Acceptable - index when no ID
<li key={index}>{item["name"]}</li>

# Bad - no key (will cause warning)
<li>{item["name"]}</li>
```

---

## Fragments

### Empty Fragment

```jac
<>
    <h1>Title</h1>
    <p>Description</p>
</>
```

### Return Nothing

```jac
def MaybeRender(show: bool) -> any {
    if not show {
        return <></>;  # Empty fragment
    }

    return <div>Content</div>;
}
```

---

## Comments in JSX

```jac
def Component() -> any {
    return (
        <div>
            # This is a comment in JSX
            <h1>Title</h1>
        </div>
    );
}
```

---

## Embedding Raw HTML

Use dangerouslySetInnerHTML (same as React):

```jac
def RawHTML(html: str) -> any {
    return (
        <div dangerouslySetInnerHTML={{ "__html": html }} />
    );
}

# Usage (be careful with XSS!)
<RawHTML html="<strong>Bold</strong> text" />
```

---

## Common JSX Patterns

### Conditional Attributes

```jac
<input
    type="text"
    disabled={isLoading}
    placeholder={("Loading...") if isLoading else ("Enter text")}
/>
```

### Spread Attributes Alternative

```jac
# Pass individual props
<Input
    value={value}
    onChange={onChange}
    placeholder={placeholder}
/>
```

### Multiple Classes

```jac
classes = "btn";
if isPrimary {
    classes = classes + " btn-primary";
}
if isLarge {
    classes = classes + " btn-lg";
}
if isDisabled {
    classes = classes + " disabled";
}

<button className={classes}>Button</button>
```

---

## Summary

| Feature | React | JAC-Client |
|---------|-------|------------|
| Style keys | `{ padding: "10px" }` | `{ "padding": "10px" }` |
| Ternary | `a ? b : c` | `(b) if a else (c)` |
| AND render | `{x && <Y />}` | `{x and <Y />}` |
| OR default | `{x \|\| "default"}` | `{x or "default"}` |
| Event handler | `onClick={() => {}}` | `onClick={lambda: fn()}` |
| Empty return | `return null` | `return <></>` |
| Comments | `{/* comment */}` | `{# comment #}` |

---

## Next Section

- [State and Hooks](../04-state-and-hooks/) - useState, useEffect, and more
