# Click Events

Learn how to handle click events in Jac.

---

## Basic Click Handler

### JavaScript/React vs Jac

**JavaScript/React:**

```jsx
<button onClick={() => handleClick()}>Click</button>
<button onClick={handleClick}>Click</button>
```

**Jac:**

```jac
<button onClick={lambda: handleClick()}>Click</button>
```

---

## Simple Click Examples

### Inline Handler

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

### Defined Handler

```jac
def Counter() -> any {
    [count, setCount] = useState(0);

    def handleIncrement() -> None {
        setCount(count + 1);
    }

    return (
        <button onClick={lambda: handleIncrement()}>
            Count: {count}
        </button>
    );
}
```

---

## Multiple Actions

```jac
def MultiAction() -> any {
    [count, setCount] = useState(0);
    [message, setMessage] = useState("");

    return (
        <button onClick={lambda -> None {
            setCount(count + 1);
            setMessage("Button clicked!");
            console.log("Click logged");
        }}>
            Click Me ({count})
        </button>
    );
}
```

---

## Click with Event Object

When you need access to the event:

```jac
def EventDemo() -> any {
    def handleClick(e: any) -> None {
        console.log("Event type:", e.type);
        console.log("Target:", e.target);
        console.log("Coordinates:", e.clientX, e.clientY);
    }

    return (
        <button onClick={lambda e: any -> None { handleClick(e); }}>
            Click for Event Info
        </button>
    );
}
```

---

## Prevent Default

```jac
def LinkButton() -> any {
    def handleClick(e: any) -> None {
        e.preventDefault();
        console.log("Link clicked but navigation prevented");
    }

    return (
        <a href="/other-page" onClick={lambda e: any -> None { handleClick(e); }}>
            Click Me (Won't Navigate)
        </a>
    );
}
```

---

## Passing Parameters

### Passing Values

```jac
def ItemList() -> any {
    items = [
        { "id": 1, "name": "Apple" },
        { "id": 2, "name": "Banana" },
        { "id": 3, "name": "Cherry" }
    ];

    def handleSelect(id: int, name: str) -> None {
        console.log("Selected:", id, name);
    }

    def renderItem(item: dict, index: int) -> any {
        return (
            <button
                key={item["id"]}
                onClick={lambda: handleSelect(item["id"], item["name"])}
            >
                {item["name"]}
            </button>
        );
    }

    return <div>{items.map(renderItem)}</div>;
}
```

### Dynamic Parameters

```jac
def Calculator() -> any {
    [result, setResult] = useState(0);

    def calculate(operation: str, value: int) -> None {
        if operation == "add" {
            setResult(result + value);
        } elif operation == "subtract" {
            setResult(result - value);
        } elif operation == "multiply" {
            setResult(result * value);
        }
    }

    return (
        <div>
            <p>Result: {result}</p>
            <button onClick={lambda: calculate("add", 5)}>+5</button>
            <button onClick={lambda: calculate("subtract", 3)}>-3</button>
            <button onClick={lambda: calculate("multiply", 2)}>×2</button>
            <button onClick={lambda: setResult(0)}>Reset</button>
        </div>
    );
}
```

---

## Toggle Patterns

### Simple Toggle

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

### Show/Hide Content

```jac
def Accordion() -> any {
    [isOpen, setIsOpen] = useState(False);

    return (
        <div>
            <button onClick={lambda: setIsOpen(not isOpen)}>
                {("Hide") if isOpen else ("Show")} Content
            </button>
            {isOpen and (
                <div style={{ "padding": "10px", "border": "1px solid #ccc" }}>
                    Hidden content revealed!
                </div>
            )}
        </div>
    );
}
```

---

## Double Click

```jac
def DoubleClickDemo() -> any {
    [count, setCount] = useState(0);

    return (
        <button onDoubleClick={lambda: setCount(count + 1)}>
            Double-click count: {count}
        </button>
    );
}
```

---

## Mouse Events

```jac
def MouseEvents() -> any {
    [status, setStatus] = useState("Waiting...");

    return (
        <div
            onMouseEnter={lambda: setStatus("Mouse entered")}
            onMouseLeave={lambda: setStatus("Mouse left")}
            onMouseDown={lambda: setStatus("Mouse down")}
            onMouseUp={lambda: setStatus("Mouse up")}
            style={{
                "padding": "50px",
                "backgroundColor": "#f0f0f0",
                "textAlign": "center"
            }}
        >
            <p>{status}</p>
        </div>
    );
}
```

---

## Conditional Handlers

```jac
def ConditionalClick() -> any {
    [isEnabled, setIsEnabled] = useState(True);
    [count, setCount] = useState(0);

    def handleClick() -> None {
        if isEnabled {
            setCount(count + 1);
        }
    }

    return (
        <div>
            <label>
                <input
                    type="checkbox"
                    checked={isEnabled}
                    onChange={lambda: setIsEnabled(not isEnabled)}
                />
                Enable clicks
            </label>
            <button onClick={lambda: handleClick()}>
                Count: {count}
            </button>
        </div>
    );
}
```

---

## Button Disabled State

```jac
def DisabledButton() -> any {
    [isLoading, setIsLoading] = useState(False);

    async def handleClick() {
        setIsLoading(True);
        await setTimeout(lambda -> None {}, 2000);
        setIsLoading(False);
    }

    return (
        <button
            onClick={lambda: handleClick()}
            disabled={isLoading}
        >
            {("Loading...") if isLoading else ("Submit")}
        </button>
    );
}
```

---

## Summary

| Pattern          | Syntax                                       |
| ---------------- | -------------------------------------------- |
| Simple click     | `onClick={lambda: fn()}`                     |
| With event       | `onClick={lambda e: any -> None { fn(e); }}` |
| Multiple actions | `onClick={lambda -> None { a(); b(); }}`     |
| Pass parameter   | `onClick={lambda: fn(value)}`                |
| Toggle           | `onClick={lambda: setState(not state)}`      |
| Prevent default  | `e.preventDefault()`                         |

---

## Next

- [Form Events](02-form-events.md) - onChange, onSubmit
