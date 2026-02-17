# Step 7: Component Lifecycle with `useEffect`

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll learn about **useEffect** - a way to run code when your component loads or when data changes!

---

## Part 1: Building the App

### Step 7.1: Understanding the Problem

Right now, your todos reset every time you refresh the page. We need to:

1. Load todos when the app starts
2. Save todos when they change

We'll use `useEffect` to handle this!

### Step 7.2: Add useEffect Import

First, import `useEffect` (note: `useState` is auto-injected when using `has` variables, so you only need to import `useEffect`):

```jac
cl import from react {useEffect}

cl {
    # ... your components
    # useState is automatically available - no import needed!
}
```

> **Note:** The `useState` import is automatically injected when you use `has` variables in `cl {}` blocks or `.cl.jac` files. You only need to explicitly import other hooks like `useEffect`.

### Step 7.3: Run Code When App Loads

Let's log a message when the app starts:

```jac
cl import from react {useEffect}

cl {
    # ... (keep all your components from step 6)

    def:pub app() -> JsxElement {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");
        [filter, setFilter] = useState("all");

        # Run once when component mounts
        useEffect(lambda -> None {
            console.log("App loaded!");
        }, []);

        # ... rest of your code
    }
}
```

**Open browser console (F12) and refresh** - you'll see "App loaded!" printed once!

### Step 7.4: Save to localStorage

Let's persist todos using localStorage:

```jac
cl import from react {useEffect}

cl {
    # ... (keep all components)

    def:pub app() -> JsxElement {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");
        [filter, setFilter] = useState("all");

        # Load todos from localStorage when app mounts
        useEffect(lambda -> None {
            saved = localStorage.getItem("todos");
            if saved {
                parsed = JSON.parse(saved);
                setTodos(parsed);
            }
        }, []);

        # Save todos to localStorage whenever they change
        useEffect(lambda -> None {
            localStorage.setItem("todos", JSON.stringify(todos));
        }, [todos]);

        # ... (keep all your functions: addTodo, toggleTodo, deleteTodo, getFilteredTodos)

        # ... (keep your return statement with all the UI)
    }
}
```

**Try it!** Add some todos, then refresh the page - your todos persist!

### Step 7.5: Add Loading State

Let's add a loading indicator:

```jac
cl import from react {useEffect}

cl {
    # ... (keep all components)

    def:pub app() -> JsxElement {
        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");
        [filter, setFilter] = useState("all");
        [loading, setLoading] = useState(true);

        # Load todos
        useEffect(lambda -> None {
            console.log("Loading todos...");

            # Simulate loading delay
            setTimeout(lambda -> None {
                saved = localStorage.getItem("todos");
                if saved {
                    parsed = JSON.parse(saved);
                    setTodos(parsed);
                }
                setLoading(false);
            }, 500);
        }, []);

        # Save todos whenever they change
        useEffect(lambda -> None {
            if not loading {  # Don't save during initial load
                localStorage.setItem("todos", JSON.stringify(todos));
            }
        }, [todos]);

        # ... (keep all your functions)

        # Show loading state
        if loading {
            return <div style={{
                "display": "flex",
                "justifyContent": "center",
                "alignItems": "center",
                "height": "100vh"
            }}>
                <h2>Loading todos...</h2>
            </div>;
        }

        # ... (keep your normal UI return statement)
    }
}
```

**Try it!** You'll see a brief loading message before your todos appear!

---

**⏭ Want to skip the theory?** Jump to [Step 8: Walkers](./step-08-walkers.md)

---

## Part 2: Understanding the Concepts

### What is `useEffect`?

`useEffect` lets you run **side effects** - code that affects things outside your component.

**Common side effects:**

- Fetching data from a server
- Saving data to localStorage
- ⏰ Setting up timers
- Logging analytics
- Subscribing to events

**Python analogy:**

```python
# Python
class TodoApp:
    def __init__(self):
        self.load_from_database()  # Side effect: reads from DB

# Jac
def:pub app() -> JsxElement {
    useEffect(lambda -> None {
        # Load data
    }, []);
}
```

### useEffect Syntax

```jac
useEffect(lambda -> None {
    # Code to run
}, [dependencies]);
```

**Two parameters:**

1. **Function** - What to run
2. **Dependencies** - When to re-run

### Dependency Array Controls When to Run

**Run once (on mount):**

```jac
useEffect(lambda -> None {
    console.log("Component mounted!");
}, []);  # Empty array = run once
```

**Run when specific value changes:**

```jac
useEffect(lambda -> None {
    console.log("Todos changed!");
}, [todos]);  # Run whenever todos changes
```

**Run on every render (rarely used):**

```jac
useEffect(lambda -> None {
    console.log("Component rendered!");
});  # No array = run always (be careful!)
```

### Multiple useEffect Hooks

You can use multiple `useEffect` hooks for different purposes:

```jac
def:pub app() -> JsxElement {
    [todos, setTodos] = useState([]);

    # Effect 1: Load data once
    useEffect(lambda -> None {
        saved = localStorage.getItem("todos");
        if saved {
            setTodos(JSON.parse(saved));
        }
    }, []);

    # Effect 2: Save when todos change
    useEffect(lambda -> None {
        localStorage.setItem("todos", JSON.stringify(todos));
    }, [todos]);

    # Effect 3: Log count changes
    useEffect(lambda -> None {
        console.log("Todo count:", todos.length);
    }, [todos.length]);
}
```

This keeps your code organized!

### useEffect Lifecycle

```
1. Component renders
   ↓
2. UI updates on screen
   ↓
3. useEffect runs
   ↓
4. State changes (from effect)
   ↓
5. Component re-renders
   ↓
6. useEffect runs again (if dependencies changed)
```

### localStorage API

Browser's built-in storage:

```jac
# Save data
localStorage.setItem("key", "value");

# Load data
value = localStorage.getItem("key");

# Remove data
localStorage.removeItem("key");

# Clear all
localStorage.clear();

# For objects/arrays, use JSON
localStorage.setItem("todos", JSON.stringify(todos));
todos = JSON.parse(localStorage.getItem("todos"));
```

**Storage limits:**

- ~5-10 MB per domain
- Persists across browser sessions
- Only stores strings (use JSON for objects)

### Preventing Initial Save

When loading from localStorage, you don't want to immediately save back:

```jac
[loading, setLoading] = useState(true);

# Load
useEffect(lambda -> None {
    # ... load data ...
    setLoading(false);
}, []);

# Save (skip during initial load)
useEffect(lambda -> None {
    if not loading {
        localStorage.setItem("todos", JSON.stringify(todos));
    }
}, [todos]);
```

### Common useEffect Patterns

**Pattern 1: Fetch on mount**

```jac
useEffect(lambda -> None {
    async def fetchData() -> None {
        data = await apiCall();
        setState(data);
    }
    fetchData();
}, []);
```

**Pattern 2: Sync with external system**

```jac
useEffect(lambda -> None {
    localStorage.setItem("key", value);
}, [value]);
```

**Pattern 3: Cleanup (timers, subscriptions)**

```jac
useEffect(lambda -> None {
    timerId = setInterval(lambda -> None {
        console.log("Tick");
    }, 1000);

    # Return cleanup function
    return lambda -> None {
        clearInterval(timerId);
    };
}, []);
```

**Pattern 4: Conditional effect**

```jac
useEffect(lambda -> None {
    if someCondition {
        # Do something
    }
}, [someCondition]);
```

---

## What You've Learned

- What useEffect is and why we need it
- How to run code when component mounts
- Dependency arrays control when effects run
- Multiple useEffect hooks for organization
- Using localStorage to persist data
- Adding loading states
- Preventing unnecessary saves

---

## Common Issues

### Issue: Effect runs too many times

**Check:** Is your dependency array correct?

```jac
#  Wrong - runs on every render
useEffect(lambda -> None {
    console.log(todos);
});

#  Correct - runs only when todos change
useEffect(lambda -> None {
    console.log(todos);
}, [todos]);
```

### Issue: Effect doesn't run when it should

**Check:** Did you include all dependencies?

```jac
#  Wrong - missing todos dependency
useEffect(lambda -> None {
    console.log(todos.length);
}, []);

#  Correct - includes todos
useEffect(lambda -> None {
    console.log(todos.length);
}, [todos]);
```

### Issue: localStorage data not loading

**Check:**

- Are you parsing JSON? `JSON.parse(saved)`
- Are you checking if data exists? `if saved { ... }`
- Is the key name correct? `"todos"` in both save and load

### Issue: Infinite loop

**Cause:** Effect updates state, which triggers effect again

```jac
#  Wrong - infinite loop!
useEffect(lambda -> None {
    setTodos([...]);  # This triggers effect again!
}, [todos]);

#  Correct - run only once
useEffect(lambda -> None {
    setTodos([...]);
}, []);
```

---

## Quick Exercise

Try adding a "last saved" timestamp:

```jac
[lastSaved, setLastSaved] = useState(None);

useEffect(lambda -> None {
    if not loading and todos.length > 0 {
        localStorage.setItem("todos", JSON.stringify(todos));
        setLastSaved(Date().toLocaleTimeString());
    }
}, [todos]);

# Display it
{(<p>Last saved: {lastSaved}</p>) if lastSaved else None}
```

---

## Next Step

Great! Your app now persists data with localStorage. But localStorage is only local to your browser!

In the next step, we'll add **real backend** using **walkers** so your data is stored on a server!

 **[Continue to Step 8: Walkers](./step-08-walkers.md)**
