# Lambda Functions in JAC-Client (Onelang)

This guide explains how JavaScript arrow functions translate to lambda functions in JAC-Client.

> **Full Examples**: See the complete working examples at [jac-client-examples/arrow-functions](https://github.com/jaseci-labs/jac-client-examples/tree/main/arrow-functions)

---

## Arrow Functions to Lambda Functions

If you are coming from a React/JavaScript background, this guide will help you understand how arrow functions translate to lambda functions in JAC-Client (Onelang).

---

## Key Concept

| React/JavaScript | JAC-Client (Onelang)                   |
| ---------------- | -------------------------------------- |
| `() => { }`      | `lambda -> None { }`                   |
| `(param) => { }` | `lambda param: Type -> ReturnType { }` |
| `param => expr`  | `lambda: expression`                   |
| Arrow function   | Lambda function                        |

---

## Syntax Reference

### 1. No Parameters

```javascript
// React/JavaScript
const sayHello = () => {
  console.log("Hello!");
};

// Short form
() => console.log("Hello!");
```

```jac
# JAC-Client - Full syntax with body
let sayHello = lambda -> None {
    console.log("Hello!");
};

# Short form (expression)
lambda: console.log("Hello!")
```

---

### 2. Single Parameter

```javascript
// React/JavaScript
const double = (n) => {
  return n * 2;
};

// Short form
n => n * 2

// Event handler
(e) => setInputValue(e.target.value)
```

```jac
# JAC-Client - Single parameter
let double = lambda n: int -> int {
    return n * 2;
};

# Event handler
lambda e: any -> None { setInputValue(e.target.value); }

# Inline call (wrapping with lambda)
onClick={lambda: double(5)}
```

---

### 3. Multiple Parameters

```javascript
// React/JavaScript
const add = (a, b) => {
  return a + b;
};

// With handler
const handleSelect = (id, name) => {
  setSelected({ id, name });
};
```

```jac
# JAC-Client - Multiple parameters
let add = lambda a: int, b: int -> int {
    return a + b;
};

# With handler
let handleSelect = lambda id: int, name: str -> None {
    setSelected({ "id": id, "name": name });
};

# Usage - wrap in lambda to pass arguments
onClick={lambda: handleSelect(1, "Apple")}
```

---

### 4. Return Types

| Scenario         | JAC-Client Syntax                          |
| ---------------- | ------------------------------------------ |
| No return (void) | `lambda -> None { ... }`                   |
| Returns int      | `lambda -> int { return 42; }`             |
| Returns string   | `lambda -> str { return "hello"; }`        |
| Returns any      | `lambda -> any { return value; }`          |
| Returns JSX      | `lambda -> any { return <div>...</div>; }` |

---

## Common Patterns

### Event Handlers

```javascript
// React - onClick handler
<button onClick={() => handleClick(id)}>Click</button>

// React - onChange handler
<input onChange={(e) => setValue(e.target.value)} />
```

```jac
# JAC-Client - onClick handler
<button onClick={lambda: handleClick(id)}>Click</button>

# JAC-Client - onChange handler (define handler first)
let handleChange = lambda e: any -> None {
    setValue(e.target.value);
};
<input onChange={handleChange} />
```

---

### Complex Inline onClick with Lambda

When you need to do multiple things or have logic inside an onClick handler:

```javascript
// React - Multiple actions in onClick
<button onClick={() => {
  setLoading(true);
  fetchData();
  console.log("Clicked!");
}}>
  Submit
</button>

// React - Conditional logic in onClick
<button onClick={() => {
  if (isValid) {
    handleSubmit();
  } else {
    showError("Invalid input");
  }
}}>
  Submit
</button>

// React - Prevent default + action
<form onSubmit={(e) => {
  e.preventDefault();
  handleSubmit();
}}>
```

```jac
# JAC-Client - Multiple actions in onClick
<button onClick={lambda -> None {
    setLoading(True);
    fetchData();
    console.log("Clicked!");
}}>
    Submit
</button>

# JAC-Client - Conditional logic in onClick
<button onClick={lambda -> None {
    if isValid {
        handleSubmit();
    } else {
        showError("Invalid input");
    }
}}>
    Submit
</button>

# JAC-Client - Prevent default + action
<form onSubmit={lambda e: any -> None {
    e.preventDefault();
    handleSubmit();
}}>
```

**Key Syntax Difference:**

| Pattern | React | JAC-Client |
|---------|-------|----------|
| Simple call | `onClick={() => fn()}` | `onClick={lambda: fn()}` |
| With event | `onClick={(e) => fn(e)}` | `onClick={lambda e: any -> None { fn(e); }}` |
| Multi-line | `onClick={() => { a(); b(); }}` | `onClick={lambda -> None { a(); b(); }}` |
| With logic | `onClick={() => { if(x) a(); }}` | `onClick={lambda -> None { if x { a(); } }}` |

---

### useEffect

```javascript
// React
useEffect(() => {
  console.log("Effect ran!");
  return () => cleanup();
}, [deps]);
```

```jac
# JAC-Client
useEffect(lambda -> None {
    console.log("Effect ran!");
    # cleanup return is handled differently
}, [deps]);
```

---

### useCallback and useMemo

```javascript
// React - useCallback
const memoizedCallback = useCallback(() => {
  doSomething(a, b);
}, [a, b]);

// React - useMemo
const memoizedValue = useMemo(() => computeExpensive(a, b), [a, b]);
```

```jac
# JAC-Client - useCallback
let memoizedCallback = useCallback(
    lambda -> None { doSomething(a, b); },
    [a, b]
);

# JAC-Client - useMemo
let memoizedValue = useMemo(
    lambda -> any { return computeExpensive(a, b); },
    [a, b]
);
```

---

### Array Methods (.map, .filter)

**Important:** For `.map()` and `.filter()`, JAC-Client works best with helper functions:

```javascript
// React
const names = users.map((user) => user.name);
const adults = users.filter((user) => user.age >= 18);
const listItems = items.map((item) => <li key={item.id}>{item.name}</li>);
```

```jac
# JAC-Client - Define helper functions
def getName(user: dict, index: int) -> any {
    return user["name"];
}

def isAdult(user: dict, index: int) -> any {
    return user["age"] >= 18;
}

def renderItem(item: dict, index: int) -> any {
    return <li key={item["id"]}>{item["name"]}</li>;
}

# Use with array methods
let names = users.map(getName);
let adults = users.filter(isAdult);
let listItems = items.map(renderItem);
```

**Alternative: Inline lambda for .map()**

```jac
# Inline lambda (used in some examples)
{items.map(lambda item: any -> any {
    return <li key={item["id"]}>{item["name"]}</li>;
})}
```

---

### Inline Lambda in JSX (The Common React Pattern)

This is the pattern React developers use most often - rendering lists directly inside JSX without assigning to variables first:

```javascript
// React - Inline .map() in JSX
<div>
  {items.map((item) => (
    <button
      key={item.id}
      style={{
        backgroundColor: selected?.id === item.id ? "#28a745" : "#007bff",
      }}
      onClick={() => handleSelect(item.id, item.name)}
    >
      {item.name}
    </button>
  ))}
</div>
```

```jac
# JAC-Client - Inline .map() in JSX
<div>
    {items.map(lambda item: any -> any {
        let isSelected = selected and selected["id"] == item["id"];
        return (
            <button
                key={item["id"]}
                style={{
                    "backgroundColor": ("#28a745") if isSelected else ("#007bff")
                }}
                onClick={lambda: handleSelect(item["id"], item["name"])}
            >
                {item["name"]}
            </button>
        );
    })}
</div>
```

### Inline .filter().map() Chain

```javascript
// React - Filter then map inline
<div>
  {items
    .filter((item) => item.inStock)
    .map((item) => (
      <span key={item.id}>In Stock: {item.name}</span>
    ))}
</div>
```

```jac
# JAC-Client - Filter then map inline
<div>
    {items.filter(lambda item: any -> any {
        return item["inStock"];
    }).map(lambda item: any -> any {
        return (
            <span key={item["id"]}>In Stock: {item["name"]}</span>
        );
    })}
</div>
```

### Inline .some() for Conditional Rendering

```javascript
// React - Using .some() for conditional UI
{
  items.some((item) => not item.inStock) && <p>Some items are out of stock!</p>;
}
```

```jac
# JAC-Client - Using .some() for conditional UI
{items.some(lambda item: any -> any { return not item["inStock"]; }) and (
    <p>Some items are out of stock!</p>
)}
```

### Inline .every() Check

```javascript
// React
{
  items.every((item) => item.price < 10) && <p>All items under $10</p>;
}
```

```jac
# JAC-Client
{items.every(lambda item: any -> any { return item["price"] < 10; }) and (
    <p>All items under $10</p>
)}
```

### Inline .map() with Index

```javascript
// React - Using index in map
<ol>
  {items.map((item, index) => (
    <li key={item.id}>
      #{index + 1}: {item.name}
    </li>
  ))}
</ol>
```

```jac
# JAC-Client - Using index in map
<ol>
    {items.map(lambda item: any, index: int -> any {
        return (
            <li key={item["id"]}>
                #{index + 1}: {item["name"]}
            </li>
        );
    })}
</ol>
```

---

### Async Functions

**Note:** For async operations, use `async def` instead of lambda:

```javascript
// React
const fetchData = async () => {
  const response = await fetch("/api/data");
  const data = await response.json();
  setData(data);
};
```

```jac
# JAC-Client - Use async def for async functions
async def fetchData() {
    let response = await fetch("/api/data");
    let data = await response.json();
    setData(data);
}

# Call it
onClick={lambda: fetchData()}
```

---

## Quick Conversion Table

| React/JavaScript                           | JAC-Client                                                                |
| ------------------------------------------ | ------------------------------------------------------------------------- |
| `() => {}`                                 | `lambda -> None {}`                                                       |
| `() => value`                              | `lambda: value`                                                           |
| `(x) => x * 2`                             | `lambda x: int -> int { return x * 2; }`                                  |
| `(e) => e.target.value`                    | `lambda e: any -> any { return e.target.value; }`                         |
| `(a, b) => a + b`                          | `lambda a: int, b: int -> int { return a + b; }`                          |
| `onClick={() => fn(x)}`                    | `onClick={lambda: fn(x)}`                                                 |
| **Complex onClick**                        |                                                                           |
| `onClick={() => { a(); b(); }}`            | `onClick={lambda -> None { a(); b(); }}`                                  |
| `onClick={(e) => { e.preventDefault(); }}` | `onClick={lambda e: any -> None { e.preventDefault(); }}`                 |
| `onClick={() => { if(x) a(); }}`           | `onClick={lambda -> None { if x { a(); } }}`                              |
| `arr.map(x => x.name)`                     | Helper function + `arr.map(helperFn)`                                     |
| `async () => {}`                           | `async def funcName() {}`                                                 |
| **Inline JSX map**                         |                                                                           |
| `{items.map(x => <li>{x}</li>)}`           | `{items.map(lambda x: any -> any { return <li>{x}</li>; })}`              |
| `{items.filter(x => x.active).map(...)}`   | `{items.filter(lambda x: any -> any { return x["active"]; }).map(...)}`   |
| `{arr.some(x => x.done) && <p>...</p>}`    | `{arr.some(lambda x: any -> any { return x["done"]; }) and (<p>...</p>)}` |
| `{arr.every(x => x.ok) && <p>...</p>}`     | `{arr.every(lambda x: any -> any { return x["ok"]; }) and (<p>...</p>)}`  |

---

## Key Differences

1. **Type Annotations Required**: JAC-Client requires type annotations for lambda parameters

   - `lambda x: int -> int { ... }` instead of just `x => ...`

2. **Return Type Specified**: The return type comes after `->`

   - `lambda -> None { }` for void
   - `lambda -> int { return 42; }` for int return

3. **Array Methods**: Use helper functions or inline lambdas with full type annotations

   - `.map()`, `.filter()`, etc. need `(item: any, index: int) -> any` signature

4. **Async**: Use `async def funcName()` instead of `async () =>`

5. **Short Syntax**:
   - React: `() => expression`
   - JAC: `lambda: expression`

---

## Tips for React Developers

1. **Think "lambda" instead of "arrow"** - Same concept, different keyword

2. **Always specify types** - JAC-Client is typed, so include `: Type` for parameters and `-> ReturnType` for returns

3. **Use `any` when uncertain** - If you are not sure of the type, `any` works like TypeScript's `any`

4. **Helper functions for clarity** - For `.map()` and `.filter()`, defining separate helper functions often reads better than inline lambdas

5. **`None` = void** - Use `-> None` when the function does not return anything (like React's void arrow functions)

6. **Object syntax** - Use `{ "key": value }` with quoted keys for objects/dicts in JAC-Client
