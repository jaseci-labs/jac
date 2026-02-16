# Advanced State Management in Jac

Learn how to manage complex state in Jac using React hooks, combining multiple state instances, and building scalable state architectures.

---

## Table of Contents

- [React Hooks Overview](#react-hooks-overview)
- [Multiple State Variables](#multiple-state-variables)
- [State Composition Patterns](#state-composition-patterns)
- [Derived State](#derived-state)
- [Advanced React Hooks](#advanced-react-hooks)
- [State Management Patterns](#state-management-patterns)
- [Best Practices](#best-practices)

---

## React Hooks Overview

Jac uses React hooks for all state management. The most common hooks are:

- **`useState`**: Manage component state
- **`useEffect`**: Handle side effects and lifecycle
- **`useReducer`**: Manage complex state logic
- **`useContext`**: Share state across components
- **`useMemo`**: Memoize expensive computations
- **`useCallback`**: Memoize callback functions

### Basic useState Example

> **Note:** When using `has` variables in Jac, `useState` is automatically injected. You only need to explicitly import `useState` when using the React hooks pattern directly (e.g., `[value, setValue] = useState(initial)`).

```jac
cl import from react { useState, useEffect }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");
        [loading, setLoading] = useState(False);

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                setLoading(True);
                result = root spawn read_todos();
                setTodos(result.reports);
                setLoading(False);
            }
            loadTodos();
        }, []);

        return <div>{/* your UI */}</div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

---

## Multiple State Variables

### Separating State by Concern

Instead of putting everything in one state object, split state into multiple variables:

```jac
cl import from react { useState, useEffect }

cl {
    def TodoApp() -> JsxElement {
        # Separate state variables for different concerns
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");
        [loading, setLoading] = useState(False);
        [error, setError] = useState(None);

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                setLoading(True);
                setError(None);
                try {
                    result = root spawn read_todos();
                    setTodos(result.reports);
                } catch (err) {
                    setError(err);
                } finally {
                    setLoading(False);
                }
            }
            loadTodos();
        }, []);

        if loading { return <div>Loading...</div>; }
        if error { return <div>Error: {error}</div>; }

        return <div>
            {todos.map(lambda todo: any -> any {
                return <TodoItem key={todo._jac_id} todo={todo} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

**Benefits:**

- **Separation of Concerns**: Each state variable manages one aspect
- **Selective Updates**: Only components using specific state re-render
- **Type Safety**: Each variable has its own type
- **Clearer Code**: Easy to understand what each state represents

### When to Use Object State

Sometimes an object makes sense for closely related data:

```jac
cl import from react { useState }

cl {
    def UserProfile() -> JsxElement {
        # Good: Related data in one object
        [user, setUser] = useState({
            "name": "",
            "username": "",
            "avatar": ""
        });

        def updateName(name: str) -> None {
            setUser({...user, "name": name});
        }

        return <div>
            <input value={user.name} onChange={lambda e: any -> None {
                updateName(e.target.value);
            }} />
        </div>;
    }
}
```

---

## State Composition Patterns

### Pattern 1: Feature-Based State

Organize state by feature or domain using multiple `useState` calls:

```jac
cl import from react { useState, useEffect }

cl {
    def App() -> JsxElement {
        # User state
        [user, setUser] = useState(None);
        [isLoggedIn, setIsLoggedIn] = useState(False);

        # Todo state
        [todos, setTodos] = useState([]);
        [selectedId, setSelectedId] = useState(None);

        # UI state
        [theme, setTheme] = useState("light");
        [sidebarOpen, setSidebarOpen] = useState(False);
        [modalOpen, setModalOpen] = useState(False);

        # Settings state
        [notifications, setNotifications] = useState(True);
        [language, setLanguage] = useState("en");

        useEffect(lambda -> None {
            async def loadData() -> None {
                result = root spawn get_user_data();
                setUser(result.user);
                setIsLoggedIn(True);
            }
            loadData();
        }, []);

        return <div className={theme}>
            {sidebarOpen and <Sidebar />}
            {todos.length > 0 and <TodoList items={todos} />}
        </div>;
    }

    def app() -> JsxElement {
        return <App />;
    }
}
```

### Pattern 2: Local vs Global State

Use Context for global state and `useState` for local state:

```jac
cl import from react { useState, useContext, createContext }

cl {
    # Create context for global state
    AppContext = createContext(None);

    def App() -> JsxElement {
        # Global state
        [currentUser, setCurrentUser] = useState(None);
        [theme, setTheme] = useState("light");

        appValue = {
            "currentUser": currentUser,
            "theme": theme,
            "setCurrentUser": setCurrentUser,
            "setTheme": setTheme
        };

        return <AppContext.Provider value={appValue}>
            <TodoForm />
            <TodoList />
        </AppContext.Provider>;
    }

    # Component with local state
    def TodoForm() -> JsxElement {
        # Access global context
        app = useContext(AppContext);

        # Local component state
        [text, setText] = useState("");
        [valid, setValid] = useState(False);

        def validate(value: str) -> None {
            setValid(len(value.trim()) > 0);
        }

        return <form>
            <input
                value={text}
                onChange={lambda e: any -> None {
                    newText = e.target.value;
                    setText(newText);
                    validate(newText);
                }}
                style={{"background": ("#333" if app.theme == "dark" else "#fff")}}
            />
        </form>;
    }

    def TodoList() -> JsxElement {
        # Local list state
        [sortBy, setSortBy] = useState("date");
        [order, setOrder] = useState("asc");

        # Access global context
        app = useContext(AppContext);

        return <div>
            <h2>Welcome, {app.currentUser.name if app.currentUser else "Guest"}</h2>
        </div>;
    }

    def app() -> JsxElement {
        return <App />;
    }
}
```

### Pattern 3: Custom Hooks (State Modules)

Create reusable custom hooks for shared logic:

```jac
cl import from react { useState, useEffect }
cl import from '@jac/runtime' { jacLogout }

cl {
    # Custom hook: User management
    def useUser() -> dict {
        [user, setUser] = useState(None);
        [loading, setLoading] = useState(False);
        [error, setError] = useState(None);

        async def loadUser() -> None {
            setLoading(True);
            setError(None);
            try {
                result = root spawn get_current_user();
                setUser(result);
            } catch (err) {
                setError(err);
            } finally {
                setLoading(False);
            }
        }

        def logout() -> None {
            jacLogout();
            setUser(None);
        }

        useEffect(lambda -> None {
            loadUser();
        }, []);

        return {
            "user": user,
            "loading": loading,
            "error": error,
            "logout": logout,
            "reload": loadUser
        };
    }

    # Custom hook: Todo management
    def useTodos() -> dict {
        [todos, setTodos] = useState([]);
        [loading, setLoading] = useState(False);

        async def loadTodos() -> None {
            setLoading(True);
            try {
                result = root spawn read_todos();
                setTodos(result.reports);
            } finally {
                setLoading(False);
            }
        }

        async def addTodo(text: str) -> None {
            response = root spawn create_todo(text=text);
            new_todo = response.reports[0][0];
            setTodos(todos.concat([new_todo]));
        }

        async def toggleTodo(id: str) -> None {
            id spawn toggle_todo();
            setTodos(todos.map(lambda todo: any -> any {
                if todo._jac_id == id {
                    return {...todo, "done": not todo.done};
                }
                return todo;
            }));
        }

        useEffect(lambda -> None {
            loadTodos();
        }, []);

        return {
            "todos": todos,
            "loading": loading,
            "addTodo": addTodo,
            "toggleTodo": toggleTodo,
            "reload": loadTodos
        };
    }

    # Using custom hooks in components
    def TodoApp() -> JsxElement {
        userData = useUser();
        todoData = useTodos();

        if userData.loading or todoData.loading {
            return <div>Loading...</div>;
        }

        return <div>
            <h1>Welcome, {userData.user.name if userData.user else "Guest"}</h1>
            <button onClick={userData.logout}>Logout</button>
            {todoData.todos.map(lambda todo: any -> any {
                return <TodoItem key={todo._jac_id} todo={todo} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

---

## Derived State

### Computed Values with useMemo

Use `useMemo` to memoize expensive computations:

```jac
cl import from react { useState, useMemo }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");

        # Memoized filtered todos - only recomputes when todos or filter changes
        filteredTodos = useMemo(lambda -> list {
            if filter == "active" {
                return todos.filter(lambda item: any -> bool { return not item.done; });
            } elif filter == "completed" {
                return todos.filter(lambda item: any -> bool { return item.done; });
            }
            return todos;
        }, [todos, filter]);

        # Memoized stats - only recomputes when todos changes
        stats = useMemo(lambda -> dict {
            total = todos.length;
            active = todos.filter(lambda item: any -> bool { return not item.done; }).length;
            completed = total - active;

            return {
                "total": total,
                "active": active,
                "completed": completed
            };
        }, [todos]);

        return <div>
            <div>
                Total: {stats.total}, Active: {stats.active}, Completed: {stats.completed}
            </div>
            {filteredTodos.map(lambda item: any -> any {
                return <TodoItem key={item._jac_id} todo={item} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

### Simple Derived Values

For simple computations, you don't need `useMemo`:

```jac
cl import from react { useState }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");

        # Simple derived values - computed on each render
        def getFilteredTodos() -> list {
            if filter == "active" {
                return todos.filter(lambda item: any -> bool { return not item.done; });
            } elif filter == "completed" {
                return todos.filter(lambda item: any -> bool { return item.done; });
            }
            return todos;
        }

        filtered = getFilteredTodos();
        activeCount = todos.filter(lambda item: any -> bool { return not item.done; }).length;

        return <div>
            <div>{activeCount} active todos</div>
            {filtered.map(lambda item: any -> any {
                return <TodoItem key={item._jac_id} todo={item} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

### Reactive Updates with useEffect

Use `useEffect` to sync derived state or perform side effects:

```jac
cl import from react { useState, useEffect }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [stats, setStats] = useState({
            "total": 0,
            "active": 0,
            "completed": 0
        });

        # Update stats whenever todos change
        useEffect(lambda -> None {
            total = todos.length;
            active = todos.filter(lambda item: any -> bool { return not item.done; }).length;
            completed = total - active;

            setStats({
                "total": total,
                "active": active,
                "completed": completed
            });

            # Optional: Save to localStorage
            localStorage.setItem("todoStats", JSON.stringify(stats));
        }, [todos]);

        return <div>
            <StatsDisplay stats={stats} />
            {todos.map(lambda item: any -> any {
                return <TodoItem key={item._jac_id} todo={item} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

---

## Advanced React Hooks

### useReducer for Complex State

When state logic becomes complex, use `useReducer` instead of `useState`:

```jac
cl import from react { useReducer, useEffect }

cl {
    # Reducer function
    def todoReducer(state: dict, action: dict) -> dict {
        type = action.type;

        if type == "ADD_TODO" {
            return {...state, "todos": state.todos.concat([action.payload])};
        } elif type == "TOGGLE_TODO" {
            return {
                ...state,
                "todos": state.todos.map(lambda todo: any -> any {
                    if todo._jac_id == action.payload {
                        return {...todo, "done": not todo.done};
                    }
                    return todo;
                })
            };
        } elif type == "REMOVE_TODO" {
            return {
                ...state,
                "todos": state.todos.filter(lambda todo: any -> bool {
                    return todo._jac_id != action.payload;
                })
            };
        } elif type == "SET_FILTER" {
            return {...state, "filter": action.payload};
        } elif type == "SET_LOADING" {
            return {...state, "loading": action.payload};
        }

        return state;
    }

    def TodoApp() -> JsxElement {
        # Initial state
        initialState = {
            "todos": [],
            "filter": "all",
            "loading": False
        };

        [state, dispatch] = useReducer(todoReducer, initialState);

        useEffect(lambda -> None {
            async def loadTodos() -> None {
                dispatch({"type": "SET_LOADING", "payload": True});
                result = root spawn read_todos();
                for todo in result.reports {
                    dispatch({"type": "ADD_TODO", "payload": todo});
                }
                dispatch({"type": "SET_LOADING", "payload": False});
            }
            loadTodos();
        }, []);

        async def addTodo(text: str) -> None {
            response = root spawn create_todo(text=text);
            new_todo = response.reports[0][0];
            dispatch({"type": "ADD_TODO", "payload": new_todo});
        }

        def toggleTodo(id: str) -> None {
            dispatch({"type": "TOGGLE_TODO", "payload": id});
        }

        return <div>
            {state.loading and <div>Loading...</div>}
            {state.todos.map(lambda todo: any -> any {
                return <TodoItem
                    key={todo._jac_id}
                    todo={todo}
                    onToggle={lambda -> None { toggleTodo(todo._jac_id); }}
                />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

### useContext for Global State

Share state across multiple components without prop drilling:

```jac
cl import from react { useState, useContext, createContext }

cl {
    # Create context
    TodoContext = createContext(None);

    # Provider component
    def TodoProvider(props: dict) -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");

        async def addTodo(text: str) -> None {
            response = root spawn create_todo(text=text);
            new_todo = response.reports[0][0];
            setTodos(todos.concat([new_todo]));
        }

        async def toggleTodo(id: str) -> None {
            id spawn toggle_todo();
            setTodos(todos.map(lambda todo: any -> any {
                if todo._jac_id == id {
                    return {...todo, "done": not todo.done};
                }
                return todo;
            }));
        }

        value = {
            "todos": todos,
            "filter": filter,
            "setFilter": setFilter,
            "addTodo": addTodo,
            "toggleTodo": toggleTodo
        };

        return <TodoContext.Provider value={value}>
            {props.children}
        </TodoContext.Provider>;
    }

    # Hook to use context
    def useTodoContext() -> dict {
        return useContext(TodoContext);
    }

    # Components using the context
    def TodoList() -> JsxElement {
        ctx = useTodoContext();

        filteredTodos = ctx.todos.filter(lambda todo: any -> bool {
            if ctx.filter == "active" { return not todo.done; }
            if ctx.filter == "completed" { return todo.done; }
            return True;
        });

        return <div>
            {filteredTodos.map(lambda todo: any -> any {
                return <TodoItem
                    key={todo._jac_id}
                    todo={todo}
                    onToggle={lambda -> None { ctx.toggleTodo(todo._jac_id); }}
                />;
            })}
        </div>;
    }

    def FilterButtons() -> JsxElement {
        ctx = useTodoContext();

        return <div>
            <button onClick={lambda -> None { ctx.setFilter("all"); }}>All</button>
            <button onClick={lambda -> None { ctx.setFilter("active"); }}>Active</button>
            <button onClick={lambda -> None { ctx.setFilter("completed"); }}>Completed</button>
        </div>;
    }

    # App with provider
    def MainApp() -> JsxElement {
        return <TodoProvider>
            <FilterButtons />
            <TodoList />
        </TodoProvider>;
    }

    def app() -> JsxElement {
        return <MainApp />;
    }
}
```

### useCallback for Memoized Functions

Prevent unnecessary re-renders by memoizing callbacks:

```jac
cl import from react { useState, useCallback }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);

        # Memoized callback - only recreated if todos changes
        handleToggle = useCallback(lambda id: str -> None {
            setTodos(todos.map(lambda todo: any -> any {
                if todo._jac_id == id {
                    return {...todo, "done": not todo.done};
                }
                return todo;
            }));
        }, [todos]);

        return <div>
            {todos.map(lambda todo: any -> any {
                return <TodoItem
                    key={todo._jac_id}
                    todo={todo}
                    onToggle={handleToggle}
                />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

---

## State Management Patterns

### Pattern 1: Action Functions

Encapsulate state logic in reusable action functions:

```jac
cl import from react { useState }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");

        # Action functions
        async def addTodo(text: str) -> None {
            if not text.trim() { return; }
            response = root spawn create_todo(text=text);
            new_todo = response.reports[0][0];
            setTodos(todos.concat([new_todo]));
        }

        async def toggleTodo(id: str) -> None {
            id spawn toggle_todo();
            setTodos(todos.map(lambda todo: any -> any {
                if todo._jac_id == id {
                    return {...todo, "done": not todo.done};
                }
                return todo;
            }));
        }

        def removeTodo(id: str) -> None {
            setTodos(todos.filter(lambda todo: any -> bool {
                return todo._jac_id != id;
            }));
        }

        def clearCompleted() -> None {
            setTodos(todos.filter(lambda todo: any -> bool {
                return not todo.done;
            }));
        }

        return <div>
            {/* UI using these actions */}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

### Pattern 2: Selector Functions with useMemo

Create memoized selector functions for derived data:

```jac
cl import from react { useState, useMemo }

cl {
    def TodoApp() -> JsxElement {
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");

        # Memoized selectors
        filteredTodos = useMemo(lambda -> list {
            if filter == "active" {
                return todos.filter(lambda t: any -> bool { return not t.done; });
            } elif filter == "completed" {
                return todos.filter(lambda t: any -> bool { return t.done; });
            }
            return todos;
        }, [todos, filter]);

        activeTodos = useMemo(lambda -> list {
            return todos.filter(lambda t: any -> bool { return not t.done; });
        }, [todos]);

        completedTodos = useMemo(lambda -> list {
            return todos.filter(lambda t: any -> bool { return t.done; });
        }, [todos]);

        return <div>
            <div>Active: {activeTodos.length}</div>
            <div>Completed: {completedTodos.length}</div>
            {filteredTodos.map(lambda todo: any -> any {
                return <TodoItem key={todo._jac_id} todo={todo} />;
            })}
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

### Pattern 3: Combining Multiple Hooks

Combine useState, useReducer, and useContext for complex applications:

```jac
cl import from react { useState, useReducer, useContext, createContext, useEffect }

cl {
    # Context for global state
    AppContext = createContext(None);

    # Main app with combined hooks
    def App() -> JsxElement {
        # User state with useState
        [user, setUser] = useState(None);

        # Todo state with useReducer
        def todoReducer(state: dict, action: dict) -> dict {
            if action.type == "ADD" {
                return {...state, "todos": state.todos.concat([action.payload])};
            } elif action.type == "TOGGLE" {
                return {
                    ...state,
                    "todos": state.todos.map(lambda t: any -> any {
                        if t._jac_id == action.payload {
                            return {...t, "done": not t.done};
                        }
                        return t;
                    })
                };
            }
            return state;
        }

        [todoState, dispatch] = useReducer(todoReducer, {"todos": [], "loading": False});

        # UI state with useState
        [theme, setTheme] = useState("light");

        useEffect(lambda -> None {
            async def loadData() -> None {
                userData = root spawn get_user();
                setUser(userData);
            }
            loadData();
        }, []);

        contextValue = {
            "user": user,
            "setUser": setUser,
            "todoState": todoState,
            "dispatch": dispatch,
            "theme": theme,
            "setTheme": setTheme
        };

        return <AppContext.Provider value={contextValue}>
            <TodoList />
        </AppContext.Provider>;
    }

    def app() -> JsxElement {
        return <App />;
    }
}
```

---

## Complete Example: Full-Featured Todo App

Here's a complete example combining multiple React hooks and patterns:

```jac
cl import from react { useState, useEffect, useMemo, useCallback }

cl {
    def TodoApp() -> JsxElement {
        # State management
        [todos, setTodos] = useState([]);
        [filter, setFilter] = useState("all");
        [loading, setLoading] = useState(False);
        [error, setError] = useState(None);
        [user, setUser] = useState(None);
        [sidebarOpen, setSidebarOpen] = useState(False);

        # Load initial data
        useEffect(lambda -> None {
            async def loadData() -> None {
                setLoading(True);
                setError(None);
                try {
                    # Load user and todos in parallel
                    results = await Promise.all([
                        root spawn get_current_user(),
                        root spawn read_todos()
                    ]);
                    setUser(results[0]);
                    setTodos(results[1].reports);
                } catch (err) {
                    setError(err);
                } finally {
                    setLoading(False);
                }
            }
            loadData();
        }, []);

        # Memoized derived state
        filteredTodos = useMemo(lambda -> list {
            if filter == "active" {
                return todos.filter(lambda t: any -> bool { return not t.done; });
            } elif filter == "completed" {
                return todos.filter(lambda t: any -> bool { return t.done; });
            }
            return todos;
        }, [todos, filter]);

        stats = useMemo(lambda -> dict {
            total = todos.length;
            active = todos.filter(lambda t: any -> bool { return not t.done; }).length;
            return {"total": total, "active": active, "completed": total - active};
        }, [todos]);

        # Memoized action functions
        addTodo = useCallback(lambda text: str -> None {
            async def _addTodo() -> None {
                response = root spawn create_todo(text=text);
                new_todo = response.reports[0][0];
                setTodos(todos.concat([new_todo]));
            }
            _addTodo();
        }, [todos]);

        toggleTodo = useCallback(lambda id: str -> None {
            async def _toggleTodo() -> None {
                id spawn toggle_todo();
                setTodos(todos.map(lambda t: any -> any {
                    if t._jac_id == id {
                        return {...t, "done": not t.done};
                    }
                    return t;
                }));
            }
            _toggleTodo();
        }, [todos]);

        removeTodo = useCallback(lambda id: str -> None {
            setTodos(todos.filter(lambda t: any -> bool { return t._jac_id != id; }));
        }, [todos]);

        clearCompleted = useCallback(lambda -> None {
            setTodos(todos.filter(lambda t: any -> bool { return not t.done; }));
        }, [todos]);

        toggleSidebar = useCallback(lambda -> None {
            setSidebarOpen(not sidebarOpen);
        }, [sidebarOpen]);

        # Render
        if loading {
            return <div style={{"padding": "20px"}}>Loading...</div>;
        }

        if error {
            return <div style={{"padding": "20px", "color": "red"}}>
                Error: {error}
            </div>;
        }

        return <div style={{"display": "flex", "minHeight": "100vh"}}>
            # Sidebar
            {sidebarOpen and <div style={{"width": "250px", "padding": "20px", "background": "#f5f5f5"}}>
                <h3>Filter</h3>
                <button onClick={lambda -> None { setFilter("all"); }}>All ({stats.total})</button>
                <button onClick={lambda -> None { setFilter("active"); }}>Active ({stats.active})</button>
                <button onClick={lambda -> None { setFilter("completed"); }}>Completed ({stats.completed})</button>
            </div>}

            # Main content
            <div style={{"flex": "1", "padding": "20px"}}>
                # Header
                <div style={{"display": "flex", "justifyContent": "space-between", "marginBottom": "20px"}}>
                    <h1>Welcome, {user.name if user else "Guest"}</h1>
                    <button onClick={toggleSidebar}>
                        {"Hide" if sidebarOpen else "Show"} Sidebar
                    </button>
                </div>

                # Stats
                <div style={{"marginBottom": "20px"}}>
                    {stats.active} active, {stats.completed} completed, {stats.total} total
                </div>

                # Todo list
                <div>
                    {filteredTodos.map(lambda todo: any -> any {
                        return <div key={todo._jac_id} style={{"marginBottom": "10px"}}>
                            <input
                                type="checkbox"
                                checked={todo.done}
                                onChange={lambda -> None { toggleTodo(todo._jac_id); }}
                            />
                            <span style={{"marginLeft": "10px"}}>{todo.text}</span>
                            <button
                                onClick={lambda -> None { removeTodo(todo._jac_id); }}
                                style={{"marginLeft": "10px"}}
                            >
                                Delete
                            </button>
                        </div>;
                    })}
                </div>

                # Clear completed button
                {stats.completed > 0 and <button
                    onClick={clearCompleted}
                    style={{"marginTop": "20px"}}
                >
                    Clear Completed
                </button>}
            </div>
        </div>;
    }

    def app() -> JsxElement {
        return <TodoApp />;
    }
}
```

---

## Best Practices

### 1. Separate State Variables by Concern

```jac
cl import from react { useState }

#  Good: Separate state variables
def App() -> JsxElement {
    [user, setUser] = useState(None);
    [todos, setTodos] = useState([]);
    [sidebarOpen, setSidebarOpen] = useState(False);
    [theme, setTheme] = useState("light");
}

#  Avoid: One giant state object for unrelated data
def App() -> JsxElement {
    [appState, setAppState] = useState({
        "user": None,
        "todos": [],
        "sidebarOpen": False,
        "theme": "light"
    });
}
```

### 2. Use useMemo for Expensive Computations

```jac
cl import from react { useState, useMemo }

#  Good: Memoize expensive calculations
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);

    activeTodos = useMemo(lambda -> list {
        return todos.filter(lambda t: any -> bool { return not t.done; });
    }, [todos]);
}

#  Avoid: Computing on every render
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);

    # This runs on every render, even if todos hasn't changed
    activeTodos = todos.filter(lambda t: any -> bool { return not t.done; });
}
```

### 3. Don't Store Derived State

```jac
cl import from react { useState }

#  Good: Calculate derived values
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);
    activeCount = todos.filter(lambda t: any -> bool { return not t.done; }).length;
}

#  Avoid: Storing derived values in state
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);
    [activeCount, setActiveCount] = useState(0);  # Redundant!
}
```

### 4. Use useReducer for Complex State Logic

```jac
cl import from react { useReducer }

#  Good: useReducer for complex interdependent state
def TodoApp() -> JsxElement {
    def reducer(state: dict, action: dict) -> dict {
        if action.type == "ADD" {
            return {...state, "todos": state.todos.concat([action.payload]), "count": state.count + 1};
        }
        return state;
    }

    [state, dispatch] = useReducer(reducer, {"todos": [], "count": 0});
}

#  Avoid: Multiple useState for interdependent state
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);
    [count, setCount] = useState(0);
    # Risk of inconsistency - need to update both together
}
```

### 5. Always Handle Loading and Error States

```jac
cl import from react { useState, useEffect }

#  Good: Comprehensive state management
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);
    [loading, setLoading] = useState(False);
    [error, setError] = useState(None);

    useEffect(lambda -> None {
        async def loadTodos() -> None {
            setLoading(True);
            setError(None);
            try {
                result = root spawn read_todos();
                setTodos(result.reports);
            } catch (err) {
                setError(err);
            } finally {
                setLoading(False);
            }
        }
        loadTodos();
    }, []);

    if loading { return <div>Loading...</div>; }
    if error { return <div>Error: {error}</div>; }
    return <div>{/* todos */}</div>;
}
```

### 6. Use useCallback for Callbacks Passed to Children

```jac
cl import from react { useState, useCallback }

#  Good: Memoized callbacks prevent unnecessary re-renders
def TodoApp() -> JsxElement {
    [todos, setTodos] = useState([]);

    handleToggle = useCallback(lambda id: str -> None {
        setTodos(todos.map(lambda t: any -> any {
            if t._jac_id == id { return {...t, "done": not t.done}; }
            return t;
        }));
    }, [todos]);

    return <TodoList todos={todos} onToggle={handleToggle} />;
}
```

### 7. Use Context for Deeply Nested Props

```jac
cl import from react { useState, useContext, createContext }

#  Good: Context avoids prop drilling
ThemeContext = createContext("light");

def App() -> JsxElement {
    [theme, setTheme] = useState("light");
    return <ThemeContext.Provider value={theme}>
        <DeeplyNestedComponent />
    </ThemeContext.Provider>;
}

def DeeplyNestedComponent() -> JsxElement {
    theme = useContext(ThemeContext);
    return <div style={{"background": theme}}></div>;
}
```

---

## Summary

- **useState**: Use for simple, independent state variables
- **useReducer**: Use for complex, interdependent state logic
- **useContext**: Use for global state and avoiding prop drilling
- **useMemo**: Use to memoize expensive computations
- **useCallback**: Use to memoize callbacks passed to child components
- **Custom Hooks**: Create reusable state logic
- **Best Practices**: Separate concerns, avoid derived state, handle errors

React hooks provide a powerful and flexible way to manage state in Jac applications!
