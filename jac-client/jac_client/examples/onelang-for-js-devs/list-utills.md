# List Handling in JAC-Client (Onelang)

This guide covers array and list methods with inline lambdas for practical use cases.

> **Full Examples**: See the complete working examples at [jac-client-examples/list-utils](https://github.com/jaseci-labs/jac-client-examples/tree/main/list-utils)

---

## Lambda Syntax in List Methods

```jac
# Basic inline lambda
items.map(lambda item: str -> any { return <li>{item}</li>; })

# With index
items.map(lambda item: str, i: int -> any { return <li key={i}>{item}</li>; })

# Filter with condition
items.filter(lambda n: int -> bool { return n > 5; })
```

---

## Quick Reference

| Method        | Purpose         | Example                                                   |
| ------------- | --------------- | --------------------------------------------------------- |
| `.map()`      | Transform items | `arr.map(lambda x -> any { return x * 2; })`              |
| `.filter()`   | Keep matching   | `arr.filter(lambda x -> bool { return x > 0; })`          |
| `.find()`     | First match     | `arr.find(lambda x -> bool { return x.id == 1; })`        |
| `.some()`     | Any match?      | `arr.some(lambda x -> bool { return x < 0; })`            |
| `.every()`    | All match?      | `arr.every(lambda x -> bool { return x > 0; })`           |
| `.reduce()`   | Aggregate       | `arr.reduce(lambda acc, x -> int { return acc + x; }, 0)` |
| `.sort()`     | Sort items      | `arr.sort(lambda a, b -> int { return a - b; })`          |
| `.concat()`   | Add items       | `arr.concat([newItem])`                                   |
| `.slice()`    | Get portion     | `arr.slice(0, 3)`                                         |
| `.includes()` | Contains?       | `arr.includes("value")`                                   |
| `.indexOf()`  | Find index      | `arr.indexOf("value")`                                    |

---

## Common Patterns

### Render List in JSX

```jac
<ul>
    {items.map(lambda item: str, i: int -> any {
        return <li key={i}>{item}</li>;
    })}
</ul>
```

### Filter and Map Chain

```jac
let activeNames = users
    .filter(lambda u -> bool { return u["active"]; })
    .map(lambda u -> str { return u["name"]; });
```

### Add Item (Immutable)

```jac
setItems(items.concat([newItem]));
```

### Remove Item by Index

```jac
setItems(items.filter(lambda item, i -> bool { return i != indexToRemove; }));
```

### Sum Array

```jac
let total = prices.reduce(lambda acc: float, p: float -> float {
    return acc + p;
}, 0);
```

### Sort Numbers

```jac
# Ascending
arr.sort(lambda a, b -> int { return a - b; });

# Descending
arr.sort(lambda a, b -> int { return b - a; });
```

### Copy Array

```jac
let copy = arr.slice();  # or use spread: [*arr]
```

---

## Running the Example

```bash
cd list-utils
npm install
jac serve app.jac
```

---

## Tips

1. Use `.concat()` instead of `.push()` for immutable updates
2. Always provide `key` prop when mapping in JSX
3. Use `.slice()` to copy arrays before sorting (sort mutates)
4. Chain methods: `.filter().map().slice()`
