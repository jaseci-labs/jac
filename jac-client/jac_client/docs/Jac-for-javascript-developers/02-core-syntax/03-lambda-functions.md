# Lambda Functions

This is the **most important syntax difference** from JavaScript. Master lambdas and you've mastered Jac.

---

## Quick Reference

| Pattern           | JavaScript     | Jac                                      |
| ----------------- | -------------- | ---------------------------------------- |
| No params         | `() => {}`     | `lambda -> None {}`                      |
| No params (short) | `() => doIt()` | `lambda: doIt()`                         |
| One param         | `(x) => {}`    | `lambda x: any -> None {}`               |
| Two params        | `(a, b) => {}` | `lambda a: any, b: any -> None {}`       |
| With return       | `(x) => x * 2` | `lambda x: int -> int { return x * 2; }` |
| Event handler     | `(e) => {}`    | `lambda e: any -> None {}`               |

---

## Short Form: `lambda: expression`

For single expressions, use the short form:

=== "JavaScript"

    ```javascript
    onClick={() => setCount(count + 1)}
    onClick={() => console.log("clicked")}
    onClick={() => handleClick()}
    ```

=== "Jac"

    ```jac
    onClick={lambda: setCount(count + 1)}
    onClick={lambda: console.log("clicked")}
    onClick={lambda: handleClick()}
    ```

This is the **most common pattern** you'll use.

---

## Full Form: `lambda -> Type { }`

For multiple statements, use the full form:

=== "JavaScript"

    ```javascript
    onClick={() => {
      setCount(count + 1);
      console.log("incremented");
      trackEvent("click");
    }}
    ```

=== "Jac"

    ```jac
    onClick={lambda -> None {
        setCount(count + 1);
        console.log("incremented");
        trackEvent("click");
    }}
    ```

---

## With Parameters

### Single Parameter

=== "JavaScript"

    ```javascript
    onChange={(e) => setName(e.target.value)}
    onSelect={(id) => selectItem(id)}
    ```

=== "Jac"

    ```jac
    onChange={lambda e: any -> None { setName(e.target.value); }}
    onSelect={lambda id: int -> None { selectItem(id); }}
    ```

### Multiple Parameters

=== "JavaScript"

    ```javascript
    onDrag={(x, y) => setPosition(x, y)}
    calculate((a, b) => a + b)
    ```

=== "Jac"

    ```jac
    onDrag={lambda x: int, y: int -> None { setPosition(x, y); }}
    calculate(lambda a: int, b: int -> int { return a + b; })
    ```

---

## With Return Values

### For Array Methods

=== "JavaScript"

    ```javascript
    numbers.map((n) => n * 2);
    numbers.filter((n) => n > 0);
    numbers.find((n) => n === target);
    ```

=== "Jac"

    ```jac
    # Option 1: Use helper function (recommended)
    def double(n: int, index: int) -> int {
        return n * 2;
    }
    numbers.map(double)

    # Option 2: Inline lambda
    numbers.filter(lambda n: int -> bool { return n > 0; })
    numbers.find(lambda n: int -> bool { return n == target; })
    ```

**Important:** For `map`, the callback receives `(item, index)` - both parameters are required.

---

## Common Patterns

### Event Handlers

```jac
# Click - no event object needed
<button onClick={lambda: handleClick()}>Click</button>

# Click - with event object
<button onClick={lambda e: any -> None {
    e.preventDefault();
    handleClick();
}}>Click</button>

# Change - need event object for value
<input onChange={lambda e: any -> None {
    setName(e.target.value);
}} />

# Submit - prevent default
<form onSubmit={lambda e: any -> None {
    e.preventDefault();
    handleSubmit();
}}>
```

### Passing Parameters to Handlers

```jac
# JavaScript: onClick={() => selectItem(id)}
<button onClick={lambda: selectItem(item["id"])}>
    Select
</button>

# JavaScript: onClick={() => deleteItem(item.id, item.name)}
<button onClick={lambda: deleteItem(item["id"], item["name"])}>
    Delete
</button>
```

### State Updates

```jac
# Simple update
<button onClick={lambda: setCount(count + 1)}>+</button>

# Toggle boolean
<button onClick={lambda: setIsOpen(not isOpen)}>Toggle</button>

# Update object
<button onClick={lambda: setUser({ **user, "name": "New Name" })}>
    Update
</button>

# Add to array
<button onClick={lambda: setItems(items.concat([newItem]))}>
    Add
</button>
```

---

## useEffect with Lambda

```jac
# On mount
useEffect(lambda -> None {
    console.log("Mounted");
}, []);

# On dependency change
useEffect(lambda -> None {
    console.log("Count changed:", count);
}, [count]);

# With cleanup
useEffect(lambda -> None {
    timer = setInterval(lambda -> None { tick(); }, 1000);
    return lambda -> None { clearInterval(timer); };
}, []);
```

---

## useCallback with Lambda

```jac
handleClick = useCallback(
    lambda -> None { setCount(count + 1); },
    [count]
);

handleChange = useCallback(
    lambda e: any -> None { setName(e.target.value); },
    []
);
```

---

## useMemo with Lambda

```jac
expensiveValue = useMemo(
    lambda -> int { return count * 100; },
    [count]
);

filteredItems = useMemo(
    lambda -> list {
        return items.filter(lambda item: dict -> bool {
            return item["active"];
        });
    },
    [items]
);
```

---

## Array Methods with Lambda

### map

```jac
# Recommended: Use helper function
def renderItem(item: dict, index: int) -> any {
    return <li key={index}>{item["name"]}</li>;
}
items.map(renderItem)

# Inline (works but verbose)
items.map(lambda item: dict, index: int -> any {
    return <li key={index}>{item["name"]}</li>;
})
```

### filter

```jac
# Filter active users
activeUsers = users.filter(lambda user: dict -> bool {
    return user["active"];
});

# Filter by condition
adults = users.filter(lambda user: dict -> bool {
    return user["age"] >= 18;
});
```

### find

```jac
user = users.find(lambda u: dict -> bool {
    return u["id"] == targetId;
});
```

### some & every

```jac
# Some match
hasErrors = items.some(lambda item: dict -> bool {
    return item["error"] != None;
});

# All match
allComplete = items.every(lambda item: dict -> bool {
    return item["complete"];
});
```

### reduce

```jac
total = prices.reduce(
    lambda acc: float, price: float -> float {
        return acc + price;
    },
    0
);
```

---

## Complex Inline onClick

```jac
# Multiple actions
<button onClick={lambda -> None {
    setCount(count + 1);
    setLog("Clicked at: " + Date().toLocaleTimeString());
    console.log("Button clicked!");
}}>
    Multi-Action
</button>

# Conditional logic
<button onClick={lambda -> None {
    if isValid {
        submitForm();
    } else {
        showError("Please fix errors");
    }
}}>
    Submit
</button>

# With if-elif-else
<button onClick={lambda -> None {
    if count > 10 {
        setMessage("Too high!");
    } elif count < 0 {
        setMessage("Too low!");
    } else {
        setMessage("Just right");
    }
}}>
    Check
</button>
```

---

## Assigning Lambda to Variables

```jac
# Assign to variable
showMessage = lambda -> None {
    setMessage("Hello!");
};

# Use later
<button onClick={showMessage}>Show</button>

# With parameters
doubleNumber = lambda n: int -> None {
    setResult(n * 2);
};

<button onClick={lambda: doubleNumber(5)}>Double 5</button>
```

---

## Common Mistakes

### Mistake 1: Forgetting Return Type

```jac
# WRONG
lambda -> { doSomething(); }

# CORRECT
lambda -> None { doSomething(); }
```

### Mistake 2: Using `=>` Instead of Lambda

```jac
# WRONG (JavaScript syntax)
onClick={() => setCount(count + 1)}

# CORRECT
onClick={lambda: setCount(count + 1)}
```

### Mistake 3: Missing Parameter Types

```jac
# WRONG
lambda e { setName(e.target.value); }

# CORRECT
lambda e: any -> None { setName(e.target.value); }
```

### Mistake 4: Wrong Short Form Syntax

```jac
# WRONG
lambda: { doSomething(); }

# CORRECT (short form - single expression only)
lambda: doSomething()

# CORRECT (full form - multiple statements)
lambda -> None { doSomething(); }
```

---

## Summary

| Use Case            | Syntax                                         |
| ------------------- | ---------------------------------------------- |
| Simple click        | `lambda: handler()`                            |
| With event          | `lambda e: any -> None { ... }`                |
| Multiple statements | `lambda -> None { a(); b(); }`                 |
| Return value        | `lambda x: int -> int { return x * 2; }`       |
| Map callback        | `def fn(item: any, index: int) -> any { ... }` |
| Filter callback     | `lambda x: any -> bool { return condition; }`  |

---

## Next

- [Operators](./04-operators.md) - and/or/not and comparisons
