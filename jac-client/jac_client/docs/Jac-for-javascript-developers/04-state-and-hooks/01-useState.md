# useState Hook

Learn how to manage component state in JAC-Client.

---

## Basic Syntax

### JavaScript/React vs JAC-Client

**JavaScript/React:**

```javascript
const [count, setCount] = useState(0);
const [name, setName] = useState("");
```

**JAC-Client:**

```jac
[count, setCount] = useState(0);
[name, setName] = useState("");
```

**Key Difference:** No `const` or `let` keyword needed.

---

## Import useState

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
}
```

---

## Different State Types

### Numbers

```jac
[count, setCount] = useState(0);
[price, setPrice] = useState(19.99);
[quantity, setQuantity] = useState(1);
```

### Strings

```jac
[name, setName] = useState("");
[email, setEmail] = useState("");
[message, setMessage] = useState("Hello");
```

### Booleans

```jac
[isOpen, setIsOpen] = useState(False);
[isLoading, setIsLoading] = useState(False);
[isActive, setIsActive] = useState(True);
```

### Arrays

```jac
[items, setItems] = useState([]);
[users, setUsers] = useState([]);
[todos, setTodos] = useState([
    { "id": 1, "text": "Learn JAC" }
]);
```

### Objects

```jac
[user, setUser] = useState(None);
[form, setForm] = useState({ "name": "", "email": "" });
[settings, setSettings] = useState({
    "theme": "dark",
    "notifications": True
});
```

---

## Updating State

### Simple Updates

```jac
# Number
setCount(count + 1);
setCount(0);

# String
setName("John");
setName("");

# Boolean
setIsOpen(True);
setIsOpen(not isOpen);  # Toggle
```

### Array Updates

```jac
# Add item
setItems(items.concat([newItem]));

# Remove item (filter)
setItems(items.filter(lambda item: dict -> bool {
    return item["id"] != idToRemove;
}));

# Update item (map)
def updateItem(item: dict, index: int) -> dict {
    if item["id"] == targetId {
        return { **item, "done": True };
    }
    return item;
}
setItems(items.map(updateItem));
```

### Object Updates

```jac
# Update single property
setUser({ **user, "name": "New Name" });

# Update multiple properties
setForm({
    **form,
    "name": "John",
    "email": "john@example.com"
});

# Reset object
setForm({ "name": "", "email": "" });
```

---

## Multiple State Variables

```jac
def Form() -> any {
    [name, setName] = useState("");
    [email, setEmail] = useState("");
    [password, setPassword] = useState("");
    [errors, setErrors] = useState({});
    [isSubmitting, setIsSubmitting] = useState(False);

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        setIsSubmitting(True);
        # Process form...
    }

    return (
        <form onSubmit={handleSubmit}>
            <input
                value={name}
                onChange={lambda e: any -> None { setName(e.target.value); }}
                placeholder="Name"
            />
            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
                placeholder="Email"
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { setPassword(e.target.value); }}
                placeholder="Password"
            />
            <button type="submit" disabled={isSubmitting}>
                {("Submitting...") if isSubmitting else ("Submit")}
            </button>
        </form>
    );
}
```

---

## State with Objects (Form Pattern)

```jac
def ContactForm() -> any {
    [formData, setFormData] = useState({
        "name": "",
        "email": "",
        "message": ""
    });

    def handleChange(field: str, value: str) -> None {
        setFormData({ **formData, field: value });
    }

    return (
        <form>
            <input
                value={formData["name"]}
                onChange={lambda e: any -> None {
                    setFormData({ **formData, "name": e.target.value });
                }}
                placeholder="Name"
            />
            <input
                value={formData["email"]}
                onChange={lambda e: any -> None {
                    setFormData({ **formData, "email": e.target.value });
                }}
                placeholder="Email"
            />
            <textarea
                value={formData["message"]}
                onChange={lambda e: any -> None {
                    setFormData({ **formData, "message": e.target.value });
                }}
                placeholder="Message"
            />
        </form>
    );
}
```

---

## Common Patterns

### Toggle State

```jac
def Toggle() -> any {
    [isOn, setIsOn] = useState(False);

    return (
        <button onClick={lambda: setIsOn(not isOn)}>
            {("ON") if isOn else ("OFF")}
        </button>
    );
}
```

### Counter

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    return (
        <div>
            <button onClick={lambda: setCount(count - 1)}>-</button>
            <span>{count}</span>
            <button onClick={lambda: setCount(count + 1)}>+</button>
            <button onClick={lambda: setCount(0)}>Reset</button>
        </div>
    );
}
```

### Todo List

```jac
def TodoList() -> any {
    [todos, setTodos] = useState([]);
    [input, setInput] = useState("");

    def addTodo() -> None {
        if input.trim() != "" {
            newTodo = {
                "id": Date.now(),
                "text": input,
                "done": False
            };
            setTodos(todos.concat([newTodo]));
            setInput("");
        }
    }

    def toggleTodo(id: int) -> None {
        def toggle(todo: dict, index: int) -> dict {
            if todo["id"] == id {
                return { **todo, "done": not todo["done"] };
            }
            return todo;
        }
        setTodos(todos.map(toggle));
    }

    def deleteTodo(id: int) -> None {
        setTodos(todos.filter(lambda t: dict -> bool {
            return t["id"] != id;
        }));
    }

    def renderTodo(todo: dict, index: int) -> any {
        return (
            <li key={todo["id"]}>
                <span
                    style={{ "textDecoration": ("line-through") if todo["done"] else ("none") }}
                    onClick={lambda: toggleTodo(todo["id"])}
                >
                    {todo["text"]}
                </span>
                <button onClick={lambda: deleteTodo(todo["id"])}>Delete</button>
            </li>
        );
    }

    return (
        <div>
            <input
                value={input}
                onChange={lambda e: any -> None { setInput(e.target.value); }}
                placeholder="Add todo..."
            />
            <button onClick={lambda: addTodo()}>Add</button>
            <ul>{todos.map(renderTodo)}</ul>
        </div>
    );
}
```

---

## Lifting State Up

```jac
def Parent() -> any {
    [count, setCount] = useState(0);

    return (
        <div>
            <Display count={count} />
            <Controls
                onIncrement={lambda: setCount(count + 1)}
                onDecrement={lambda: setCount(count - 1)}
            />
        </div>
    );
}

def Display(count: int) -> any {
    return <h1>Count: {count}</h1>;
}

def Controls(onIncrement: any, onDecrement: any) -> any {
    return (
        <div>
            <button onClick={onDecrement}>-</button>
            <button onClick={onIncrement}>+</button>
        </div>
    );
}
```

---

## Summary

| Pattern | JavaScript | JAC-Client |
|---------|-----------|------------|
| Declare state | `const [x, setX] = useState(0)` | `[x, setX] = useState(0)` |
| Update state | `setX(newValue)` | `setX(newValue)` |
| Toggle | `setX(!x)` | `setX(not x)` |
| Add to array | `setArr([...arr, item])` | `setArr(arr.concat([item]))` |
| Update object | `setObj({...obj, key: val})` | `setObj({ **obj, "key": val })` |
| Initial boolean | `useState(false)` | `useState(False)` |

---

## Next

- [useEffect](02-useEffect.md) - Side effects and lifecycle
