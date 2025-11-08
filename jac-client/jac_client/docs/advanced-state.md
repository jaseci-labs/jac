# Advanced State Management in Jac

Learn how to combine multiple `createState()` calls, manage complex state patterns, and build scalable state architectures.

---

## 📚 Table of Contents

- [Multiple State Instances](#multiple-state-instances)
- [State Composition Patterns](#state-composition-patterns)
- [Derived State](#derived-state)
- [State Management Patterns](#state-management-patterns)
- [Best Practices](#best-practices)

---

## Multiple State Instances

### Basic Multiple State Pattern

Instead of putting everything in one state object, you can split state into multiple instances:

```jac
cl {
    # Separate concerns into different state instances
    let [todoState, setTodoState] = createState({
        "items": []
    });

    let [filterState, setFilterState] = createState({
        "filter": "all"
    });

    let [uiState, setUiState] = createState({
        "loading": False,
        "error": None
    });

    def TodoApp() -> any {
        todos = todoState();
        filter = filterState();
        ui = uiState();

        return <div>
            {ui.loading and <div>Loading...</div>}
            {ui.error and <div>Error: {ui.error}</div>}
            {[TodoItem(item) for item in todos.items]}
        </div>;
    }
}
```

**Benefits:**
- **Separation of Concerns**: Each state manages one aspect
- **Selective Updates**: Only components using specific state re-render
- **Easier Testing**: Test each state independently
- **Better Organization**: Clearer code structure

---

## State Composition Patterns

### Pattern 1: Feature-Based State

Organize state by feature or domain:

```jac
cl {
    # User state
    let [userState, setUserState] = createState({
        "profile": None,
        "isLoggedIn": False
    });

    # Todo state
    let [todoState, setTodoState] = createState({
        "items": [],
        "selectedId": None
    });

    # UI state
    let [uiState, setUiState] = createState({
        "theme": "light",
        "sidebarOpen": False,
        "modalOpen": False
    });

    # Settings state
    let [settingsState, setSettingsState] = createState({
        "notifications": True,
        "language": "en"
    });

    def App() -> any {
        user = userState();
        todos = todoState();
        ui = uiState();
        settings = settingsState();

        return <div className={ui.theme}>
            {ui.sidebarOpen and <Sidebar />}
            {todos.items.length > 0 and <TodoList items={todos.items} />}
        </div>;
    }
}
```

### Pattern 2: Local vs Global State

Use different state instances for different scopes:

```jac
cl {
    # Global application state
    let [appState, setAppState] = createState({
        "currentUser": None,
        "theme": "light"
    });

    # Component-specific state (can be defined inside components)
    def TodoForm() -> any {
        # Local component state
        let [formState, setFormState] = createState({
            "text": "",
            "valid": False
        });

        def validate() -> None {
            text = formState().text;
            setFormState({"valid": len(text.trim()) > 0});
        }

        return <form>
            <input
                value={formState().text}
                onChange={lambda e: any -> None {
                    setFormState({"text": e.target.value});
                    validate();
                }}
            />
        </form>;
    }

    def TodoList() -> any {
        # Local list state
        let [listState, setListState] = createState({
            "sortBy": "date",
            "order": "asc"
        });

        todos = appState().todos;
        sorted = sortTodos(todos, listState());

        return <div>
            {[TodoItem(item) for item in sorted]}
        </div>;
    }
}
```

### Pattern 3: State Modules

Create reusable state modules:

```jac
cl {
    # State module: User management
    let [userState, setUserState] = createState({
        "currentUser": None,
        "isLoading": False,
        "error": None
    });

    async def loadUser() -> None {
        setUserState({"isLoading": True, "error": None});
        try {
            user = await __jacSpawn("get_current_user");
            setUserState({"currentUser": user, "isLoading": False});
        } except Exception as err {
            setUserState({"error": str(err), "isLoading": False});
        }
    }

    def logout() -> None {
        jacLogout();
        setUserState({"currentUser": None});
    }

    # State module: Todo management
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "loading": False
    });

    async def loadTodos() -> None {
        setTodoState({"loading": True});
        try {
            todos = await __jacSpawn("read_todos");
            setTodoState({"items": todos.reports, "loading": False});
        } except Exception as err {
            setTodoState({"loading": False});
        }
    }

    async def addTodo(text: str) -> None {
        new_todo = await __jacSpawn("create_todo", {"text": text});
        s = todoState();
        setTodoState({"items": s.items.concat([new_todo])});
    }
}
```

---

## Derived State

### Computed Values from Multiple States

Combine multiple states to create derived values:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": []
    });

    let [filterState, setFilterState] = createState({
        "filter": "all"
    });

    def getFilteredTodos() -> list {
        todos = todoState();
        filter = filterState();

        if filter == "active" {
            return [item for item in todos.items if not item.done];
        } elif filter == "completed" {
            return [item for item in todos.items if item.done];
        }
        return todos.items;
    }

    def getStats() -> dict {
        todos = todoState();
        total = len(todos.items);
        active = len([item for item in todos.items if not item.done]);
        completed = total - active;

        return {
            "total": total,
            "active": active,
            "completed": completed
        };
    }

    def TodoApp() -> any {
        filtered = getFilteredTodos();
        stats = getStats();

        return <div>
            <div>
                Total: {stats.total}, Active: {stats.active}, Completed: {stats.completed}
            </div>
            {[TodoItem(item) for item in filtered]}
        </div>;
    }
}
```

### Reactive Derived State

Use `createEffect()` for reactive derived state:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": []
    });

    let [statsState, setStatsState] = createState({
        "total": 0,
        "active": 0,
        "completed": 0
    });

    # Automatically update stats when todos change
    createEffect(lambda -> None {
        todos = todoState();
        total = len(todos.items);
        active = len([item for item in todos.items if not item.done]);
        completed = total - active;

        setStatsState({
            "total": total,
            "active": active,
            "completed": completed
        });
    });

    def TodoApp() -> any {
        todos = todoState();
        stats = statsState();

        return <div>
            <StatsDisplay stats={stats} />
            {[TodoItem(item) for item in todos.items]}
        </div>;
    }
}
```

---

## State Management Patterns

### Pattern 1: State Reducers

Create reducer-like functions for complex state updates:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "input": ""
    });

    def todoReducer(action: str, payload: any) -> None {
        s = todoState();

        if action == "ADD_TODO" {
            newItem = {
                "id": payload.id,
                "text": payload.text,
                "done": False
            };
            setTodoState({"items": s.items.concat([newItem])});

        } elif action == "TOGGLE_TODO" {
            updated = [item for item in s.items {
                if item.id == payload.id {
                    return {"id": item.id, "text": item.text, "done": not item.done};
                }
                return item;
            }];
            setTodoState({"items": updated});

        } elif action == "REMOVE_TODO" {
            remaining = [item for item in s.items if item.id != payload.id];
            setTodoState({"items": remaining});

        } elif action == "SET_FILTER" {
            setTodoState({"filter": payload.filter});

        } elif action == "CLEAR_COMPLETED" {
            remaining = [item for item in s.items if not item.done];
            setTodoState({"items": remaining});
        }
    }

    async def addTodo(text: str) -> None {
        new_todo = await __jacSpawn("create_todo", {"text": text});
        todoReducer("ADD_TODO", {
            "id": new_todo._jac_id,
            "text": new_todo.text
        });
    }

    async def toggleTodo(id: str) -> None {
        await __jacSpawn("toggle_todo", {}, id);
        todoReducer("TOGGLE_TODO", {"id": id});
    }

    def setFilter(filter: str) -> None {
        todoReducer("SET_FILTER", {"filter": filter});
    }
}
```

### Pattern 2: State Selectors

Create selector functions to extract specific state slices:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "loading": False,
        "error": None
    });

    # Selectors
    def getTodos() -> list {
        return todoState().items;
    }

    def getActiveTodos() -> list {
        return [item for item in todoState().items if not item.done];
    }

    def getCompletedTodos() -> list {
        return [item for item in todoState().items if item.done];
    }

    def getFilteredTodos() -> list {
        s = todoState();
        if s.filter == "active" {
            return getActiveTodos();
        } elif s.filter == "completed" {
            return getCompletedTodos();
        }
        return getTodos();
    }

    def isLoading() -> bool {
        return todoState().loading;
    }

    def getError() -> str | None {
        return todoState().error;
    }
}
```

### Pattern 3: State Actions

Create action functions that encapsulate state updates:

```jac
cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all"
    });

    # Action creators
    async def createTodoAction(text: str) -> None {
        if not text.trim() {
            return;
        }

        new_todo = await __jacSpawn("create_todo", {"text": text});
        s = todoState();
        newItem = {
            "id": new_todo._jac_id,
            "text": new_todo.text,
            "done": new_todo.done
        };
        setTodoState({"items": s.items.concat([newItem])});
    }

    async def toggleTodoAction(id: str) -> None {
        await __jacSpawn("toggle_todo", {}, id);
        s = todoState();
        updated = [item for item in s.items {
            if item.id == id {
                return {"id": item.id, "text": item.text, "done": not item.done};
            }
            return item;
        }];
        setTodoState({"items": updated});
    }

    def removeTodoAction(id: str) -> None {
        s = todoState();
        remaining = [item for item in s.items if item.id != id];
        setTodoState({"items": remaining});
    }

    def setFilterAction(filter: str) -> None {
        setTodoState({"filter": filter});
    }

    def clearCompletedAction() -> None {
        s = todoState();
        remaining = [item for item in s.items if not item.done];
        setTodoState({"items": remaining});
    }
}
```

---

## Complete Example: Multi-State Todo App

Here's a complete example combining multiple state patterns:

```jac
cl {
    # User state
    let [userState, setUserState] = createState({
        "profile": None,
        "isLoading": False
    });

    # Todo state
    let [todoState, setTodoState] = createState({
        "items": [],
        "loading": False,
        "error": None
    });

    # Filter state
    let [filterState, setFilterState] = createState({
        "filter": "all"
    });

    # UI state
    let [uiState, setUiState] = createState({
        "sidebarOpen": False,
        "modalOpen": False
    });

    # Derived state functions
    def getFilteredTodos() -> list {
        todos = todoState();
        filter = filterState();

        if filter == "active" {
            return [item for item in todos.items if not item.done];
        } elif filter == "completed" {
            return [item for item in todos.items if item.done];
        }
        return todos.items;
    }

    def getStats() -> dict {
        todos = todoState();
        total = len(todos.items);
        active = len([item for item in todos.items if not item.done]);
        completed = total - active;

        return {"total": total, "active": active, "completed": completed};
    }

    # Actions
    async def loadTodos() -> None {
        setTodoState({"loading": True, "error": None});
        try {
            todos = await __jacSpawn("read_todos");
            items = [{
                "id": todo._jac_id,
                "text": todo.text,
                "done": todo.done
            } for todo in todos.reports];
            setTodoState({"items": items, "loading": False});
        } except Exception as err {
            setTodoState({"error": str(err), "loading": False});
        }
    }

    async def addTodo(text: str) -> None {
        new_todo = await __jacSpawn("create_todo", {"text": text});
        s = todoState();
        newItem = {
            "id": new_todo._jac_id,
            "text": new_todo.text,
            "done": new_todo.done
        };
        setTodoState({"items": s.items.concat([newItem])});
    }

    def setFilter(filter: str) -> None {
        setFilterState({"filter": filter});
    }

    def toggleSidebar() -> None {
        s = uiState();
        setUiState({"sidebarOpen": not s.sidebarOpen});
    }

    # Components
    def TodoApp() -> any {
        onMount(lambda -> None {
            loadTodos();
        });

        todos = todoState();
        filter = filterState();
        ui = uiState();

        if todos.loading {
            return <div>Loading...</div>;
        }

        if todos.error {
            return <div>Error: {todos.error}</div>;
        }

        filtered = getFilteredTodos();
        stats = getStats();

        return <div>
            <Header stats={stats} onToggleSidebar={toggleSidebar} />
            {ui.sidebarOpen and <Sidebar filter={filter} onSetFilter={setFilter} />}
            <TodoList items={filtered} />
        </div>;
    }
}
```

---

## Best Practices

### 1. Separate Concerns

```jac
# ✅ Good: Separate state by concern
let [userState, setUserState] = createState({"profile": None});
let [todoState, setTodoState] = createState({"items": []});
let [uiState, setUiState] = createState({"sidebarOpen": False});

# ❌ Avoid: Mixing unrelated state
let [appState, setAppState] = createState({
    "user": None,
    "todos": [],
    "sidebarOpen": False,
    "theme": "light"
});
```

### 2. Keep State Flat

```jac
# ✅ Good: Flat state structure
let [todoState, setTodoState] = createState({
    "items": [],
    "loading": False
});

# ❌ Avoid: Deeply nested state
let [appState, setAppState] = createState({
    "data": {
        "todos": {
            "items": [],
            "meta": {
                "loading": False
            }
        }
    }
});
```

### 3. Use Selectors for Computed Values

```jac
# ✅ Good: Computed values via functions
def getActiveTodos() -> list {
    return [item for item in todoState().items if not item.done];
}

# ❌ Avoid: Storing computed values in state
let [todoState, setTodoState] = createState({
    "items": [],
    "activeTodos": []  # Computed, shouldn't be in state
});
```

### 4. Encapsulate State Updates

```jac
# ✅ Good: Action functions
async def addTodo(text: str) -> None {
    new_todo = await __jacSpawn("create_todo", {"text": text});
    # Update state
    setTodoState(/* ... */);
}

# ❌ Avoid: Direct state updates everywhere
def Component() -> any {
    # Don't call setTodoState directly here
    # Use action functions instead
}
```

### 5. Handle Loading and Error States

```jac
# ✅ Good: Include loading/error in state
let [todoState, setTodoState] = createState({
    "items": [],
    "loading": False,
    "error": None
});

# ❌ Avoid: Missing error handling
let [todoState, setTodoState] = createState({
    "items": []
});
```

---

## Summary

- **Multiple States**: Split state by concern for better organization
- **State Composition**: Combine multiple states for complex applications
- **Derived State**: Compute values from multiple states using functions
- **State Patterns**: Use reducers, selectors, and actions for complex state
- **Best Practices**: Keep state flat, separate concerns, handle errors

Advanced state management helps you build scalable, maintainable applications! 🚀

