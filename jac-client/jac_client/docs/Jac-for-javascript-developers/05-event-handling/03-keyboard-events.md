# Keyboard Events

Learn how to handle keyboard events in Jac.

---

## Basic Keyboard Events

### onKeyDown, onKeyUp, onKeyPress

```jac
def KeyboardDemo() -> any {
    [lastKey, setLastKey] = useState("");

    return (
        <input
            onKeyDown={lambda e: any -> None { setLastKey("Down: " + e.key); }}
            onKeyUp={lambda e: any -> None { setLastKey("Up: " + e.key); }}
            placeholder="Press any key"
        />
    );
}
```

---

## Check Specific Keys

### Enter Key

```jac
def EnterSubmit() -> any {
    [value, setValue] = useState("");
    [submitted, setSubmitted] = useState([]);

    def handleKeyDown(e: any) -> None {
        if e.key == "Enter" {
            if value.trim() != "" {
                setSubmitted(submitted.concat([value]));
                setValue("");
            }
        }
    }

    return (
        <div>
            <input
                value={value}
                onChange={lambda e: any -> None { setValue(e.target.value); }}
                onKeyDown={lambda e: any -> None { handleKeyDown(e); }}
                placeholder="Press Enter to add"
            />
            <ul>
                {submitted.map(lambda item: str, i: int -> any {
                    return <li key={i}>{item}</li>;
                })}
            </ul>
        </div>
    );
}
```

### Escape Key

```jac
def EscapeClose() -> any {
    [isOpen, setIsOpen] = useState(False);

    def handleKeyDown(e: any) -> None {
        if e.key == "Escape" {
            setIsOpen(False);
        }
    }

    return (
        <div onKeyDown={lambda e: any -> None { handleKeyDown(e); }} tabIndex={0}>
            <button onClick={lambda: setIsOpen(True)}>Open Modal</button>
            {isOpen and (
                <div style={{
                    "position": "fixed",
                    "top": "50%",
                    "left": "50%",
                    "transform": "translate(-50%, -50%)",
                    "backgroundColor": "white",
                    "padding": "20px",
                    "boxShadow": "0 2px 10px rgba(0,0,0,0.3)"
                }}>
                    <p>Press Escape to close</p>
                    <button onClick={lambda: setIsOpen(False)}>Close</button>
                </div>
            )}
        </div>
    );
}
```

### Arrow Keys

```jac
def ArrowNavigation() -> any {
    [position, setPosition] = useState({ "x": 50, "y": 50 });

    def handleKeyDown(e: any) -> None {
        step = 10;

        if e.key == "ArrowUp" {
            setPosition({ **position, "y": position["y"] - step });
        } elif e.key == "ArrowDown" {
            setPosition({ **position, "y": position["y"] + step });
        } elif e.key == "ArrowLeft" {
            setPosition({ **position, "x": position["x"] - step });
        } elif e.key == "ArrowRight" {
            setPosition({ **position, "x": position["x"] + step });
        }
    }

    return (
        <div
            onKeyDown={lambda e: any -> None { handleKeyDown(e); }}
            tabIndex={0}
            style={{ "outline": "none" }}
        >
            <p>Use arrow keys to move (click here first to focus)</p>
            <div
                style={{
                    "position": "relative",
                    "width": "200px",
                    "height": "200px",
                    "border": "1px solid black"
                }}
            >
                <div
                    style={{
                        "position": "absolute",
                        "left": position["x"].toString() + "px",
                        "top": position["y"].toString() + "px",
                        "width": "20px",
                        "height": "20px",
                        "backgroundColor": "red",
                        "borderRadius": "50%"
                    }}
                />
            </div>
        </div>
    );
}
```

---

## Modifier Keys

### Ctrl, Shift, Alt

```jac
def ModifierKeys() -> any {
    [lastAction, setLastAction] = useState("");

    def handleKeyDown(e: any) -> None {
        if e.ctrlKey and e.key == "s" {
            e.preventDefault();
            setLastAction("Ctrl+S: Save");
        } elif e.ctrlKey and e.key == "z" {
            e.preventDefault();
            setLastAction("Ctrl+Z: Undo");
        } elif e.shiftKey and e.key == "Enter" {
            setLastAction("Shift+Enter: New line");
        } elif e.altKey and e.key == "h" {
            setLastAction("Alt+H: Help");
        }
    }

    return (
        <div
            onKeyDown={lambda e: any -> None { handleKeyDown(e); }}
            tabIndex={0}
            style={{ "padding": "20px", "border": "1px solid #ccc" }}
        >
            <p>Try keyboard shortcuts:</p>
            <ul>
                <li>Ctrl+S - Save</li>
                <li>Ctrl+Z - Undo</li>
                <li>Shift+Enter - New line</li>
                <li>Alt+H - Help</li>
            </ul>
            <p>Last action: {lastAction or "None"}</p>
        </div>
    );
}
```

---

## Input with Keyboard Navigation

```jac
def SearchWithSuggestions() -> any {
    [query, setQuery] = useState("");
    [selectedIndex, setSelectedIndex] = useState(-1);

    suggestions = ["Apple", "Banana", "Cherry", "Date", "Elderberry"];

    filtered = suggestions.filter(lambda s: str -> bool {
        return s.toLowerCase().includes(query.toLowerCase());
    });

    def handleKeyDown(e: any) -> None {
        if e.key == "ArrowDown" {
            e.preventDefault();
            if selectedIndex < filtered.length - 1 {
                setSelectedIndex(selectedIndex + 1);
            }
        } elif e.key == "ArrowUp" {
            e.preventDefault();
            if selectedIndex > 0 {
                setSelectedIndex(selectedIndex - 1);
            }
        } elif e.key == "Enter" and selectedIndex >= 0 {
            setQuery(filtered[selectedIndex]);
            setSelectedIndex(-1);
        } elif e.key == "Escape" {
            setSelectedIndex(-1);
        }
    }

    return (
        <div>
            <input
                value={query}
                onChange={lambda e: any -> None {
                    setQuery(e.target.value);
                    setSelectedIndex(-1);
                }}
                onKeyDown={lambda e: any -> None { handleKeyDown(e); }}
                placeholder="Search..."
            />
            {query and filtered.length > 0 and (
                <ul style={{
                    "listStyle": "none",
                    "padding": "0",
                    "margin": "0",
                    "border": "1px solid #ccc"
                }}>
                    {filtered.map(lambda item: str, index: int -> any {
                        isSelected = index == selectedIndex;
                        return (
                            <li
                                key={index}
                                style={{
                                    "padding": "10px",
                                    "backgroundColor": ("#e0e0e0") if isSelected else ("white"),
                                    "cursor": "pointer"
                                }}
                                onClick={lambda: setQuery(item)}
                            >
                                {item}
                            </li>
                        );
                    })}
                </ul>
            )}
        </div>
    );
}
```

---

## Global Key Listener

Using useEffect to listen globally:

```jac
def GlobalKeyListener() -> any {
    [pressedKeys, setPressedKeys] = useState([]);

    useEffect(lambda -> None {
        def handleKeyDown(e: any) -> None {
            if not (e.key in pressedKeys) {
                setPressedKeys(pressedKeys.concat([e.key]));
            }
        }

        def handleKeyUp(e: any) -> None {
            setPressedKeys(pressedKeys.filter(lambda k: str -> bool {
                return k != e.key;
            }));
        }

        window.addEventListener("keydown", handleKeyDown);
        window.addEventListener("keyup", handleKeyUp);

        return lambda -> None {
            window.removeEventListener("keydown", handleKeyDown);
            window.removeEventListener("keyup", handleKeyUp);
        };
    }, [pressedKeys]);

    return (
        <div>
            <p>Currently pressed: {pressedKeys.join(", ") or "None"}</p>
        </div>
    );
}
```

---

## Common Key Codes

| Key         | e.key Value    |
| ----------- | -------------- |
| Enter       | `"Enter"`      |
| Escape      | `"Escape"`     |
| Space       | `" "`          |
| Tab         | `"Tab"`        |
| Backspace   | `"Backspace"`  |
| Delete      | `"Delete"`     |
| Arrow Up    | `"ArrowUp"`    |
| Arrow Down  | `"ArrowDown"`  |
| Arrow Left  | `"ArrowLeft"`  |
| Arrow Right | `"ArrowRight"` |

---

## Summary

| Pattern         | Syntax                                                |
| --------------- | ----------------------------------------------------- |
| Key down        | `onKeyDown={lambda e: any -> None { handleKey(e); }}` |
| Key up          | `onKeyUp={lambda e: any -> None { handleKey(e); }}`   |
| Check key       | `if e.key == "Enter" { }`                             |
| Modifier        | `if e.ctrlKey and e.key == "s" { }`                   |
| Prevent default | `e.preventDefault()`                                  |

---

## Next Section

- [Conditional Rendering](../06-conditional-rendering/01-if-else.md) - if/else, ternary, and/or
