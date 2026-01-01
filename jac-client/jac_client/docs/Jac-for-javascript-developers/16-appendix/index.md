# Appendix

Quick reference and migration guide.

---

## Complete Syntax Reference

| JavaScript | JAC-Client |
|------------|------------|
| `const x = 5` | `x = 5` |
| `let x = 5` | `x = 5` |
| `true/false/null` | `True/False/None` |
| `&&/\|\|/!` | `and/or/not` |
| `===` | `==` |
| `function name() {}` | `def name() -> type {}` |
| `(x) => x * 2` | `lambda x: int -> int { return x * 2; }` |
| `() => doThing()` | `lambda: doThing()` |
| `// comment` | `# comment` |
| `condition ? a : b` | `(a) if condition else (b)` |
| `try/catch` | `try/except` |
| `throw new Error()` | `raise Exception()` |
| `import { x } from 'y'` | `cl import from y { x }` |
| `export const x` | `glob:pub x = value` |
| `export function` | `def:pub` |
| Direct params | `def Comp(name: str, age: int)` |
| Props access | `name` or `props.name` (both work) |
| `{ key: value }` | `{"key": value}` |
| `for (let i=0; i<5; i++)` | `for i=0 to i<5 by i+=1 {}` |
| `for (item of items)` | `for item in items {}` |

---

## Common Gotchas

### 1. Ternary is Python-Style

```jac
# WRONG
result = isTrue ? "yes" : "no";

# CORRECT
result = ("yes") if isTrue else ("no");
```

### 2. Object Keys Must Be Quoted

```jac
# WRONG
style = { padding: "10px" };

# CORRECT
style = {"padding": "10px"};
```

### 4. Props Are Direct Parameters

```jac
# Modern approach (preferred)
def Button(label: str, onClick: any) -> any {
    return <button onClick={onClick}>{label}</button>;
}

# Can also access via props
def Button(label: str, onClick: any) -> any {
    return <button onClick={props.onClick}>{props.label}</button>;
}
```

### 5. Lambda Needs Type Annotations

```jac
# WRONG
onClick = (e) => handleClick(e);

# CORRECT
onClick = lambda e: any -> None { handleClick(e); };
```

### 6. Booleans Use Capital Letters

```jac
# JavaScript style (works but not idiomatic)
isActive = true;

# JAC-Client style (preferred)
isActive = True;
```

### 7. No range() for Loops

```jac
# WRONG (Python style)
for i in range(5) {}

# CORRECT (JAC style)
for i=0 to i<5 by i+=1 {}
```

---

## Migration Checklist

When converting JavaScript/React to JAC-Client:

- [ ] Change `const/let` to no keyword
- [ ] Change `true/false/null` to `True/False/None`
- [ ] Change `&&/||/!` to `and/or/not`
- [ ] Change `//` comments to `#`
- [ ] Change functions to `def name() -> type {}`
- [ ] Change arrow functions to `lambda`
- [ ] Change ternary `? :` to `(a) if cond else (b)`
- [ ] Change `try/catch` to `try/except`
- [ ] Change imports to `cl import from`
- [ ] Add `:pub` for exports
- [ ] Quote all object keys
- [ ] Use direct parameters: `def Comp(name: str)` not `def Comp(props: dict)`
- [ ] Access props directly or via `props.name` (both work)
- [ ] Use `[x, setX] = useState()` with brackets
- [ ] Change for loops to `for i=0 to i<n by i+=1`

---

## Quick Examples

### Counter Component

```jac
cl import from react { useState }

cl {
    def app() -> any {
        [count, setCount] = useState(0);

        return (
            <div>
                <p>Count: {count}</p>
                <button onClick={lambda: setCount(count + 1)}>+</button>
                <button onClick={lambda: setCount(count - 1)}>-</button>
            </div>
        );
    }
}
```

### Todo List

```jac
cl import from react { useState }

cl {
    def app() -> any {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");

        def addTodo() -> None {
            if input != "" {
                setTodos(todos.concat([{"id": Date.now(), "text": input}]));
                setInput("");
            }
        }

        def removeTodo(id: int) -> None {
            setTodos(todos.filter(lambda t: dict -> bool { return t["id"] != id; }));
        }

        def renderTodo(todo: dict, index: int) -> any {
            return (
                <li key={todo["id"]}>
                    {todo["text"]}
                    <button onClick={lambda: removeTodo(todo["id"])}>X</button>
                </li>
            );
        }

        return (
            <div>
                <input
                    value={input}
                    onChange={lambda e: any -> None { setInput(e.target.value); }}
                />
                <button onClick={addTodo}>Add</button>
                <ul>{todos.map(renderTodo)}</ul>
            </div>
        );
    }
}
```

---

## Resources

- [JAC-Client Examples](../../) - Full working examples
- [01-Introduction](../01-introduction/) - Getting started
- [02-Core Syntax](../02-core-syntax/) - Fundamentals
