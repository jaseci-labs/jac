# useRef Hook

Learn how to use references for DOM access and mutable values in JAC-Client.

---

## Basic Syntax

### JavaScript/React vs JAC-Client

**JavaScript/React:**

```javascript
const inputRef = useRef(null);
inputRef.current.focus();
```

**JAC-Client:**

```jac
inputRef = useRef(None);
inputRef.current.focus();
```

---

## Import useRef

```jac
cl import from react { useRef }
```

---

## DOM References

### Focus Input

```jac
cl import from react { useRef }

cl {
    def FocusInput() -> any {
        inputRef = useRef(None);

        def handleClick() -> None {
            inputRef.current.focus();
        }

        return (
            <div>
                <input ref={inputRef} placeholder="Click button to focus" />
                <button onClick={lambda: handleClick()}>Focus Input</button>
            </div>
        );
    }
}
```

### Scroll to Element

```jac
def ScrollDemo() -> any {
    topRef = useRef(None);
    bottomRef = useRef(None);

    def scrollToTop() -> None {
        topRef.current.scrollIntoView({ "behavior": "smooth" });
    }

    def scrollToBottom() -> None {
        bottomRef.current.scrollIntoView({ "behavior": "smooth" });
    }

    return (
        <div>
            <div ref={topRef}>Top of page</div>

            <div style={{ "height": "1000px" }}>
                Long content...
            </div>

            <div ref={bottomRef}>Bottom of page</div>

            <div style={{ "position": "fixed", "bottom": "20px", "right": "20px" }}>
                <button onClick={lambda: scrollToTop()}>Scroll to Top</button>
                <button onClick={lambda: scrollToBottom()}>Scroll to Bottom</button>
            </div>
        </div>
    );
}
```

### Get Input Value

```jac
def UncontrolledForm() -> any {
    nameRef = useRef(None);
    emailRef = useRef(None);

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        name = nameRef.current.value;
        email = emailRef.current.value;
        console.log("Name:", name, "Email:", email);
    }

    return (
        <form onSubmit={handleSubmit}>
            <input ref={nameRef} placeholder="Name" />
            <input ref={emailRef} type="email" placeholder="Email" />
            <button type="submit">Submit</button>
        </form>
    );
}
```

---

## Mutable Values (No Re-render)

useRef can hold any mutable value that persists across renders without causing re-renders.

### Previous Value

```jac
cl import from react { useState, useRef, useEffect }

cl {
    def Counter() -> any {
        [count, setCount] = useState(0);
        prevCountRef = useRef(None);

        useEffect(lambda -> None {
            prevCountRef.current = count;
        }, [count]);

        prevCount = prevCountRef.current;

        return (
            <div>
                <p>Current: {count}</p>
                <p>Previous: {(prevCount) if prevCount != None else ("None")}</p>
                <button onClick={lambda: setCount(count + 1)}>Increment</button>
            </div>
        );
    }
}
```

### Timer ID

```jac
def Timer() -> any {
    [count, setCount] = useState(0);
    [isRunning, setIsRunning] = useState(False);
    timerRef = useRef(None);

    def startTimer() -> None {
        if timerRef.current != None {
            return;  # Already running
        }

        setIsRunning(True);
        timerRef.current = setInterval(lambda -> None {
            setCount(count + 1);
        }, 1000);
    }

    def stopTimer() -> None {
        if timerRef.current != None {
            clearInterval(timerRef.current);
            timerRef.current = None;
            setIsRunning(False);
        }
    }

    def resetTimer() -> None {
        stopTimer();
        setCount(0);
    }

    return (
        <div>
            <p>Time: {count}s</p>
            <button onClick={lambda: startTimer()} disabled={isRunning}>Start</button>
            <button onClick={lambda: stopTimer()} disabled={not isRunning}>Stop</button>
            <button onClick={lambda: resetTimer()}>Reset</button>
        </div>
    );
}
```

### Render Count

```jac
def RenderCounter() -> any {
    [value, setValue] = useState("");
    renderCount = useRef(0);

    # Increment on every render (doesn't cause re-render)
    renderCount.current = renderCount.current + 1;

    return (
        <div>
            <input
                value={value}
                onChange={lambda e: any -> None { setValue(e.target.value); }}
            />
            <p>Render count: {renderCount.current}</p>
        </div>
    );
}
```

---

## Multiple Refs

### Form with Multiple Inputs

```jac
def MultiInputForm() -> any {
    refs = {
        "firstName": useRef(None),
        "lastName": useRef(None),
        "email": useRef(None),
        "phone": useRef(None)
    };

    def focusNext(current: str) -> None {
        order = ["firstName", "lastName", "email", "phone"];

        for i=0 to i<order.length by i+=1 {
            if order[i] == current and i < order.length - 1 {
                refs[order[i + 1]].current.focus();
                return;
            }
        }
    }

    return (
        <form>
            <input
                ref={refs["firstName"]}
                placeholder="First Name"
                onKeyDown={lambda e: any -> None {
                    if e.key == "Enter" {
                        e.preventDefault();
                        focusNext("firstName");
                    }
                }}
            />
            <input
                ref={refs["lastName"]}
                placeholder="Last Name"
                onKeyDown={lambda e: any -> None {
                    if e.key == "Enter" {
                        e.preventDefault();
                        focusNext("lastName");
                    }
                }}
            />
            <input
                ref={refs["email"]}
                placeholder="Email"
                type="email"
            />
            <input
                ref={refs["phone"]}
                placeholder="Phone"
            />
        </form>
    );
}
```

---

## Ref vs State

| Feature | useRef | useState |
|---------|--------|----------|
| Re-renders on change | No | Yes |
| Persists across renders | Yes | Yes |
| Access value | `.current` | Direct |
| Use case | DOM, timers, previous values | UI state |

### When to Use useRef

- DOM element access
- Timer IDs (setInterval, setTimeout)
- Previous values
- Values that change frequently but don't need re-render
- Third-party library instances

### When to Use useState

- Values that should trigger re-render
- UI state (forms, toggles, counters)
- Data that affects what's displayed

---

## Common Patterns

### Auto-focus on Mount

```jac
def AutoFocusInput() -> any {
    inputRef = useRef(None);

    useEffect(lambda -> None {
        inputRef.current.focus();
    }, []);

    return <input ref={inputRef} placeholder="I'm focused!" />;
}
```

### Measuring Elements

```jac
def MeasuredBox() -> any {
    boxRef = useRef(None);
    [dimensions, setDimensions] = useState({ "width": 0, "height": 0 });

    useEffect(lambda -> None {
        if boxRef.current {
            rect = boxRef.current.getBoundingClientRect();
            setDimensions({
                "width": rect.width,
                "height": rect.height
            });
        }
    }, []);

    return (
        <div>
            <div ref={boxRef} style={{ "padding": "20px", "border": "1px solid black" }}>
                Content here
            </div>
            <p>Width: {dimensions["width"]}px, Height: {dimensions["height"]}px</p>
        </div>
    );
}
```

---

## Summary

| Pattern | Syntax |
|---------|--------|
| Create ref | `myRef = useRef(None)` |
| Attach to DOM | `<input ref={myRef} />` |
| Access DOM | `myRef.current.focus()` |
| Store value | `myRef.current = value` |
| Read value | `value = myRef.current` |

---

## Next

- [Custom Hooks](05-custom-hooks.md) - Creating reusable hooks
