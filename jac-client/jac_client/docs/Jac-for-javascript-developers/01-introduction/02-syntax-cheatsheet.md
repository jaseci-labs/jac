# Syntax Cheatsheet

Quick reference for all JAC-Client syntax. Print it, bookmark it, keep it handy!

---

## Variables

| JavaScript | JAC-Client |
|-----------|------------|
| `const name = "John"` | `name = "John"` |
| `let count = 0` | `count = 0` |
| `const arr = [1, 2, 3]` | `arr = [1, 2, 3]` |
| `const obj = { a: 1 }` | `obj = { "a": 1 }` |

---

## Data Types

| Type | JavaScript | JAC-Client |
|------|-----------|------------|
| Boolean true | `true` | `True` |
| Boolean false | `false` | `False` |
| Null | `null` | `None` |
| Undefined | `undefined` | `None` |
| String | `"hello"` | `"hello"` |
| Number | `42` | `42` |
| Array | `[1, 2, 3]` | `[1, 2, 3]` |
| Object | `{ key: val }` | `{ "key": val }` |

---

## Functions

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Basic | `function greet() {}` | `def greet() -> any {}` |
| With params | `function add(a, b) {}` | `def add(a: int, b: int) -> int {}` |
| No return | `function log() {}` | `def log() -> None {}` |
| Async | `async function fn() {}` | `async def fn() {}` |

---

## Lambda Functions (Arrow Functions)

This is the **biggest syntax change**!

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| No params | `() => {}` | `lambda -> None {}` |
| No params (short) | `() => doIt()` | `lambda: doIt()` |
| One param | `(x) => {}` | `lambda x: any -> None {}` |
| Two params | `(a, b) => {}` | `lambda a: any, b: any -> None {}` |
| With return | `(x) => x * 2` | `lambda x: int -> int { return x * 2; }` |
| Event handler | `(e) => {}` | `lambda e: any -> None {}` |

### Common Patterns

```jac
# Short form (single expression)
onClick={lambda: setCount(count + 1)}

# With event object
onChange={lambda e: any -> None { setName(e.target.value); }}

# Multiple statements
onClick={lambda -> None {
    setCount(count + 1);
    console.log("clicked");
}}
```

---

## State (useState)

| JavaScript | JAC-Client |
|-----------|------------|
| `const [x, setX] = useState(0)` | `[x, setX] = useState(0)` |
| `const [name, setName] = useState("")` | `[name, setName] = useState("")` |
| `const [on, setOn] = useState(false)` | `[on, setOn] = useState(False)` |
| `const [items, setItems] = useState([])` | `[items, setItems] = useState([])` |

```jac
cl import from react { useState }

[count, setCount] = useState(0);
[name, setName] = useState("");
[isActive, setIsActive] = useState(False);
```

---

## Effects (useEffect)

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| On mount | `useEffect(() => {}, [])` | `useEffect(lambda -> None {}, [])` |
| On change | `useEffect(() => {}, [dep])` | `useEffect(lambda -> None {}, [dep])` |
| With cleanup | `useEffect(() => { return () => {} }, [])` | `useEffect(lambda -> None { return lambda -> None {}; }, [])` |

---

## Conditional Rendering

### Ternary (Python Style!)

| JavaScript | JAC-Client |
|-----------|------------|
| `condition ? a : b` | `(a) if condition else (b)` |

```jac
# Simple
{("Yes") if isActive else ("No")}

# JSX - WRAP IN PARENTHESES!
{(<LoggedIn />) if isLoggedIn else (<LoggedOut />)}

# Nested
{("A") if x > 10 else (("B") if x > 5 else ("C"))}
```

### Logical Operators

| Operator | JavaScript | JAC-Client |
|----------|-----------|------------|
| AND | `&&` | `and` |
| OR | `\|\|` | `or` |
| NOT | `!` | `not` |

```jac
# AND - Show if true
{isLoggedIn and <Dashboard />}

# OR - Default value
{username or "Guest"}

# NOT
{not isLoading and <Content />}
```

### Return Nothing

| JavaScript | JAC-Client |
|-----------|------------|
| `return null` | `return <></>` |

---

## Loops

### For Loop (Counter-based)

| JavaScript | JAC-Client |
|-----------|------------|
| `for(let i=0; i<5; i++)` | `for i=0 to i<5 by i+=1` |

```jac
# Basic (0 to 4)
for i=0 to i<5 by i+=1 {
    console.log(i);
}

# Start from different value
for i=10 to i<20 by i+=1 {
    console.log(i);
}

# Custom step
for i=0 to i<10 by i+=2 {
    console.log(i);  # 0, 2, 4, 6, 8
}

# Countdown
for i=5 to i>=0 by i-=1 {
    console.log(i);  # 5, 4, 3, 2, 1, 0
}
```

### For-In Loop (Iterate Array)

| JavaScript | JAC-Client |
|-----------|------------|
| `for(item of items)` | `for item in items` |

```jac
fruits = ["apple", "banana", "cherry"];

for fruit in fruits {
    console.log(fruit);
}
```

### While Loop

| JavaScript | JAC-Client |
|-----------|------------|
| `while(condition)` | `while condition` |

```jac
count = 0;
while count < 5 {
    console.log(count);
    count = count + 1;
}
```

---

## Array Methods

```jac
# Map - use helper function
def double(n: int, index: int) -> int {
    return n * 2;
}
doubled = numbers.map(double);

# Filter
evens = numbers.filter(lambda n: int -> bool { return n % 2 == 0; });

# Find
user = users.find(lambda u: dict -> bool { return u["id"] == searchId; });

# Some
hasAdults = users.some(lambda u: dict -> bool { return u["age"] >= 18; });

# Every
allAdults = users.every(lambda u: dict -> bool { return u["age"] >= 18; });

# Reduce
total = prices.reduce(lambda acc: int, x: int -> int { return acc + x; }, 0);
```

---

## Objects/Dictionaries

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Create | `{ key: value }` | `{ "key": value }` |
| Access | `obj.key` | `obj["key"]` |
| Spread | `{...obj}` | `{**obj}` |

```jac
# Create - keys MUST be quoted
user = { "name": "John", "age": 25 };

# Access - use bracket notation
name = user["name"];

# Spread
newUser = { **user, "age": 26 };
```

---

## Imports

| JavaScript | JAC-Client |
|-----------|------------|
| `import { x } from 'lib'` | `cl import from lib { x }` |
| `import { x, y } from 'lib'` | `cl import from lib { x, y }` |
| `import './style.css'` | `cl import "./style.css"` |

```jac
# React hooks
cl import from react { useState, useEffect, useCallback }

# Router
cl import from react-router-dom { Link, useNavigate }

# Local files
cl import from .components { Header, Footer }
cl import from .utils { formatDate }
```

---

## Exports

Use `:pub` annotation to export:

| JavaScript | JAC-Client |
|-----------|------------|
| `export function fn()` | `def:pub fn() -> any {}` |
| `export const x = 5` | `glob:pub x: int = 5` |
| `export class Foo` | `obj:pub Foo {}` |

```jac
# Export function
def:pub formatDate(date: any) -> str {
    return date.toLocaleDateString();
}

# Export constant
glob:pub API_URL: str = "https://api.example.com";

# Export class/object
obj:pub UserModel {
    has name: str;
    has age: int;
}

# Export enum
enum:pub Status {
    ACTIVE = "active",
    INACTIVE = "inactive"
}
```

---

## Exception Handling

| JavaScript | JAC-Client |
|-----------|------------|
| `try { } catch(e) { }` | `try { } except { }` |
| `try { } catch(e) { } finally { }` | `try { } except { } finally { }` |

```jac
try {
    result = riskyOperation();
} except {
    console.log("Error occurred");
} finally {
    cleanup();
}
```

---

## Comments

| JavaScript | JAC-Client |
|-----------|------------|
| `// comment` | `# comment` |
| `/* multi */` | `# each line` |

---

## Quick Reference Table

| Category | JavaScript | JAC-Client |
|----------|-----------|------------|
| Variable | `const x = 5` | `x = 5` |
| State | `const [x, setX] = useState(0)` | `[x, setX] = useState(0)` |
| Function | `function fn() {}` | `def fn() -> any {}` |
| Arrow (none) | `() => {}` | `lambda -> None {}` |
| Arrow (short) | `() => doIt()` | `lambda: doIt()` |
| Arrow (params) | `(a, b) => {}` | `lambda a: any, b: any -> None {}` |
| Ternary | `a ? b : c` | `(b) if a else (c)` |
| AND | `&&` | `and` |
| OR | `\|\|` | `or` |
| NOT | `!x` | `not x` |
| True | `true` | `True` |
| False | `false` | `False` |
| Null | `null` | `None` |
| Object | `{ key: val }` | `{ "key": val }` |
| Access | `obj.key` | `obj["key"]` |
| Spread | `{...obj}` | `{**obj}` |
| For | `for(let i=0; i<5; i++)` | `for i=0 to i<5 by i+=1` |
| For-of | `for(x of arr)` | `for x in arr` |
| Try/Catch | `try {} catch {}` | `try {} except {}` |
| Comment | `// text` | `# text` |
| Import | `import { x } from 'lib'` | `cl import from lib { x }` |
| Export | `export function fn()` | `def:pub fn() -> any {}` |
| Return null | `return null` | `return <></>` |

---

Happy coding with JAC!
