# State Management

Manage reactive state with hooks and the `has` keyword.

> **Prerequisites**
>
> - Completed: [React-Style Components](components.md)
> - Time: ~30 minutes

---

## Reactive State with `has`

Inside `cl { }` blocks, `has` creates reactive state (like React's `useState`):

```jac
cl {
    def:pub Counter() -> any {
        has count: int = 0;  # Reactive state

        return <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

**How it works:**

- `has count: int = 0` compiles to `const [count, setCount] = useState(0)`
- Assignments like `count = count + 1` become `setCount(count + 1)`
- The component re-renders when state changes

---

## Multiple State Variables

```jac
cl {
    def:pub Form() -> any {
        has name: str = "";
        has email: str = "";
        has submitted: bool = False;

        def handle_submit() -> None {
            print(f"Submitting: {name}, {email}");
            submitted = True;
        }

        if submitted {
            return <p>Thanks, {name}!</p>;
        }

        return <form>
            <input
                value={name}
                onChange={lambda e: any -> None { name = e.target.value; }}
                placeholder="Name"
            />
            <input
                value={email}
                onChange={lambda e: any -> None { email = e.target.value; }}
                placeholder="Email"
            />
            <button
                type="button"
                onClick={lambda -> None { handle_submit(); }}
            >
                Submit
            </button>
        </form>;
    }
}
```

---

## Complex State (Objects/Lists)

```jac
cl {
    def:pub TodoApp() -> any {
        has todos: list = [];
        has input_text: str = "";

        def add_todo() -> None {
            if input_text {
                todos = todos + [{"id": len(todos), "text": input_text}];
                input_text = "";
            }
        }

        def remove_todo(id: int) -> None {
            todos = [t for t in todos if t["id"] != id];
        }

        return <div>
            <input
                value={input_text}
                onChange={lambda e: any -> None { input_text = e.target.value; }}
            />
            <button onClick={lambda -> None { add_todo(); }}>Add</button>

            <ul>
                {todos.map(lambda todo: any -> any {
                    return <li key={todo["id"]}>
                        {todo["text"]}
                        <button onClick={lambda -> None { remove_todo(todo["id"]); }}>
                            X
                        </button>
                    </li>;
                })}
            </ul>
        </div>;
    }
}
```

**Important:** For lists and objects, create new references:

- `todos = [...todos, newItem]` (spread to new list)
- `todos = [t for t in todos if condition]` (filter to new list)

---

## useEffect - Side Effects

```jac
cl {
    import from react { useEffect }

    def:pub DataFetcher() -> any {
        has data: list = [];
        has loading: bool = True;

        # Run once on mount
        useEffect(lambda -> None {
            async def fetch_data() -> None {
                # Simulate API call
                result = await some_async_operation();
                data = result;
                loading = False;
            }
            fetch_data();
        }, []);  # Empty deps = run once

        if loading {
            return <p>Loading...</p>;
        }

        return <ul>
            {data.map(lambda item: any -> any {
                return <li key={item.id}>{item.name}</li>;
            })}
        </ul>;
    }
}
```

### Effect Dependencies

```jac
cl {
    import from react { useEffect }

    def:pub SearchResults() -> any {
        has query: str = "";
        has results: list = [];

        # Run when query changes
        useEffect(lambda -> None {
            if query {
                # Fetch results based on query
                print(f"Searching for: {query}");
            }
        }, [query]);  # Depends on query

        return <div>
            <input
                value={query}
                onChange={lambda e: any -> None { query = e.target.value; }}
            />
            <ul>
                {results.map(lambda r: any -> any { return <li>{r}</li>; })}
            </ul>
        </div>;
    }
}
```

---

## useContext - Global State

### Creating Context

```jac
cl {
    import from react { createContext, useContext }

    # Create context
    glob AppContext = createContext(None);

    # Provider component
    def:pub AppProvider(props: dict) -> any {
        has user: any = None;
        has theme: str = "light";

        value = {
            "user": user,
            "theme": theme,
            "setUser": lambda u: any -> None { user = u; },
            "setTheme": lambda t: str -> None { theme = t; }
        };

        return <AppContext.Provider value={value}>
            {props.children}
        </AppContext.Provider>;
    }

    # Consumer component
    def:pub UserDisplay() -> any {
        ctx = useContext(AppContext);

        if ctx.user {
            return <p>Welcome, {ctx.user.name}!</p>;
        }
        return <p>Not logged in</p>;
    }

    def:pub ThemeToggle() -> any {
        ctx = useContext(AppContext);

        return <button onClick={lambda -> None {
            ctx.setTheme("dark" if ctx.theme == "light" else "light");
        }}>
            Toggle Theme ({ctx.theme})
        </button>;
    }

    def:pub app() -> any {
        return <AppProvider>
            <UserDisplay />
            <ThemeToggle />
        </AppProvider>;
    }
}
```

---

## Custom Hooks

Create reusable state logic:

```jac
cl {
    import from react { useEffect }

    # Custom hook
    def use_local_storage(key: str, initial_value: any) -> tuple {
        has value: any = initial_value;

        # Load from localStorage on mount
        useEffect(lambda -> None {
            stored = localStorage.getItem(key);
            if stored {
                value = JSON.parse(stored);
            }
        }, []);

        # Save to localStorage when value changes
        useEffect(lambda -> None {
            localStorage.setItem(key, JSON.stringify(value));
        }, [value]);

        return (value, lambda v: any -> None { value = v; });
    }

    def:pub Settings() -> any {
        (theme, set_theme) = use_local_storage("theme", "light");

        return <div>
            <p>Current theme: {theme}</p>
            <button onClick={lambda -> None { set_theme("dark"); }}>
                Dark
            </button>
            <button onClick={lambda -> None { set_theme("light"); }}>
                Light
            </button>
        </div>;
    }
}
```

---

## State Patterns

### Loading State Pattern

```jac
cl {
    def:pub DataComponent() -> any {
        has data: any = None;
        has loading: bool = True;
        has error: str = "";

        # ... fetch data ...

        if loading {
            return <div className="spinner">Loading...</div>;
        }

        if error {
            return <div className="error">{error}</div>;
        }

        return <div>{data}</div>;
    }
}
```

### Form State Pattern

```jac
cl {
    def:pub ContactForm() -> any {
        has form_data: dict = {
            "name": "",
            "email": "",
            "message": ""
        };
        has errors: dict = {};
        has submitting: bool = False;

        def update_field(field: str, value: str) -> None {
            form_data[field] = value;
        }

        def validate() -> bool {
            new_errors = {};
            if not form_data["name"] {
                new_errors["name"] = "Name is required";
            }
            if "@" not in form_data["email"] {
                new_errors["email"] = "Invalid email";
            }
            errors = new_errors;
            return len(new_errors) == 0;
        }

        def handle_submit() -> None {
            if validate() {
                submitting = True;
                # ... submit form ...
            }
        }

        return <form>
            <input
                value={form_data["name"]}
                onChange={lambda e: any -> None { update_field("name", e.target.value); }}
            />
            {errors.get("name") and <span className="error">{errors["name"]}</span>}
        </form>;
    }
}
```

---

## Key Takeaways

| Concept | Jac Syntax | React Equivalent |
|---------|------------|------------------|
| State variable | `has count: int = 0` | `useState(0)` |
| Update state | `count = count + 1` | `setCount(count + 1)` |
| Side effects | `useEffect(fn, deps)` | Same |
| Global state | `useContext(Ctx)` | Same |
| Dependencies | `[var1, var2]` | Same |

---

## Next Steps

- [Backend Integration](backend.md) - Fetch data from walkers
- [Authentication](auth.md) - Add user login
