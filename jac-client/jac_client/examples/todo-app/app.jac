node Todo {
    has text: str;
    has done: bool = False;
}

walker create_todo {
    can create with `root entry {
        new_todo = here ++> Todo(text="Example Todo");
        report new_todo;
    }
}
walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here;
    }
}
walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with exit {
        report here;
    }
}

cl {
    let [todoState, setTodoState] = createState({
        "items": [],
        "filter": "all",
        "input": ""
    });

    # -----------------------------
    # State helpers
    # -----------------------------
def onInputChange(e: any) -> None {
    setTodoState({"input": e.target.value});
}

async def onAddTodo(e: any) -> None {
    e.preventDefault();
    inputEl = document.getElementById("todo-input");
    text = (inputEl.value if inputEl and inputEl.value else "").trim();
    if not text { return; }

    new_todo = await __jacSpawn("create_todo", {"text": text});

    s = todoState();
    newItem = {"id": new_todo._jac_id, "text": new_todo.text, "done": new_todo.done};
    setTodoState({"items": s.items.concat([newItem])});

    # Clear the input visually
    if inputEl { inputEl.value = ""; }
}

    def setFilter(next: str) -> None {
        setTodoState({"filter": next});
    }

    async def toggleTodo(id: any) -> None {
        # we need to pass the id to the toggle_todo walker
        toggled_todo = await __jacSpawn("toggle_todo", {}, id);
        s = todoState();
        updated = [];
        for item in s.items {
            if item.id == id {
                updated.push({"id": item.id, "text": item.text, "done": not item.done});
            } else {
                updated.push(item);
            }
        }
        setTodoState({"items": updated});
    }

    def removeTodo(id: any) -> None {
        s = todoState();
        remaining = [];
        for item in s.items {
            if item.id != id { remaining.push(item); }
        }
        setTodoState({"items": remaining});
    }

    def clearCompleted() -> None {
        s = todoState();
        remaining = [];
        for item in s.items {
            if not item.done { remaining.push(item); }
        }
        setTodoState({"items": remaining});
    }

    def filteredItems() -> list {
        s = todoState();
        result = [];
        if s.filter == "active" {
            for it in s.items { if not it.done { result.push(it); } }
            return result;
        } elif s.filter == "completed" {
            for it in s.items { if it.done { result.push(it); } }
            return result;
        }
        return s.items;
    }

    # -----------------------------
    # UI pieces
    # -----------------------------
    def TodoItem(item: dict) -> any {
        console.log(item.text,"-",typeof (item.done)== 'boolean');
        return <li key={item.id} style={{
            "display": "flex",
            "gap": "12px",
            "alignItems": "center",
            "background": "#FFFFFF",
            "padding": "12px 16px",
            "borderRadius": "10px",
            "marginBottom": "8px",
            "boxShadow": "0 1px 2px rgba(17,24,39,0.06)",
            "border": "1px solid #E5E7EB"
        }}>
            <input
                type="checkbox"
                checked={item.done}

                onChange={lambda -> None { toggleTodo(item.id); }}
                style={{
                    "width": "18px",
                    "height": "18px",
                    "accentColor": "#7C3AED",
                    "cursor": "pointer"
                }}
            />
            <span style={{
                "textDecoration": ("line-through" if item.done else "none"),
                "flex": "1",
                "fontSize": "16px",
                "color": ("#9CA3AF" if item.done else "#111827")
            }}>
                {item.text}
            </span>
            <button
                style={{
                    "marginLeft": "auto",
                    "padding": "6px 12px",
                    "background": "#FFFFFF",
                    "color": "#EF4444",
                    "border": "1px solid #FCA5A5",
                    "borderRadius": "6px",
                    "fontSize": "12px",
                    "fontWeight": "600",
                    "cursor": "pointer",
                    "boxShadow": "none",
                    "transition": "all 0.2s ease"
                }}
                onClick={lambda -> None { removeTodo(item.id); }}>
                Remove
            </button>
        </li>;
    }

    def RenderUl(children: list, style: dict = {}) -> any {
        return __jacJsx("ul", {"style": style}, children);
    }

    async def read_todos_action() -> any {
        todos = await __jacSpawn("read_todos");
        for todo in todos.reports {
            console.log("Todo read:", todo);
            setTodoState({"items": todoState().items.concat([{"id": todo._jac_id, "text": todo.text, "done": todo.done}])});
        }
    }

    def TodoApp() -> any {
        s = todoState();

        onMount(lambda -> None {
            read_todos_action();
        });


        itemsArr = filteredItems();
        if not Array.isArray(itemsArr) {
            console.warn("filteredItems() did not return an array; coercing to []", itemsArr);
            itemsArr = [];
        }

        activeCount = 0;
        for it in s.items { if not it.done { activeCount += 1; } }

        children = [];
        for it in itemsArr { children.push(TodoItem(it)); }




        return <div style={{
            "maxWidth": "640px",
            "margin": "24px auto",
            "padding": "24px",
            "background": "#FFFFFF",
            "borderRadius": "12px",
            "fontFamily": "system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif",
            "boxShadow": "0 10px 20px rgba(17,24,39,0.06)",
            "border": "1px solid #E5E7EB",
            "color": "#111827"
        }}>
            <h2 style={{
                "marginTop": "0",
                "color": "#111827",
                "textAlign": "left",
                "fontSize": "1.5rem",
                "fontWeight": "700",
                "marginBottom": "16px"
            }}>My Todos</h2>

            <form id="todo_submit" onSubmit={onAddTodo} style={{
                "display": "flex",
                "gap": "12px",
                "marginBottom": "16px",
                "background": "#FFFFFF",
                "padding": "16px",
                "borderRadius": "10px",
                "border": "1px solid #E5E7EB",
                "boxShadow": "0 1px 2px rgba(17,24,39,0.04)"
            }}>
                <input
                    id="todo-input"
                    type="text"
                    placeholder="What needs to be done?"
                    style={{
                        "flex": "1",
                        "padding": "12px 14px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "outline": "none",
                        "background": "#FFFFFF",
                        "color": "#111827"
                    }}
                />
                <button type="submit" style={{
                    "padding": "12px 18px",
                    "background": "#7C3AED",
                    "color": "#FFFFFF",
                    "border": "1px solid #6D28D9",
                    "borderRadius": "8px",
                    "fontSize": "15px",
                    "fontWeight": "600",
                    "cursor": "pointer",
                    "boxShadow": "0 1px 2px rgba(124,58,237,0.3)",
                    "transition": "all 0.2s ease"
                }}>Add Todo</button>
            </form>

            <div style={{
                "display": "flex",
                "gap": "8px",
                "marginTop": "8px",
                "background": "#FFFFFF",
                "padding": "10px",
                "borderRadius": "10px",
                "border": "1px solid #E5E7EB",
                "flexWrap": "wrap"
            }}>
                <button
                    onClick={lambda -> None { setFilter("all"); }}
                    style={{
                        "padding": "8px 14px",
                        "background": ("#7C3AED" if s.filter == "all" else "#FFFFFF"),
                        "color": ("#FFFFFF" if s.filter == "all" else "#7C3AED"),
                        "border": ("1px solid #6D28D9" if s.filter == "all" else "1px solid #E5E7EB"),
                        "borderRadius": "20px",
                        "fontSize": "14px",
                        "fontWeight": ("700" if s.filter == "all" else "500"),
                        "cursor": "pointer",
                        "boxShadow": ("0 1px 2px rgba(124,58,237,0.25)" if s.filter == "all" else "none"),
                        "transition": "all 0.2s ease"
                    }}>
                    All
                </button>
                <button
                    onClick={lambda -> None { setFilter("active"); }}
                    style={{
                        "padding": "8px 14px",
                        "background": ("#7C3AED" if s.filter == "active" else "#FFFFFF"),
                        "color": ("#FFFFFF" if s.filter == "active" else "#7C3AED"),
                        "border": ("1px solid #6D28D9" if s.filter == "active" else "1px solid #E5E7EB"),
                        "borderRadius": "20px",
                        "fontSize": "14px",
                        "fontWeight": ("700" if s.filter == "active" else "500"),
                        "cursor": "pointer",
                        "boxShadow": ("0 1px 2px rgba(124,58,237,0.25)" if s.filter == "active" else "none"),
                        "transition": "all 0.2s ease"
                    }}>
                    Active
                </button>
                <button
                    onClick={lambda -> None { setFilter("completed"); }}
                    style={{
                        "padding": "8px 14px",
                        "background": ("#7C3AED" if s.filter == "completed" else "#FFFFFF"),
                        "color": ("#FFFFFF" if s.filter == "completed" else "#7C3AED"),
                        "border": ("1px solid #6D28D9" if s.filter == "completed" else "1px solid #E5E7EB"),
                        "borderRadius": "20px",
                        "fontSize": "14px",
                        "fontWeight": ("700" if s.filter == "completed" else "500"),
                        "cursor": "pointer",
                        "boxShadow": ("0 1px 2px rgba(124,58,237,0.25)" if s.filter == "completed" else "none"),
                        "transition": "all 0.2s ease"
                    }}>
                    Completed
                </button>
                <button
                    style={{
                        "marginLeft": "auto",
                        "padding": "8px 14px",
                        "background": "#F9FAFB",
                        "color": "#374151",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "20px",
                        "fontSize": "14px",
                        "fontWeight": "600",
                        "cursor": "pointer",
                        "boxShadow": "none",
                        "transition": "all 0.2s ease"
                    }}
                    onClick={clearCompleted}>
                    Clear Completed
                </button>
            </div>

            {RenderUl(children, {
                "listStyle": "none",
                "padding": "0",
                "marginTop": "12px",
                "background": "#FFFFFF",
                "borderRadius": "12px",
                "padding": "12px",
                "border": "1px solid #E5E7EB",
                "max-height": "366px",
                "overflowY": "auto"
            })}
             {[TodoItem(item) for item in items]}
            <div style={{
                "marginTop": "12px",
                "color": "#374151",
                "textAlign": "center",
                "fontSize": "14px",
                "fontWeight": "500",
                "background": "#F3F4F6",
                "padding": "8px 12px",
                "borderRadius": "10px",
                "border": "1px solid #E5E7EB"
            }}>
                {s.items.length} total, {activeCount} active
            </div>
        </div>;
    }

    # -----------------------------
    # Auth pages
    # -----------------------------
    def LoginForm() -> any {
        return <div style={{
            "maxWidth": "420px",
            "margin": "60px auto",
            "padding": "28px",
            "background": "#FFFFFF",
            "borderRadius": "12px",
            "fontFamily": "system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif",
            "boxShadow": "0 10px 20px rgba(17,24,39,0.06)",
            "border": "1px solid #E5E7EB",
            "color": "#111827"
        }}>
            <h2 style={{
                "marginTop": "0",
                "color": "#111827",
                "textAlign": "center",
                "fontSize": "1.5rem",
                "fontWeight": "700",
                "marginBottom": "20px"
            }}>Welcome Back</h2>
            <form onSubmit={handle_login}>
                <div style={{"marginBottom": "20px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "8px",
                        "color": "#374151",
                        "fontSize": "14px",
                        "fontWeight": "600"
                    }}>Username</label>
                    <input id="login-username" type="text" style={{
                        "width": "100%",
                        "padding": "12px 16px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "background": "#FFFFFF",
                        "color": "#111827",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}/>
                </div>
                <div style={{"marginBottom": "24px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "8px",
                        "color": "#374151",
                        "fontSize": "14px",
                        "fontWeight": "600"
                    }}>Password</label>
                    <input id="login-password" type="password" style={{
                        "width": "100%",
                        "padding": "12px 16px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "background": "#FFFFFF",
                        "color": "#111827",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}/>
                </div>
                <button type="submit" style={{
                    "width": "100%",
                    "padding": "12px",
                    "background": "#7C3AED",
                    "color": "#FFFFFF",
                    "border": "1px solid #6D28D9",
                    "borderRadius": "8px",
                    "fontSize": "15px",
                    "fontWeight": "600",
                    "cursor": "pointer",
                    "boxShadow": "0 1px 2px rgba(124,58,237,0.3)",
                    "transition": "all 0.2s ease"
                }}>Sign In</button>
            </form>
            <div style={{
                "marginTop": "16px",
                "textAlign": "center",
                "background": "#F9FAFB",
                "padding": "10px",
                "borderRadius": "8px",
                "border": "1px solid #E5E7EB"
            }}>
                <Link href="/signup" style={{
                    "color": "#7C3AED",
                    "textDecoration": "none",
                    "fontWeight": "500"
                }}>Create an account</Link>
            </div>
        </div>;
    }

    async def handle_login(e: any) -> None {
        e.preventDefault();
        username = document.getElementById("login-username").value;
        password = document.getElementById("login-password").value;
        success = await jacLogin(username, password);
        if success { navigate("/todos"); } else { alert("Login failed"); }
    }

    def SignupForm() -> any {
        return <div style={{
            "maxWidth": "420px",
            "margin": "60px auto",
            "padding": "28px",
            "background": "#FFFFFF",
            "borderRadius": "12px",
            "fontFamily": "system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif",
            "boxShadow": "0 10px 20px rgba(17,24,39,0.06)",
            "border": "1px solid #E5E7EB",
            "color": "#111827"
        }}>
            <h2 style={{
                "marginTop": "0",
                "color": "#111827",
                "textAlign": "center",
                "fontSize": "1.5rem",
                "fontWeight": "700",
                "marginBottom": "20px"
            }}>Join Us</h2>
            <form onSubmit={handle_signup}>
                <div style={{"marginBottom": "20px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "8px",
                        "color": "#374151",
                        "fontSize": "14px",
                        "fontWeight": "600"
                    }}>Username</label>
                    <input id="signup-username" type="text" required style={{
                        "width": "100%",
                        "padding": "12px 16px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "background": "#FFFFFF",
                        "color": "#111827",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}/>
                </div>
                <div style={{"marginBottom": "20px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "8px",
                        "color": "#374151",
                        "fontSize": "14px",
                        "fontWeight": "600"
                    }}>Password</label>
                    <input id="signup-password" type="password" required style={{
                        "width": "100%",
                        "padding": "12px 16px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "background": "#FFFFFF",
                        "color": "#111827",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}/>
                </div>
                <div style={{"marginBottom": "24px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "8px",
                        "color": "#374151",
                        "fontSize": "14px",
                        "fontWeight": "600"
                    }}>Confirm Password</label>
                    <input id="signup-password-confirm" type="password" required style={{
                        "width": "100%",
                        "padding": "12px 16px",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "8px",
                        "fontSize": "16px",
                        "background": "#FFFFFF",
                        "color": "#111827",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}/>
                </div>
                <button type="submit" style={{
                    "width": "100%",
                    "padding": "12px",
                    "background": "#7C3AED",
                    "color": "#FFFFFF",
                    "border": "1px solid #6D28D9",
                    "borderRadius": "8px",
                    "fontSize": "15px",
                    "fontWeight": "600",
                    "cursor": "pointer",
                    "boxShadow": "0 1px 2px rgba(124,58,237,0.3)",
                    "transition": "all 0.2s ease"
                }}>Create Account</button>
            </form>
            <div style={{
                "marginTop": "16px",
                "textAlign": "center",
                "background": "#F9FAFB",
                "padding": "10px",
                "borderRadius": "8px",
                "border": "1px solid #E5E7EB"
            }}>
                <Link href="/login" style={{
                    "color": "#7C3AED",
                    "textDecoration": "none",
                    "fontWeight": "500"
                }}>Already have an account? Login</Link>
            </div>
        </div>;
    }

    async def handle_signup(e: any) -> None {
        e.preventDefault();
        username = document.getElementById("signup-username").value;
        password = document.getElementById("signup-password").value;
        confirm  = document.getElementById("signup-password-confirm").value;

        if password != confirm { alert("Passwords do not match"); return; }
        if username.length < 3 { alert("Username must be at least 3 characters"); return; }
        if password.length < 6 { alert("Password must be at least 6 characters"); return; }

        result = await jacSignup(username, password);

        if result["success"] if "success" in result else False {
            alert("Account created successfully! Welcome to My Todo!");
            navigate("/todos");
        } else {
            alert(result["error"] if "error" in result else "Signup failed");
        }
    }

    def logout_action() -> None {
        jacLogout();
        setTodoState({"items": [
            {"id": 1, "text": "Sign up for an account", "done": False},
            {"id": 2, "text": "Log in", "done": False},
            {"id": 3, "text": "Add a new todo", "done": False},
            {"id": 4, "text": "Toggle a todo", "done": False},
            {"id": 5, "text": "Filter active/completed", "done": False},
            {"id": 6, "text": "Clear completed", "done": False}
        ], "filter": "all", "input": ""});
        navigate("/login");
    }

    # -----------------------------
    # Shell + Router
    # -----------------------------
    def Nav(route: str) -> any {
        if not jacIsLoggedIn() or route == "/login" or route == "/signup" { return None; }
        return <nav style={{
            "background": "#FFFFFF",
            "padding": "12px",
            "boxShadow": "0 1px 2px rgba(17,24,39,0.06)",
            "border": "1px solid #E5E7EB",
            "borderRadius": "10px"
        }}>
            <div style={{
                "maxWidth": "960px",
                "margin": "0 auto",
                "display": "flex",
                "gap": "16px",
                "alignItems": "center",
                "padding": "0 12px"
            }}>
                <Link href="/todos" style={{"textDecoration": "none"}}>
                    <span style={{
                        "color": "#111827",
                        "fontWeight": "800",
                        "fontSize": "18px"
                    }}>📝 My Todos</span>
                </Link>
                <button
                    onClick={logout_action}
                    style={{
                        "marginLeft": "auto",
                        "padding": "8px 12px",
                        "background": "#FFFFFF",
                        "color": "#374151",
                        "border": "1px solid #E5E7EB",
                        "borderRadius": "18px",
                        "cursor": "pointer",
                        "fontSize": "14px",
                        "fontWeight": "600",
                        "boxShadow": "none",
                        "transition": "all 0.2s ease"
                    }}
                >
                    Logout
                </button>

            </div>
        </nav>;
    }

    def App() -> any {
        login_route = {"path": "/login", "component": lambda -> any { return LoginForm(); }, "guard": None};
        signup_route = {"path": "/signup", "component": lambda -> any { return SignupForm(); }, "guard": None};
        todos_route  = {"path": "/todos", "component": lambda -> any { return TodoApp(); }, "guard": jacIsLoggedIn};

        routes = [login_route, signup_route, todos_route];
        router = initRouter(routes, "/login");   # changed from createRouter

        currentPath = router.path();
        return <div style={{
            "minHeight": "95vh",
            "background": "#F7F8FA",
            "padding": "24px"
        }}>
            {Nav(currentPath)}
            <div style={{"maxWidth": "960px", "margin": "0 auto", "padding": "20px"}}>
                {router.render()}
            </div>
        </div>;
    }

    def jac_app() -> any { return App(); }
}