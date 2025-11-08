# Lifecycle Hooks in Jac: Component Lifecycle Management

Learn how to use `onMount()` and other lifecycle hooks to manage component initialization, side effects, and cleanup.

---

## 📚 Table of Contents

- [What are Lifecycle Hooks?](#what-are-lifecycle-hooks)
- [The `onMount()` Hook](#the-onmount-hook)
- [Common Use Cases](#common-use-cases)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)

---

## What are Lifecycle Hooks?

Lifecycle hooks are functions that let you run code at specific points in a component's lifecycle:
- **When component mounts**: Run initialization code once
- **When component updates**: React to state changes
- **When component unmounts**: Clean up resources

In Jac, the primary lifecycle hook is `onMount()`, which runs code once when a component first renders.

**Key Benefits:**
- **Initialization**: Load data when component appears
- **Side Effects**: Set up subscriptions, timers, or listeners
- **One-Time Setup**: Ensure code runs only once, not on every render
- **Component Scoping**: Automatically tracks which component called the hook

---

## The `onMount()` Hook

### Basic Usage

```jac
cl {
    def MyComponent() -> any {
        onMount(lambda -> None {
            console.log("Component mounted!");
            # Load initial data
            loadData();
        });

        return <div>My Component</div>;
    }
}
```

**How it Works:**
1. Component renders
2. `onMount()` is called
3. The provided function runs **once** after the component is fully rendered
4. Function won't run again on re-renders

### Key Characteristics

- **Runs Once**: Executes only on the first render
- **After Render**: Runs after the component is mounted to the DOM
- **Component Scoped**: Automatically tracks which component called it
- **Async Support**: Can contain async operations

---

## Common Use Cases

### 1. Loading Initial Data

The most common use case is loading data when a component mounts:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "loading": True
    });

    async def loadTodos() -> None {
        setTodoState({"loading": True});

        # Fetch todos from backend
        todos = await __jacSpawn("read_todos");

        items = [];
        for todo in todos.reports {
            items.push({
                "id": todo._jac_id,
                "text": todo.text,
                "done": todo.done
            });
        }

        setTodoState({"items": items, "loading": False});
    }

    def TodoApp() -> any {
        # Load todos when component mounts
        onMount(lambda -> None {
            loadTodos();
        });

        s = todoState();

        if s.loading {
            return <div>Loading...</div>;
        }

        return <div>
            {[TodoItem(item) for item in s.items]}
        </div>;
    }
}
```

### 2. Setting Up Event Listeners

Set up event listeners that need to persist across re-renders:

```jac
cl {
    def WindowResizeHandler() -> any {
        let [windowSize, setWindowSize] = createState({
            "width": 0,
            "height": 0
        });

        def handleResize() -> None {
            setWindowSize({
                "width": window.innerWidth,
                "height": window.innerHeight
            });
        }

        def ResizeDisplay() -> any {
            onMount(lambda -> None {
                # Set initial size
                handleResize();

                # Add listener
                window.addEventListener("resize", handleResize);
            });

            s = windowSize();
            return <div>
                Window size: {s.width} x {s.height}
            </div>;
        }

        return ResizeDisplay();
    }
}
```

### 3. Fetching User Data

Load user-specific data when a component mounts:

```jac
cl {
    let [userState, setUserState] = createState({
        "profile": None,
        "loading": True
    });

    async def loadUserProfile() -> None {
        if not jacIsLoggedIn() {
            navigate("/login");
            return;
        }

        # Fetch user profile
        profile = await __jacSpawn("get_user_profile");

        setUserState({
            "profile": profile,
            "loading": False
        });
    }

    def ProfileView() -> any {
        onMount(lambda -> None {
            loadUserProfile();
        });

        s = userState();

        if s.loading {
            return <div>Loading profile...</div>;
        }

        if not s.profile {
            return <div>No profile found</div>;
        }

        return <div>
            <h1>{s.profile.username}</h1>
            <p>{s.profile.email}</p>
        </div>;
    }
}
```

### 4. Initializing Third-Party Libraries

Initialize external libraries or APIs:

```jac
cl {
    def ChartComponent() -> any {
        onMount(lambda -> None {
            # Initialize chart library
            chart = new Chart("myChart", {
                "type": "line",
                "data": chartData,
                "options": chartOptions
            });
        });

        return <canvas id="myChart"></canvas>;
    }
}
```

### 5. Focusing Input Fields

Focus an input field when a component mounts:

```jac
cl {
    def SearchBar() -> any {
        onMount(lambda -> None {
            # Focus search input on mount
            inputEl = document.getElementById("search-input");
            if inputEl {
                inputEl.focus();
            }
        });

        return <input
            id="search-input"
            type="text"
            placeholder="Search..."
        />;
    }
}
```

---

## Complete Examples

### Example 1: Todo App with Data Loading

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "loading": False
    });

    async def read_todos_action() -> None {
        setTodoState({"loading": True});

        try {
            todos = await __jacSpawn("read_todos");

            items = [];
            for todo in todos.reports {
                items.push({
                    "id": todo._jac_id,
                    "text": todo.text,
                    "done": todo.done
                });
            }

            setTodoState({"items": items, "loading": False});
        } except Exception as err {
            console.error("Failed to load todos:", err);
            setTodoState({"loading": False});
        }
    }

    def TodoApp() -> any {
        # Load todos when component mounts
        onMount(lambda -> None {
            read_todos_action();
        });

        s = todoState();

        if s.loading {
            return <div style={{
                "textAlign": "center",
                "padding": "40px"
            }}>
                Loading todos...
            </div>;
        }

        itemsArr = filteredItems();
        children = [];
        for it in itemsArr {
            children.push(TodoItem(it));
        }

        return <div>
            <h2>My Todos</h2>
            <form onSubmit={onAddTodo}>
                <input id="todo-input" type="text" />
                <button type="submit">Add Todo</button>
            </form>
            <ul>{children}</ul>
        </div>;
    }
}
```

### Example 2: Dashboard with Multiple Data Sources

```jac
cl {
    let [dashboardState, setDashboardState] = createState({
        "stats": None,
        "recentActivity": [],
        "loading": True
    });

    async def loadDashboardData() -> None {
        setDashboardState({"loading": True});

        # Load multiple data sources in parallel
        [stats, activity] = await Promise.all([
            __jacSpawn("get_stats"),
            __jacSpawn("get_recent_activity")
        ]);

        setDashboardState({
            "stats": stats,
            "recentActivity": activity.reports,
            "loading": False
        });
    }

    def Dashboard() -> any {
        # Load all dashboard data on mount
        onMount(lambda -> None {
            loadDashboardData();
        });

        s = dashboardState();

        if s.loading {
            return <div>Loading dashboard...</div>;
        }

        return <div>
            <StatsView stats={s.stats} />
            <ActivityList activities={s.recentActivity} />
        </div>;
    }
}
```

### Example 3: Component with Cleanup (Future)

While `onMount()` doesn't currently support cleanup directly, you can store cleanup functions:

```jac
cl {
    let cleanupFunctions = [];

    def TimerComponent() -> any {
        onMount(lambda -> None {
            # Set up timer
            intervalId = setInterval(lambda -> None {
                console.log("Timer tick");
            }, 1000);

            # Store cleanup function
            cleanupFunctions.push(lambda -> None {
                clearInterval(intervalId);
            });
        });

        return <div>Timer Component</div>;
    }
}
```

---

## Best Practices

### 1. Use `onMount()` for Initialization Only

```jac
# ✅ Good: One-time initialization
def Component() -> any {
    onMount(lambda -> None {
        loadInitialData();
    });
    return <div>Component</div>;
}

# ❌ Avoid: Side effects that should run on every state change
def Component() -> any {
    s = state();
    onMount(lambda -> None {
        # This won't run when state changes!
        processState(s);
    });
    return <div>{s.value}</div>;
}
```

### 2. Handle Async Operations

Always handle async operations properly:

```jac
# ✅ Good: Handle async properly
async def loadData() -> None {
    try {
        data = await __jacSpawn("get_data");
        setState({"data": data});
    } except Exception as err {
        console.error("Error loading data:", err);
    }
}

def Component() -> any {
    onMount(lambda -> None {
        loadData();
    });
    return <div>Component</div>;
}
```

### 3. Check Conditions Before Operations

Verify prerequisites before executing operations:

```jac
# ✅ Good: Check authentication first
def ProtectedComponent() -> any {
    onMount(lambda -> None {
        if not jacIsLoggedIn() {
            navigate("/login");
            return;
        }
        loadUserData();
    });
    return <div>Protected Content</div>;
}
```

### 4. Use Loading States

Show loading indicators while data is being fetched:

```jac
def Component() -> any {
    let [dataState, setDataState] = createState({
        "data": None,
        "loading": True
    });

    onMount(lambda -> None {
        loadData();
    });

    s = dataState();
    if s.loading {
        return <div>Loading...</div>;
    }

    return <div>{s.data}</div>;
}
```

### 5. Avoid Multiple `onMount()` Calls

Group initialization logic in a single `onMount()` call:

```jac
# ✅ Good: Single onMount with multiple operations
def Component() -> any {
    onMount(lambda -> None {
        loadData();
        setupEventListeners();
        initializeThirdParty();
    });
    return <div>Component</div>;
}

# ❌ Avoid: Multiple onMount calls
def Component() -> any {
    onMount(lambda -> None { loadData(); });
    onMount(lambda -> None { setupEventListeners(); });
    onMount(lambda -> None { initializeThirdParty(); });
    return <div>Component</div>;
}
```

---

## When NOT to Use `onMount()`

### Use `createEffect()` for Reactive Side Effects

If you need code to run when state changes, use `createEffect()` instead:

```jac
# ✅ Use createEffect() for state-dependent side effects
def Component() -> any {
    let [count, setCount] = createSignal(0);

    createEffect(lambda -> None {
        console.log("Count changed:", count());
    });

    return <div>
        <button onClick={lambda -> None { setCount(count() + 1); }}>
            Count: {count()}
        </button>
    </div>;
}

# ❌ onMount() won't run when state changes
def Component() -> any {
    let [count, setCount] = createSignal(0);

    onMount(lambda -> None {
        console.log("Count:", count());  # Only logs initial value
    });

    return <div>Component</div>;
}
```

---

## Summary

- **`onMount()`**: Runs code once when a component first mounts
- **Use Cases**: Loading data, setting up listeners, initializing libraries
- **Best Practices**: Handle async properly, check conditions, show loading states
- **Avoid**: Using `onMount()` for reactive side effects (use `createEffect()` instead)

Lifecycle hooks help you manage component initialization and side effects effectively! 🎯

