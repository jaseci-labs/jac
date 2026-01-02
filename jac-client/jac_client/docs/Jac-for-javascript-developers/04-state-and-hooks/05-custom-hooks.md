# Custom Hooks

Learn how to create reusable custom hooks in Jac.

---

## What are Custom Hooks?

Custom hooks are functions that use React hooks to encapsulate reusable logic. They start with `use` and can call other hooks.

---

## Basic Custom Hook

### JavaScript/React

```javascript
function useCounter(initialValue = 0) {
  const [count, setCount] = useState(initialValue);

  const increment = () => setCount(count + 1);
  const decrement = () => setCount(count - 1);
  const reset = () => setCount(initialValue);

  return { count, increment, decrement, reset };
}
```

### Jac

```jac
def useCounter(initialValue: int = 0) -> dict {
    [count, setCount] = useState(initialValue);

    def increment() -> None {
        setCount(count + 1);
    }

    def decrement() -> None {
        setCount(count - 1);
    }

    def reset() -> None {
        setCount(initialValue);
    }

    return {
        "count": count,
        "increment": increment,
        "decrement": decrement,
        "reset": reset
    };
}

# Usage
def Counter() -> any {
    counter = useCounter(0);

    return (
        <div>
            <p>Count: {counter["count"]}</p>
            <button onClick={lambda: counter["increment"]()}>+</button>
            <button onClick={lambda: counter["decrement"]()}>-</button>
            <button onClick={lambda: counter["reset"]()}>Reset</button>
        </div>
    );
}
```

---

## Common Custom Hooks

### useToggle

```jac
def useToggle(initialValue: bool = False) -> dict {
    [value, setValue] = useState(initialValue);

    def toggle() -> None {
        setValue(not value);
    }

    def setTrue() -> None {
        setValue(True);
    }

    def setFalse() -> None {
        setValue(False);
    }

    return {
        "value": value,
        "toggle": toggle,
        "setTrue": setTrue,
        "setFalse": setFalse
    };
}

# Usage
def Modal() -> any {
    modal = useToggle(False);

    return (
        <div>
            <button onClick={lambda: modal["toggle"]()}>Toggle Modal</button>
            {modal["value"] and (
                <div className="modal">
                    <p>Modal Content</p>
                    <button onClick={lambda: modal["setFalse"]()}>Close</button>
                </div>
            )}
        </div>
    );
}
```

### useInput

```jac
def useInput(initialValue: str = "") -> dict {
    [value, setValue] = useState(initialValue);

    def onChange(e: any) -> None {
        setValue(e.target.value);
    }

    def reset() -> None {
        setValue(initialValue);
    }

    def clear() -> None {
        setValue("");
    }

    return {
        "value": value,
        "onChange": onChange,
        "reset": reset,
        "clear": clear,
        "setValue": setValue
    };
}

# Usage
def Form() -> any {
    name = useInput("");
    email = useInput("");

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        console.log("Name:", name["value"], "Email:", email["value"]);
        name["reset"]();
        email["reset"]();
    }

    return (
        <form onSubmit={handleSubmit}>
            <input
                value={name["value"]}
                onChange={name["onChange"]}
                placeholder="Name"
            />
            <input
                value={email["value"]}
                onChange={email["onChange"]}
                placeholder="Email"
            />
            <button type="submit">Submit</button>
        </form>
    );
}
```

### useLocalStorage

```jac
def useLocalStorage(key: str, initialValue: any) -> dict {
    # Get from localStorage or use initial
    [storedValue, setStoredValue] = useState(lambda -> any {
        try {
            item = localStorage.getItem(key);
            return (JSON.parse(item)) if item else (initialValue);
        } except {
            return initialValue;
        }
    });

    def setValue(value: any) -> None {
        try {
            setStoredValue(value);
            localStorage.setItem(key, JSON.stringify(value));
        } except {
            console.log("Error saving to localStorage");
        }
    }

    def removeValue() -> None {
        setStoredValue(initialValue);
        localStorage.removeItem(key);
    }

    return {
        "value": storedValue,
        "setValue": setValue,
        "removeValue": removeValue
    };
}

# Usage
def Settings() -> any {
    theme = useLocalStorage("theme", "light");
    fontSize = useLocalStorage("fontSize", 16);

    return (
        <div>
            <select
                value={theme["value"]}
                onChange={lambda e: any -> None { theme["setValue"](e.target.value); }}
            >
                <option value="light">Light</option>
                <option value="dark">Dark</option>
            </select>

            <input
                type="number"
                value={fontSize["value"]}
                onChange={lambda e: any -> None { fontSize["setValue"](parseInt(e.target.value)); }}
            />
        </div>
    );
}
```

### useFetch

```jac
def useFetch(url: str) -> dict {
    [data, setData] = useState(None);
    [loading, setLoading] = useState(True);
    [error, setError] = useState(None);

    useEffect(lambda -> None {
        async def fetchData() {
            setLoading(True);
            setError(None);

            try {
                response = await fetch(url);
                if not response.ok {
                    setError("Failed to fetch");
                    return;
                }
                result = await response.json();
                setData(result);
            } except {
                setError("Error fetching data");
            } finally {
                setLoading(False);
            }
        }

        fetchData();
    }, [url]);

    def refetch() -> None {
        setLoading(True);
        # Trigger useEffect by changing a dependency
    }

    return {
        "data": data,
        "loading": loading,
        "error": error,
        "refetch": refetch
    };
}

# Usage
def UserList() -> any {
    users = useFetch("/api/users");

    if users["loading"] {
        return <p>Loading...</p>;
    }

    if users["error"] {
        return <p>Error: {users["error"]}</p>;
    }

    return (
        <ul>
            {users["data"].map(lambda user: dict, i: int -> any {
                return <li key={user["id"]}>{user["name"]}</li>;
            })}
        </ul>
    );
}
```

### useDebounce

```jac
def useDebounce(value: any, delay: int = 500) -> any {
    [debouncedValue, setDebouncedValue] = useState(value);

    useEffect(lambda -> None {
        timer = setTimeout(lambda -> None {
            setDebouncedValue(value);
        }, delay);

        return lambda -> None {
            clearTimeout(timer);
        };
    }, [value, delay]);

    return debouncedValue;
}

# Usage
def Search() -> any {
    [query, setQuery] = useState("");
    debouncedQuery = useDebounce(query, 300);
    [results, setResults] = useState([]);

    useEffect(lambda -> None {
        if debouncedQuery.trim() == "" {
            setResults([]);
            return lambda -> None {};
        }

        async def search() {
            response = await fetch("/api/search?q=" + debouncedQuery);
            data = await response.json();
            setResults(data);
        }

        search();
    }, [debouncedQuery]);

    return (
        <div>
            <input
                value={query}
                onChange={lambda e: any -> None { setQuery(e.target.value); }}
                placeholder="Search..."
            />
            <ul>
                {results.map(lambda item: any, i: int -> any {
                    return <li key={i}>{item}</li>;
                })}
            </ul>
        </div>
    );
}
```

### useWindowSize

```jac
def useWindowSize() -> dict {
    [size, setSize] = useState({
        "width": window.innerWidth,
        "height": window.innerHeight
    });

    useEffect(lambda -> None {
        def handleResize() -> None {
            setSize({
                "width": window.innerWidth,
                "height": window.innerHeight
            });
        }

        window.addEventListener("resize", handleResize);

        return lambda -> None {
            window.removeEventListener("resize", handleResize);
        };
    }, []);

    return size;
}

# Usage
def ResponsiveComponent() -> any {
    windowSize = useWindowSize();
    isMobile = windowSize["width"] < 768;

    return (
        <div>
            <p>Window: {windowSize["width"]} x {windowSize["height"]}</p>
            {(isMobile) and <p>Mobile view</p>}
            {(not isMobile) and <p>Desktop view</p>}
        </div>
    );
}
```

---

## Organizing Custom Hooks

### Separate File

**hooks/useCounter.jac:**

```jac
cl import from react { useState }

cl {
    def:pub useCounter(initialValue: int = 0) -> dict {
        [count, setCount] = useState(initialValue);

        def increment() -> None { setCount(count + 1); }
        def decrement() -> None { setCount(count - 1); }
        def reset() -> None { setCount(initialValue); }

        return {
            "count": count,
            "increment": increment,
            "decrement": decrement,
            "reset": reset
        };
    }
}
```

**app.jac:**

```jac
cl import from ./hooks/useCounter { useCounter }

cl {
    def app() -> any {
        counter = useCounter(0);
        return <p>{counter["count"]}</p>;
    }
}
```

---

## Rules of Custom Hooks

1. **Name starts with `use`** - Convention for hooks
2. **Call hooks at top level** - Not inside conditions or loops
3. **Call from React functions** - Components or other hooks only

---

## Summary

| Hook            | Purpose                          |
| --------------- | -------------------------------- |
| useCounter      | Counter with increment/decrement |
| useToggle       | Boolean toggle                   |
| useInput        | Form input state                 |
| useLocalStorage | Persist to localStorage          |
| useFetch        | Data fetching                    |
| useDebounce     | Debounced value                  |
| useWindowSize   | Window dimensions                |

---

## Next Section

- [Event Handling](../05-event-handling/) - Click, form, keyboard events
