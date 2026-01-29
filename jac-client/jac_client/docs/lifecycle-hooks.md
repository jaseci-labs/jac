# Lifecycle Hooks in Jac: Component Lifecycle Management

Learn how to use React's `useEffect` and `useState` hooks to manage component state, initialization, side effects, and cleanup.

---

## Table of Contents

- [What are Lifecycle Hooks?](#what-are-lifecycle-hooks)
- [React Hooks (Recommended)](#react-hooks-recommended)
  - [useState](#usestate)
  - [useEffect](#useeffect)
- [Common Use Cases](#common-use-cases)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)
- [Legacy Jac Hooks](#legacy-jac-hooks)

---

## What are Lifecycle Hooks?

Lifecycle hooks are functions that let you run code at specific points in a component's lifecycle:

- **When component mounts**: Run initialization code once
- **When component updates**: React to state changes
- **When component unmounts**: Clean up resources

**Jac uses React hooks as the standard approach:**

- **useState**: Manage component state
- **useEffect**: Handle side effects, lifecycle events, and cleanup

**Key Benefits:**

- **Initialization**: Load data when component appears
- **Side Effects**: Set up subscriptions, timers, or listeners
- **Reactive Updates**: Run code when specific dependencies change
- **Cleanup**: Properly clean up resources when components unmount
- **Standard React API**: Works exactly like React hooks you already know

---

## React Hooks (Recommended)

### useState

The `useState` hook lets you add state to your components.

> **Note:** When using `has` variables in Jac, `useState` is automatically injected. You only need to explicitly import `useState` when using the React hooks pattern directly.

#### Basic Usage

```jac
cl import from react { useState }

cl {
    def Counter() -> any {
        [count, setCount] = useState(0);

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                setCount(count + 1);
            }}>
                Increment
            </button>
        </div>;
    }
}
```

**Key Points:**

- Import `useState` from `react`
- Returns an array: `[currentValue, setterFunction]`
- Use destructuring to get the value and setter
- Call the setter function to update state

#### Multiple State Variables

```jac
cl import from react { useState }

cl {
    def TodoApp() -> any {
        [todos, setTodos] = useState([]);
        [inputValue, setInputValue] = useState("");
        [filter, setFilter] = useState("all");

        return <div>Todo App</div>;
    }
}
```

### useEffect

The `useEffect` hook lets you perform side effects in your components. It provides full lifecycle management including mount, update, and cleanup.

#### Basic Usage - Run on Mount

```jac
cl import from react { useState, useEffect }

cl {
    def MyComponent() -> any {
        [data, setData] = useState(None);

        useEffect(lambda -> None {
            console.log("Component mounted!");
            # Load initial data
            async def loadData() -> None {
                result = await jacSpawn("get_data", "", {});
                setData(result);
            }
            loadData();
        }, []);  # Empty array means run only on mount

        return <div>My Component</div>;
    }
}
```

**Key Points:**

- Import `useEffect` from `react`
- First argument: function to run
- Second argument: dependency array
  - `[]` - run only on mount
  - `[count]` - run when `count` changes
  - No array - run on every render

#### useEffect with Dependencies

```jac
cl import from react { useState, useEffect }

cl {
    def Counter() -> any {
        [count, setCount] = useState(0);

        useEffect(lambda -> None {
            console.log("Count changed to:", count);
            document.title = "Count: " + str(count);
        }, [count]);  # Run when count changes

        return <div>
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                setCount(count + 1);
            }}>
                Increment
            </button>
        </div>;
    }
}
```

#### useEffect with Cleanup

```jac
cl import from react { useEffect }

cl {
    def TimerComponent() -> any {
        useEffect(lambda -> any {
            # Setup
            intervalId = setInterval(lambda -> None {
                console.log("Timer tick");
            }, 1000);

            # Cleanup function (returned from useEffect)
            return lambda -> None {
                clearInterval(intervalId);
            };
        }, []);

        return <div>Timer Component</div>;
    }
}
```

---

## Common Use Cases

### 1. Loading Initial Data

The most common use case is loading data when a component mounts:

```jac
cl import from react { useState, useEffect }
cl import from '@jac/runtime' { jacSpawn }

cl {
    def TodoApp() -> any {
        [todos, setTodos] = useState([]);
        [loading, setLoading] = useState(True);

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                setLoading(True);

                # Fetch todos from backend
                result = await jacSpawn("read_todos", "", {});
                console.log(result);
                setTodos(result.reports);
                setLoading(False);
            }
            loadTodos();
        }, []);  # Empty array = run only on mount

        if loading {
            return <div>Loading...</div>;
        }

        return <div>
            {todos.map(lambda todo: any -> any {
                return <TodoItem todo={todo} />;
            })}
        </div>;
    }
}
```

### 2. Setting Up Event Listeners

Set up event listeners with proper cleanup:

```jac
cl import from react { useState, useEffect }

cl {
    def WindowResizeHandler() -> any {
        [width, setWidth] = useState(0);
        [height, setHeight] = useState(0);

        useEffect(lambda -> any {
            def handleResize() -> None {
                setWidth(window.innerWidth);
                setHeight(window.innerHeight);
            }

            # Set initial size
            handleResize();

            # Add listener
            window.addEventListener("resize", handleResize);

            # Cleanup function
            return lambda -> None {
                window.removeEventListener("resize", handleResize);
            };
        }, []);

        return <div>
            Window size: {width} x {height}
        </div>;
    }
}
```

### 3. Fetching User Data

Load user-specific data when a component mounts:

```jac
cl import from react { useState, useEffect }
cl import from '@jac/runtime' { jacSpawn }

cl {
    def ProfileView() -> any {
        [profile, setProfile] = useState(None);
        [loading, setLoading] = useState(True);

        useEffect(lambda -> None {
            async def loadUserProfile() -> None {
                if not jacIsLoggedIn() {
                    navigate("/login");
                    return;
                }

                # Fetch user profile
                result = await jacSpawn("get_user_profile", "", {});
                setProfile(result);
                setLoading(False);
            }
            loadUserProfile();
        }, []);

        if loading {
            return <div>Loading profile...</div>;
        }

        if not profile {
            return <div>No profile found</div>;
        }

        return <div>
            <h1>{profile.username}</h1>
            <p>{profile.bio}</p>
        </div>;
    }
}
```

### 4. Initializing Third-Party Libraries

Initialize external libraries or APIs:

```jac
cl import from react { useEffect }

cl {
    def ChartComponent() -> any {
        useEffect(lambda -> any {
            # Initialize chart library
            chart = new Chart("myChart", {
                "type": "line",
                "data": chartData,
                "options": chartOptions
            });

            # Cleanup function
            return lambda -> None {
                chart.destroy();
            };
        }, []);

        return <canvas id="myChart"></canvas>;
    }
}
```

### 5. Focusing Input Fields

Focus an input field when a component mounts:

```jac
cl import from react { useEffect }

cl {
    def SearchBar() -> any {
        useEffect(lambda -> None {
            # Focus search input on mount
            inputEl = document.getElementById("search-input");
            if inputEl {
                inputEl.focus();
            }
        }, []);

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
cl import from react { useState, useEffect }
cl import from '@jac/runtime' { jacSpawn }

cl {
    def app() -> any {
        [todos, setTodos] = useState([]);
        [inputValue, setInputValue] = useState("");
        [filter, setFilter] = useState("all");

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                todos = await jacSpawn("read_todos","",{});
                console.log(todos);
                setTodos(todos.reports);
            }
            loadTodos();
        }, []);

        # Add a new todo
        async def addTodo() -> None {
            if not inputValue.trim() { return; }
            newTodo = {
                "id": Date.now(),
                "text": inputValue.trim(),
                "done": False
            };
            await jacSpawn("create_todo","", {"text": inputValue.trim()});
            newTodos = todos.concat([newTodo]);
            setTodos(newTodos);
            setInputValue("");
        }

        # Toggle todo completion status
        async def toggleTodo(id: any) -> None {
            await jacSpawn("toggle_todo",id, {});
            setTodos(todos.map(lambda todo: any -> any {
                if todo._jac_id == id {
                    updatedTodo = {
                        "_jac_id": todo._jac_id,
                        "text": todo.text,
                        "done": not todo.done,
                        "id": todo.id
                    };
                    return updatedTodo;
                }
                return todo;
            }));
        }

        # Filter todos based on current filter
        def getFilteredTodos() -> list {
            if filter == "active" {
                return todos.filter(lambda todo: any -> bool { return not todo.done; });
            } elif filter == "completed" {
                return todos.filter(lambda todo: any -> bool { return todo.done; });
            }
            return todos;
        }

        filteredTodos = getFilteredTodos();

        return <div style={{
            "maxWidth": "600px",
            "margin": "40px auto",
            "padding": "24px",
            "fontFamily": "system-ui, -apple-system, sans-serif"
        }}>
            <h1 style={{"textAlign": "center"}}> My Todo App</h1>

            # Add todo form
            <div style={{"display": "flex", "gap": "8px", "marginBottom": "24px"}}>
                <input
                    type="text"
                    value={inputValue}
                    onChange={lambda e: any -> None { setInputValue(e.target.value); }}
                    onKeyPress={lambda e: any -> None {
                        if e.key == "Enter" { addTodo(); }
                    }}
                    placeholder="What needs to be done?"
                    style={{"flex": "1", "padding": "12px"}}
                />
                <button onClick={addTodo} style={{"padding": "12px 24px"}}>
                    Add
                </button>
            </div>

            # Filter buttons
            <div style={{"display": "flex", "gap": "8px", "marginBottom": "16px"}}>
                <button onClick={lambda -> None { setFilter("all"); }}>All</button>
                <button onClick={lambda -> None { setFilter("active"); }}>Active</button>
                <button onClick={lambda -> None { setFilter("completed"); }}>Completed</button>
            </div>

            # Todo list
            <ul>
                {filteredTodos.map(lambda todo: any -> any {
                    return <li key={todo._jac_id}>
                        <input
                            type="checkbox"
                            checked={todo.done}
                            onChange={lambda -> None { toggleTodo(todo._jac_id); }}
                        />
                        <span>{todo.text}</span>
                    </li>;
                })}
            </ul>
        </div>;
    }
}
```

### Example 2: Dashboard with Multiple Data Sources

```jac
cl import from react { useState, useEffect }
cl import from '@jac/runtime' { jacSpawn }

cl {
    def Dashboard() -> any {
        [stats, setStats] = useState(None);
        [activity, setActivity] = useState([]);
        [loading, setLoading] = useState(True);

        useEffect(lambda -> None {
            async def loadDashboardData() -> None {
                setLoading(True);

                # Load multiple data sources in parallel
                results = await Promise.all([
                    jacSpawn("get_stats", "", {}),
                    jacSpawn("get_recent_activity", "", {})
                ]);

                setStats(results[0]);
                setActivity(results[1].reports);
                setLoading(False);
            }
            loadDashboardData();
        }, []);

        if loading {
            return <div>Loading dashboard...</div>;
        }

        return <div>
            <StatsView stats={stats} />
            <ActivityList activities={activity} />
        </div>;
    }
}
```

### Example 3: Timer Component with Cleanup

Proper cleanup when component unmounts:

```jac
cl import from react { useState, useEffect }

cl {
    def TimerComponent() -> any {
        [seconds, setSeconds] = useState(0);

        useEffect(lambda -> any {
            # Set up timer
            intervalId = setInterval(lambda -> None {
                setSeconds(lambda prev: int -> int { return prev + 1; });
            }, 1000);

            # Cleanup function - runs when component unmounts
            return lambda -> None {
                clearInterval(intervalId);
            };
        }, []);

        return <div>Timer: {seconds} seconds</div>;
    }
}
```

---

## Best Practices

### 1. Always Specify Dependencies

Be explicit about what your effect depends on:

```jac
#  Good: Empty array for mount-only effects
useEffect(lambda -> None {
    loadInitialData();
}, []);

#  Good: Specify dependencies
useEffect(lambda -> None {
    console.log("Count changed:", count);
}, [count]);

#  Warning: No dependency array runs on every render
useEffect(lambda -> None {
    console.log("Runs on every render!");
});
```

### 2. Handle Async Operations Properly

Always handle async operations with proper error handling:

```jac
#  Good: Proper async handling
useEffect(lambda -> None {
    async def loadData() -> None {
        try {
            data = await jacSpawn("get_data", "", {});
            setData(data);
        } except Exception as err {
            console.error("Error loading data:", err);
            setError(err);
        }
    }
    loadData();
}, []);
```

### 3. Clean Up Side Effects

Always clean up event listeners, timers, and subscriptions:

```jac
#  Good: Cleanup function removes event listener
useEffect(lambda -> any {
    def handleResize() -> None {
        setWidth(window.innerWidth);
    }

    window.addEventListener("resize", handleResize);

    return lambda -> None {
        window.removeEventListener("resize", handleResize);
    };
}, []);
```

### 4. Use Loading States

Show loading indicators while data is being fetched:

```jac
#  Good: Clear loading states
def Component() -> any {
    [data, setData] = useState(None);
    [loading, setLoading] = useState(True);
    [error, setError] = useState(None);

    useEffect(lambda -> None {
        async def loadData() -> None {
            try {
                setLoading(True);
                result = await jacSpawn("get_data", "", {});
                setData(result);
            } except Exception as err {
                setError(err);
            } finally {
                setLoading(False);
            }
        }
        loadData();
    }, []);

    if loading { return <div>Loading...</div>; }
    if error { return <div>Error: {error}</div>; }
    return <div>{data}</div>;
}
```

### 5. Keep Effects Focused

Each effect should have a single responsibility:

```jac
#  Good: Separate effects for separate concerns
def Component() -> any {
    useEffect(lambda -> None {
        loadData();  # Data loading
    }, []);

    useEffect(lambda -> any {
        # Event listener setup
        window.addEventListener("resize", handleResize);
        return lambda -> None {
            window.removeEventListener("resize", handleResize);
        };
    }, []);

    return <div>Component</div>;
}
```

### 6. Avoid Stale Closures

Be careful with closures capturing old state values:

```jac
#  Avoid: Stale closure problem
useEffect(lambda -> None {
    setInterval(lambda -> None {
        setCount(count + 1);  # count is stale!
    }, 1000);
}, []);

#  Good: Use functional update
useEffect(lambda -> any {
    intervalId = setInterval(lambda -> None {
        setCount(lambda prev: int -> int { return prev + 1; });
    }, 1000);

    return lambda -> None {
        clearInterval(intervalId);
    };
}, []);
```

---

## Summary

- **useState**: Manage component state (replaces `createState()`, `createSignal()`)
- **useEffect**: Handle side effects and lifecycle events (replaces `onMount()`, `createEffect()`)
- **Dependencies**: Always specify what your effect depends on
- **Cleanup**: Return a cleanup function for subscriptions, timers, and listeners
- **Best Practices**: Handle errors, use loading states, keep effects focused

React hooks provide a powerful and standard way to manage component lifecycle!

---

## Legacy Jac Hooks

> **Note**: The following hooks are from older Jac versions. New projects should use React hooks instead.

### `onMount()` - Legacy

The `onMount()` hook was a Jac-specific hook for running code once when a component mounts:

```jac
# Legacy approach - use useEffect instead
def Component() -> any {
    onMount(lambda -> None {
        loadData();
    });
    return <div>Component</div>;
}
```

**Modern equivalent:**

```jac
# Modern approach with React hooks
def Component() -> any {
    useEffect(lambda -> None {
        loadData();
    }, []);
    return <div>Component</div>;
}
```

### `createState()` - Legacy

The `createState()` hook was a Jac-specific state management solution:

```jac
# Legacy approach - use useState instead
[state, setState] = createState({"count": 0});

def Component() -> any {
    s = state();
    return <div>{s.count}</div>;
}
```

**Modern equivalent:**

```jac
# Modern approach with React hooks
def Component() -> any {
    [count, setCount] = useState(0);
    return <div>{count}</div>;
}
```

### `createSignal()` and `createEffect()` - Legacy

These were Signal-based reactive primitives from Jac:

```jac
# Legacy approach
[count, setCount] = createSignal(0);

createEffect(lambda -> None {
    console.log("Count:", count());
});
```

**Modern equivalent:**

```jac
# Modern approach with React hooks
[count, setCount] = useState(0);

useEffect(lambda -> None {
    console.log("Count:", count);
}, [count]);
```
