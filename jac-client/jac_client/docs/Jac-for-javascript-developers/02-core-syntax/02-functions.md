# Functions

Learn how to define and use functions in JAC-Client.

---

## Basic Function Syntax

### JavaScript vs JAC-Client

**JavaScript:**

```javascript
function greet() {
  return "Hello!";
}

function add(a, b) {
  return a + b;
}
```

**JAC-Client:**

```jac
def greet() -> str {
    return "Hello!";
}

def add(a: int, b: int) -> int {
    return a + b;
}
```

### Key Differences

1. Use `def` instead of `function`
2. Specify return type with `-> Type`
3. Parameters have type annotations

---

## Return Types

### Common Return Types

```jac
# Return string
def getName() -> str {
    return "John";
}

# Return number
def getAge() -> int {
    return 25;
}

# Return boolean
def isActive() -> bool {
    return True;
}

# Return any type (flexible)
def getData() -> any {
    return { "name": "John" };
}

# Return nothing (void)
def logMessage() -> None {
    console.log("Hello");
}
```

### React Components Return `any`

```jac
def MyComponent() -> any {
    return <div>Hello</div>;
}

def Button(label: str) -> any {
    return <button>{label}</button>;
}
```

---

## Parameters

### Typed Parameters

```jac
# Single parameter
def greet(name: str) -> str {
    return "Hello, " + name + "!";
}

# Multiple parameters
def add(a: int, b: int) -> int {
    return a + b;
}

# Mixed types
def createUser(name: str, age: int, active: bool) -> dict {
    return { "name": name, "age": age, "active": active };
}
```

### Default Parameters

```jac
def greet(name: str = "World") -> str {
    return "Hello, " + name + "!";
}

greet()        # "Hello, World!"
greet("John")  # "Hello, John!"
```

### Any Type Parameters

Use `any` for flexible parameters:

```jac
def processData(data: any) -> any {
    return data;
}

def handleEvent(e: any) -> None {
    console.log(e.target.value);
}
```

---

## Functions in Components

### Event Handlers

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    # Define handler function
    def handleIncrement() -> None {
        setCount(count + 1);
    }

    def handleDecrement() -> None {
        setCount(count - 1);
    }

    return (
        <div>
            <p>Count: {count}</p>
            <button onClick={lambda: handleIncrement()}>+</button>
            <button onClick={lambda: handleDecrement()}>-</button>
        </div>
    );
}
```

### Helper Functions

```jac
def TodoList() -> any {
    [todos, setTodos] = useState([]);

    # Helper function for rendering
    def renderTodo(todo: dict, index: int) -> any {
        return (
            <li key={todo["id"]}>
                {todo["text"]}
            </li>
        );
    }

    # Helper function for filtering
    def filterCompleted(todo: dict) -> bool {
        return todo["completed"];
    }

    completedTodos = todos.filter(filterCompleted);

    return (
        <ul>
            {todos.map(renderTodo)}
        </ul>
    );
}
```

---

## Async Functions

### JavaScript vs JAC-Client

**JavaScript:**

```javascript
async function fetchData() {
  const response = await fetch('/api/data');
  return response.json();
}
```

**JAC-Client:**

```jac
async def fetchData() {
    response = await fetch("/api/data");
    return response.json();
}
```

### Async in Components

```jac
def DataLoader() -> any {
    [data, setData] = useState(None);
    [loading, setLoading] = useState(False);

    async def loadData() {
        setLoading(True);
        try {
            response = await fetch("/api/data");
            result = await response.json();
            setData(result);
        } except {
            console.log("Error loading data");
        } finally {
            setLoading(False);
        }
    }

    return (
        <div>
            <button onClick={lambda: loadData()}>
                Load Data
            </button>
            {loading and <p>Loading...</p>}
            {data and <pre>{JSON.stringify(data)}</pre>}
        </div>
    );
}
```

---

## Exporting Functions

Use `:pub` to export functions:

```jac
# Private function (not exported)
def helperFunction() -> None {
    console.log("Helper");
}

# Public function (exported)
def:pub formatDate(date: any) -> str {
    return date.toLocaleDateString();
}

def:pub calculateTotal(items: list) -> float {
    total = 0;
    for item in items {
        total = total + item["price"];
    }
    return total;
}
```

### Importing Functions

```jac
# In another file
cl import from .utils { formatDate, calculateTotal }

def app() -> any {
    today = formatDate(Date());
    return <p>Today: {today}</p>;
}
```

---

## Functions as Parameters

```jac
# Function that takes a callback
def processItems(items: list, callback: any) -> list {
    results = [];
    for item in items {
        result = callback(item);
        results.push(result);
    }
    return results;
}

# Usage
def double(n: int) -> int {
    return n * 2;
}

numbers = [1, 2, 3, 4, 5];
doubled = processItems(numbers, double);  # [2, 4, 6, 8, 10]
```

---

## Nested Functions

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    def createHandler(amount: int) -> any {
        # Nested function that creates a handler
        def handler() -> None {
            setCount(count + amount);
        }
        return handler;
    }

    increment = createHandler(1);
    decrement = createHandler(-1);

    return (
        <div>
            <p>{count}</p>
            <button onClick={lambda: increment()}>+1</button>
            <button onClick={lambda: decrement()}>-1</button>
        </div>
    );
}
```

---

## Summary

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Basic function | `function fn() {}` | `def fn() -> any {}` |
| With return type | N/A | `def fn() -> str {}` |
| Parameters | `function fn(a, b)` | `def fn(a: int, b: int)` |
| No return | `function fn() {}` | `def fn() -> None {}` |
| Async | `async function fn()` | `async def fn()` |
| Export | `export function fn()` | `def:pub fn() -> any {}` |

---

## Next

- [Lambda Functions](03-lambda-functions.md) - Arrow function equivalent (most important!)
