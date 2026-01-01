# What is JAC-Client?

JAC-Client is a frontend programming language that combines Python-like syntax with React's component model. It compiles to JavaScript and React, giving you the best of both worlds.

---

## Why JAC-Client?

| Feature | Benefit |
|---------|---------|
| **Python-like syntax** | Familiar to Python developers, cleaner than JavaScript |
| **React compatible** | Uses JSX, hooks, and React ecosystem |
| **Type annotations** | Optional type hints for better code quality |
| **No boilerplate** | No `const`, `let`, `function` keywords needed |

---

## JAC-Client vs JavaScript

### Cleaner Syntax

**JavaScript:**

```javascript
const name = "John";
let count = 0;
const isActive = true;
const data = null;
```

**JAC-Client:**

```jac
name = "John"
count = 0
isActive = True
data = None
```

### Functions

**JavaScript:**

```javascript
function greet(name) {
  return `Hello, ${name}!`;
}

const double = (x) => x * 2;
```

**JAC-Client:**

```jac
def greet(name: str) -> str {
    return "Hello, " + name + "!";
}

double = lambda x: int -> int { return x * 2; }
```

### React Components

**JavaScript/React:**

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  );
}
```

**JAC-Client:**

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    return (
        <button onClick={lambda: setCount(count + 1)}>
            Count: {count}
        </button>
    );
}
```

---

## Core Concepts

### 1. The `cl` Block

All client-side (frontend) code must be wrapped in a `cl { }` block:

```jac
cl {
    def app() -> any {
        return <h1>Hello!</h1>;
    }
}
```

### 2. The `app()` Entry Point

Every JAC-Client project needs an `app.jac` file with a `def app()` function:

```jac
cl {
    def app() -> any {
        return <div>Your app here</div>;
    }
}
```

### 3. Imports

Import npm packages and other files using `cl import`:

```jac
# Import from npm packages
cl import from react { useState, useEffect }
cl import from react-router-dom { Link, useNavigate }

# Import from local files
cl import from ./components { Header, Footer }
```

### 4. Lambda Functions

Arrow functions in JavaScript become lambdas in JAC:

```jac
# No parameters
onClick={lambda: doSomething()}

# With parameters
onChange={lambda e: any -> None { setName(e.target.value); }}

# With return value
doubled = numbers.map(lambda n: int, i: int -> int { return n * 2; })
```

---

## What Makes JAC Different

### Python-Style Conditionals

**JavaScript:**

```javascript
isLoggedIn ? <Dashboard /> : <Login />
```

**JAC-Client:**

```jac
(<Dashboard />) if isLoggedIn else (<Login />)
```

### No `let` or `const`

Just assign directly:

```jac
name = "John"
[count, setCount] = useState(0)
items = [1, 2, 3]
```

### Quoted Object Keys

Object keys must be strings:

```jac
# JAC-Client
user = { "name": "John", "age": 25 }
style = { "padding": "10px", "margin": "5px" }
```

### Property Access

Use bracket notation:

```jac
name = user["name"]
value = props["value"]
```

---

## When to Use JAC-Client

**Good for:**

- Building React-style web applications
- Teams familiar with Python syntax
- Projects that benefit from optional typing
- Rapid prototyping with cleaner syntax

**JAC-Client ecosystem:**

- Full React hooks support
- React Router integration
- State management (Zustand, Redux)
- Form libraries (React Hook Form)
- Styling (Tailwind, styled-components)

---

## Next Steps

- [Quick Start Guide](02-quick-start.md) - Build your first component
- [Syntax Cheatsheet](03-syntax-cheatsheet.md) - Quick reference for all syntax

---

## Summary

JAC-Client is essentially **React with Python syntax**. If you know:

- **Python**: The syntax will feel natural
- **React**: The component model and hooks work the same
- **JavaScript**: You just need to learn the syntax differences

The learning curve is minimal - most concepts translate directly!
