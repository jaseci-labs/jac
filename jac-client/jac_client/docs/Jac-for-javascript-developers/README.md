# JAC for JavaScript Developers

A comprehensive learning path for JavaScript developers transitioning to JAC-Client. This series covers everything from basic syntax to advanced patterns.

---

## What is JAC-Client?

JAC-Client is a programming language that combines Python-like syntax with React's component model. If you know JavaScript and React, you're 80% there - this guide covers the 20% that's different.

**Key characteristics:**

- Python-inspired syntax (no semicolons required, `def` for functions)
- React-compatible JSX for UI components
- Compiles to JavaScript/React
- Built-in support for hooks, routing, and state management

---

## TL;DR - The Key Differences

| Concept | JavaScript | JAC-Client |
|---------|-----------|------------|
| Variable | `const x = 5` | `x = 5` |
| State | `const [x, setX] = useState(0)` | `[x, setX] = useState(0)` |
| Function | `function fn() {}` | `def fn() -> any {}` |
| Arrow function | `() => {}` | `lambda -> None {}` |
| Arrow (short) | `() => doIt()` | `lambda: doIt()` |
| Ternary | `a ? b : c` | `(b) if a else (c)` |
| AND | `&&` | `and` |
| OR | `\|\|` | `or` |
| NOT | `!x` | `not x` |
| Boolean | `true / false` | `True / False` |
| Null | `null` | `None` |
| Object | `{ key: val }` | `{ "key": val }` |
| Property access | `obj.key` | `obj["key"]` |
| For loop | `for(let i=0; i<5; i++)` | `for i=0 to i<5 by i+=1` |
| For-of | `for(x of arr)` | `for x in arr` |
| Import | `import { x } from 'lib'` | `cl import from lib { x }` |
| Export | `export function fn()` | `def:pub fn() -> any {}` |
| Comment | `// comment` | `# comment` |

---

## Learning Path

### Beginner Level

| # | Section | Description |
|---|---------|-------------|
| 01 | [Introduction](01-introduction/) | What is JAC, quick start, syntax cheatsheet |
| 02 | [Core Syntax](02-core-syntax/) | Variables, functions, lambdas, operators |
| 03 | [Components](03-components/) | Component structure, props, children, JSX |

### Intermediate Level

| # | Section | Description |
|---|---------|-------------|
| 04 | [State & Hooks](04-state-and-hooks/) | useState, useEffect, useCallback, useMemo, useRef |
| 05 | [Event Handling](05-event-handling/) | Click, form, and keyboard events |
| 06 | [Conditional Rendering](06-conditional-rendering/) | Ternary, logical operators, advanced patterns |
| 07 | [Lists & Loops](07-lists-and-loops/) | For loops, for-in, while, array methods |
| 08 | [Exception Handling](08-exception-handling/) | try/except patterns |

### Advanced Level

| # | Section | Description |
|---|---------|-------------|
| 09 | [Imports & Exports](09-imports-and-exports/) | Module system, npm packages, local files |
| 10 | [Project Structure](10-project-structure/) | File organization, nested folders |
| 11 | [Styling](11-styling/) | Inline styles, CSS, Tailwind, styled-components |
| 12 | [Forms](12-forms/) | Controlled inputs, React Hook Form |
| 13 | [Routing](13-routing/) | React Router integration |
| 14 | [State Management](14-state-management/) | Zustand, Redux, React Query |
| 15 | [Authentication](15-authentication/) | Login/logout, protected routes |

### Reference

| # | Section | Description |
|---|---------|-------------|
| 16 | [Appendix](16-appendix/) | Complete reference, gotchas, migration guide |

---

## Quick Start

### Your First JAC Component

**JavaScript/React:**

```jsx
import { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>
        Increment
      </button>
    </div>
  );
}

export default function App() {
  return <Counter />;
}
```

**JAC-Client:**

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

### Key Differences in This Example

1. `cl import from react` instead of `import from 'react'`
2. `cl { }` block wraps all client-side code
3. `def Counter() -> any` instead of `function Counter()`
4. `[count, setCount] = useState(0)` - no `const`
5. `lambda: setCount(count + 1)` instead of `() => setCount(count + 1)`
6. `def app()` is the required entry point

---

## Project Structure

A typical JAC-Client project:

```
my-app/
├── jac.toml              # Project configuration
├── src/
│   ├── app.jac           # Required entry point
│   ├── components/       # Reusable components
│   └── utils/            # Utility functions
├── assets/               # Static assets
└── build/                # Build output
```

### The Entry Point (`app.jac`)

Every JAC-Client project must have an `app.jac` file with an `app()` function:

```jac
cl {
    def app() -> any {
        return <div>
            <h1>Hello, World!</h1>
        </div>;
    }
}
```

---

## Running Your App

```bash
# Install dependencies
npm install

# Start development server
jac serve src/app.jac

# Or use jac.toml entry-point
jac serve
```

Your app will be available at `http://localhost:8000/page/app`

---

## Next Steps

1. Start with [01-introduction/01-what-is-jac.md](01-introduction/01-what-is-jac.md)
2. Try the [Quick Start example](01-introduction/02-quick-start.md)
3. Reference the [Syntax Cheatsheet](01-introduction/03-syntax-cheatsheet.md) as you learn

Happy coding with JAC!
