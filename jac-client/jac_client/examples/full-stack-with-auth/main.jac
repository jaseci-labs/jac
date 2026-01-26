# Full Stack Todo App with Auth and React Router
cl import from react {
    useState,
    useEffect
}
cl import from "@jac/runtime" {
    Router,
    Routes,
    Route,
    Link,
    Navigate,
    useNavigate,
    useLocation,
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn
}

# Backend - Todo Node
node Todo {
    has text: str,
        done: bool = False;
}

# Backend - Walkers
walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with Todo entry {
        report here;
    }
}

walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}

# Frontend Components
cl {
    # Navigation
    def Navigation -> any {
        isLoggedIn = jacIsLoggedIn();
        navigate = useNavigate();

        def handleLogout(e: any) -> None {
            e.preventDefault();
            jacLogout();
            navigate("/login");
        }

        if isLoggedIn {
            return
                <nav
                    style={{
                        "padding": "12px 24px",
                        "background": "#3b82f6",
                        "color": "#ffffff",
                        "display": "flex",
                        "justifyContent": "space-between"
                    }}
                >
                    <div style={{"fontWeight": "600"}}>
                        Todo App
                    </div>
                    <div style={{"display": "flex", "gap": "16px"}}>
                        <Link
                            to="/todos"
                            style={{"color": "#ffffff", "textDecoration": "none"}}
                        >
                            Todos
                        </Link>
                        <button
                            onClick={handleLogout}
                            style={{
                                "background": "none",
                                "color": "#ffffff",
                                "border": "1px solid #ffffff",
                                "padding": "2px 10px",
                                "borderRadius": "4px",
                                "cursor": "pointer"
                            }}
                        >
                            Logout
                        </button>
                    </div>
                </nav>;
        }

        return
            <nav
                style={{
                    "padding": "12px 24px",
                    "background": "#3b82f6",
                    "color": "#ffffff",
                    "display": "flex",
                    "justifyContent": "space-between"
                }}
            >
                <div style={{"fontWeight": "600"}}>
                    Todo App
                </div>
                <div style={{"display": "flex", "gap": "16px"}}>
                    <Link
                        to="/login"
                        style={{"color": "#ffffff", "textDecoration": "none"}}
                    >
                        Login
                    </Link>
                    <Link
                        to="/signup"
                        style={{"color": "#ffffff", "textDecoration": "none"}}
                    >
                        Sign Up
                    </Link>
                </div>
            </nav>;
    }

    # Login Page
    def LoginPage -> any {
        has username: str = "",
            password: str = "",
            error: str = "";

        navigate = useNavigate();

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            error = "";
            if not username or not password {
                error = "Please fill in all fields";
                return;
            }
            success = await jacLogin(username, password);
            if success {
                navigate("/todos");
            } else {
                error = "Invalid credentials";
            }
        }

        def handleUsernameChange(e: any) -> None {
            username = e.target.value;
        }

        def handlePasswordChange(e: any) -> None {
            password = e.target.value;
        }

        errorDisplay = None;
        if error {
            errorDisplay = <div
                style={{"color": "#dc2626", "fontSize": "14px", "marginBottom": "10px"}}
            >
                {error}
            </div>;
        }

        return
            <div
                style={{
                    "minHeight": "calc(100vh - 48px)",
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "background": "#f5f5f5"
                }}
            >
                <div
                    style={{
                        "background": "#ffffff",
                        "padding": "30px",
                        "borderRadius": "8px",
                        "width": "280px",
                        "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
                    }}
                >
                    <h2 style={{"marginBottom": "20px"}}>
                        Login
                    </h2>
                    <form onSubmit={handleLogin}>
                        <input
                            type="text"
                            value={username}
                            onChange={handleUsernameChange}
                            placeholder="Username"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "marginBottom": "10px",
                                "border": "1px solid #ddd",
                                "borderRadius": "4px",
                                "boxSizing": "border-box"
                            }}
                        />
                        <input
                            type="password"
                            value={password}
                            onChange={handlePasswordChange}
                            placeholder="Password"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "marginBottom": "10px",
                                "border": "1px solid #ddd",
                                "borderRadius": "4px",
                                "boxSizing": "border-box"
                            }}
                        />
                        {errorDisplay}
                        <button
                            type="submit"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "background": "#3b82f6",
                                "color": "#ffffff",
                                "border": "none",
                                "borderRadius": "4px",
                                "cursor": "pointer",
                                "fontWeight": "600"
                            }}
                        >
                            Login
                        </button>
                    </form>
                    <p
                        style={{
                            "textAlign": "center",
                            "marginTop": "12px",
                            "fontSize": "14px"
                        }}
                    >
                        Need an account?
                        <Link to="/signup">
                            Sign up
                        </Link>
                    </p>
                </div>
            </div>;
    }

    # Signup Page
    def SignupPage -> any {
        has username: str = "",
            password: str = "",
            error: str = "";

        navigate = useNavigate();

        async def handleSignup(e: any) -> None {
            e.preventDefault();
            error = "";
            if not username or not password {
                error = "Please fill in all fields";
                return;
            }
            result = await jacSignup(username, password);
            if result["success"] {
                navigate("/todos");
            } else {
                error = result["error"] if result["error"] else "Signup failed";
            }
        }

        def handleUsernameChange(e: any) -> None {
            username = e.target.value;
        }

        def handlePasswordChange(e: any) -> None {
            password = e.target.value;
        }

        errorDisplay = None;
        if error {
            errorDisplay = <div
                style={{"color": "#dc2626", "fontSize": "14px", "marginBottom": "10px"}}
            >
                {error}
            </div>;
        }

        return
            <div
                style={{
                    "minHeight": "calc(100vh - 48px)",
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "background": "#f5f5f5"
                }}
            >
                <div
                    style={{
                        "background": "#ffffff",
                        "padding": "30px",
                        "borderRadius": "8px",
                        "width": "280px",
                        "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
                    }}
                >
                    <h2 style={{"marginBottom": "20px"}}>
                        Sign Up
                    </h2>
                    <form onSubmit={handleSignup}>
                        <input
                            type="text"
                            value={username}
                            onChange={handleUsernameChange}
                            placeholder="Username"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "marginBottom": "10px",
                                "border": "1px solid #ddd",
                                "borderRadius": "4px",
                                "boxSizing": "border-box"
                            }}
                        />
                        <input
                            type="password"
                            value={password}
                            onChange={handlePasswordChange}
                            placeholder="Password"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "marginBottom": "10px",
                                "border": "1px solid #ddd",
                                "borderRadius": "4px",
                                "boxSizing": "border-box"
                            }}
                        />
                        {errorDisplay}
                        <button
                            type="submit"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "background": "#3b82f6",
                                "color": "#ffffff",
                                "border": "none",
                                "borderRadius": "4px",
                                "cursor": "pointer",
                                "fontWeight": "600"
                            }}
                        >
                            Sign Up
                        </button>
                    </form>
                    <p
                        style={{
                            "textAlign": "center",
                            "marginTop": "12px",
                            "fontSize": "14px"
                        }}
                    >
                        Have an account?
                        <Link to="/login">
                            Login
                        </Link>
                    </p>
                </div>
            </div>;
    }

    # TodoInput Component
    def TodoInput(props: any) -> any {
        input = props.input;
        setInput = props.setInput;
        addTodo = props.addTodo;

        return
            <div style={{"display": "flex", "gap": "8px", "marginBottom": "16px"}}>
                <input
                    type="text"
                    value={input}
                    onChange={lambda e: any  -> None { setInput(e.target.value);}}
                    onKeyPress={lambda e: any  -> None { if e.key == "Enter" {
                        addTodo();
                    }}}
                    placeholder="What needs to be done?"
                    style={{
                        "flex": "1",
                        "padding": "8px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px"
                    }}
                />
                <button
                    onClick={addTodo}
                    style={{
                        "padding": "8px 16px",
                        "background": "#3b82f6",
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontWeight": "600"
                    }}
                >
                    Add
                </button>
            </div>;
    }

    # TodoFilters Component
    def TodoFilters(props: any) -> any {
        filter = props.filter;
        setFilter = props.setFilter;

        return
            <div style={{"display": "flex", "gap": "8px", "marginBottom": "16px"}}>
                <button
                    onClick={lambda -> None { setFilter("all");}}
                    style={{
                        "padding": "6px 12px",
                        "background": ("#3b82f6" if filter == "all" else "#e5e7eb"),
                        "color": ("#ffffff" if filter == "all" else "#000000"),
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontSize": "14px"
                    }}
                >
                    All
                </button>
                <button
                    onClick={lambda -> None { setFilter("active");}}
                    style={{
                        "padding": "6px 12px",
                        "background": ("#3b82f6" if filter == "active" else "#e5e7eb"),
                        "color": ("#ffffff" if filter == "active" else "#000000"),
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontSize": "14px"
                    }}
                >
                    Active
                </button>
                <button
                    onClick={lambda -> None { setFilter("completed");}}
                    style={{
                        "padding": "6px 12px",
                        "background": (
                            "#3b82f6" if filter == "completed" else "#e5e7eb"
                        ),
                        "color": ("#ffffff" if filter == "completed" else "#000000"),
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontSize": "14px"
                    }}
                >
                    Completed
                </button>
            </div>;
    }

    # TodoItem Component
    def TodoItem(props: any) -> any {
        todo = props.todo;
        toggleTodo = props.toggleTodo;
        deleteTodo = props.deleteTodo;

        return
            <div
                key={todo._jac_id}
                style={{
                    "display": "flex",
                    "alignItems": "center",
                    "gap": "10px",
                    "padding": "10px",
                    "borderBottom": "1px solid #e5e7eb"
                }}
            >
                <input
                    type="checkbox"
                    checked={todo.done}
                    onChange={lambda -> None { toggleTodo(todo._jac_id);}}
                    style={{"cursor": "pointer"}}
                />
                <span
                    style={{
                        "flex": "1",
                        "textDecoration": ("line-through" if todo.done else "none"),
                        "color": ("#999" if todo.done else "#000")
                    }}
                >
                    {todo.text}
                </span>
                <button
                    onClick={lambda -> None { deleteTodo(todo._jac_id);}}
                    style={{
                        "padding": "4px 8px",
                        "background": "#ef4444",
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontSize": "12px"
                    }}
                >
                    Delete
                </button>
            </div>;
    }

    # TodoList Component
    def TodoList(props: any) -> any {
        filteredTodos = props.filteredTodos;
        toggleTodo = props.toggleTodo;
        deleteTodo = props.deleteTodo;

        if filteredTodos.length == 0 {
            return
                <div
                    style={{"padding": "20px", "textAlign": "center", "color": "#999"}}
                >
                    No todos yet. Add one above!
                </div>;
        }

        return
            <div>
                {filteredTodos.map(
                    lambda todo: any  -> any { return
                        <TodoItem
                            key={todo._jac_id}
                            todo={todo}
                            toggleTodo={toggleTodo}
                            deleteTodo={deleteTodo}
                        />; }
                )}
            </div>;
    }

    # Todos Page (Protected)
    def TodosPage -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return
                <Navigate to="/login" />;
        }

        [todos, setTodos] = useState([]);
        [input, setInput] = useState("");
        [filter, setFilter] = useState("all");

        # Load todos on mount
        useEffect(
            lambda -> None { async def loadTodos -> None {
                result = root spawn read_todos();
                setTodos(result.reports or []);
            } loadTodos();},
            []
        );

        # Add todo
        async def addTodo -> None {
            if not input.trim() {
                return;
            }
            result = root spawn create_todo(text=input.trim());
            setTodos(todos.concat([result.reports[0][0]]));
            setInput("");
        }

        # Toggle todo
        async def toggleTodo(id: any) -> None {
            id spawn toggle_todo();
            setTodos(
                todos.map(
                    lambda todo: any  -> any { if todo._jac_id == id {
                        return {
                            "_jac_id": todo._jac_id,
                            "text": todo.text,
                            "done": not todo.done
                        };
                    }return todo; }
                )
            );
        }

        # Delete todo
        async def deleteTodo(id: any) -> None {
            #id spawn delete_todo();
            setTodos(
                todos.filter(lambda todo: any  -> bool { return todo._jac_id != id; })
            );
        }

        # Filter todos
        def getFilteredTodos -> list {
            if filter == "active" {
                return todos.filter(
                    lambda todo: any  -> bool { return not todo.done; }
                );
            } elif filter == "completed" {
                return todos.filter(lambda todo: any  -> bool { return todo.done; });
            }
            return todos;
        }

        filteredTodos = getFilteredTodos();
        activeCount = todos.filter(lambda todo: any  -> bool { return not todo.done; }).length;

        return
            <div
                style={{
                    "maxWidth": "600px",
                    "margin": "20px auto",
                    "padding": "20px",
                    "background": "#ffffff",
                    "borderRadius": "8px",
                    "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
                }}
            >
                <h1 style={{"marginBottom": "20px"}}>
                    My Todos
                </h1>
                <TodoInput input={input} setInput={setInput} addTodo={addTodo} />
                <TodoFilters filter={filter} setFilter={setFilter} />
                <TodoList
                    filteredTodos={filteredTodos}
                    toggleTodo={toggleTodo}
                    deleteTodo={deleteTodo}
                />
                {(
                    <div
                        style={{
                            "marginTop": "16px",
                            "padding": "10px",
                            "background": "#f9fafb",
                            "borderRadius": "4px",
                            "fontSize": "14px",
                            "color": "#666"
                        }}
                    >
                        {activeCount}{"item" if activeCount == 1 else "items"}left
                    </div>
                )
                if todos.length > 0
                else None}
            </div>;
    }

    # Home/Landing Page - auto-redirect
    def HomePage -> any {
        if jacIsLoggedIn() {
            return
                <Navigate to="/todos" />;
        }
        return
            <Navigate to="/login" />;
    }

    # Main App with React Router
    def:pub app -> any {
        return
            <Router>
                <div style={{"fontFamily": "system-ui, sans-serif"}}>
                    <Navigation />
                    <Routes>
                        <Route path="/" element={<HomePage />} />
                        <Route path="/login" element={<LoginPage />} />
                        <Route path="/signup" element={<SignupPage />} />
                        <Route path="/todos" element={<TodosPage />} />
                    </Routes>
                </div>
            </Router>;
    }
}
# Add todo input

# Filter buttons

# Todo list

# Stats
