# Authentication

Add user login, signup, and protected routes to your Jac application.

> **Prerequisites**
>
> - Completed: [Backend Integration](backend.md)
> - Time: ~30 minutes

---

## Overview

Authentication in Jac works across both backend approaches. Use `def:priv` (private functions) or `walker:priv` (private walkers) to create per-user endpoints where each user gets their own isolated data graph. The frontend uses built-in runtime functions to handle login/signup/logout.

!!! tip "See it in action"
    The [AI Day Planner tutorial (Part 6)](../first-app/build-ai-day-planner.md#part-6-multi-user-support) walks through adding authentication to a complete app, including per-user data isolation.

Jac provides **built-in authentication** with these runtime functions:

| Function | Description |
|----------|-------------|
| `jacLogin(username, password)` | Login user, returns `bool` |
| `jacSignup(username, password)` | Register user, returns `dict` with `success` key |
| `jacLogout()` | Clear auth token |
| `jacIsLoggedIn()` | Check if user is authenticated |

```jac
cl import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
```

---

## Quick Start: Simple Login

```jac
cl import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, useNavigate }

cl {
    def:pub LoginPage() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";
        has loading: bool = False;

        navigate = useNavigate();

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            error = "";

            if not username or not password {
                error = "Please fill in all fields";
                return;
            }

            loading = True;
            success = await jacLogin(username, password);
            loading = False;

            if success {
                navigate("/");
            } else {
                error = "Invalid credentials";
            }
        }

        return <div style={{"maxWidth": "400px", "margin": "0 auto", "padding": "2rem"}}>
            <h2>Login</h2>
            <form onSubmit={handleLogin}>
                {error and <div style={{"color": "red", "marginBottom": "1rem"}}>{error}</div>}

                <input
                    type="text"
                    value={username}
                    onChange={lambda e: any -> None { username = e.target.value; }}
                    placeholder="Username"
                    style={{"width": "100%", "padding": "0.5rem", "marginBottom": "1rem"}}
                />

                <input
                    type="password"
                    value={password}
                    onChange={lambda e: any -> None { password = e.target.value; }}
                    placeholder="Password"
                    style={{"width": "100%", "padding": "0.5rem", "marginBottom": "1rem"}}
                />

                <button
                    type="submit"
                    disabled={loading}
                    style={{"width": "100%", "padding": "0.5rem"}}
                >
                    {loading and "Logging in..." or "Login"}
                </button>
            </form>
        </div>;
    }
}
```

---

## Built-in Auth Functions

### jacLogin

Authenticates a user and stores the JWT token.

```jac
cl import from "@jac/runtime" { jacLogin }

cl {
    async def handleLogin() -> None {
        # jacLogin returns bool (True = success, False = failure)
        success = await jacLogin(username, password);

        if success {
            # User is now logged in, token stored automatically
            navigate("/dashboard");
        } else {
            error = "Invalid credentials";
        }
    }
}
```

### jacSignup

Registers a new user account.

```jac
cl import from "@jac/runtime" { jacSignup }

cl {
    async def handleSignup() -> None {
        # jacSignup returns dict with success key
        result = await jacSignup(username, password);

        if result["success"] {
            # User registered and logged in
            navigate("/dashboard");
        } else {
            error = result["error"] or "Signup failed";
        }
    }
}
```

### jacLogout

Clears the authentication token.

```jac
cl import from "@jac/runtime" { jacLogout }

cl {
    def handleLogout() -> None {
        jacLogout();
        # User is now logged out
        navigate("/login");
    }
}
```

### jacIsLoggedIn

Checks if user is currently authenticated.

```jac
cl import from "@jac/runtime" { jacIsLoggedIn }

cl {
    def:pub NavBar() -> any {
        isLoggedIn = jacIsLoggedIn();

        return <nav>
            {isLoggedIn and (
                <button onClick={lambda -> None { handleLogout(); }}>Logout</button>
            ) or (
                <a href="/login">Login</a>
            )}
        </nav>;
    }
}
```

---

## Complete Auth Example

```jac
cl import from "@jac/runtime" {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn,
    Router,
    Routes,
    Route,
    Link,
    useNavigate
}

cl {
    # === Login Page ===
    def:pub LoginPage() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";
        has loading: bool = False;

        navigate = useNavigate();

        # Check if already logged in
        can with entry {
            if jacIsLoggedIn() {
                navigate("/");
            }
        }

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            error = "";

            if not username.trim() or not password {
                error = "Please fill in all fields";
                return;
            }

            loading = True;
            success = await jacLogin(username, password);
            loading = False;

            if success {
                navigate("/");
            } else {
                error = "Invalid username or password";
            }
        }

        return <div style={{"maxWidth": "400px", "margin": "2rem auto", "padding": "2rem"}}>
            <h2>Login</h2>
            <form onSubmit={handleLogin}>
                {error and <div style={{"color": "#dc2626", "marginBottom": "1rem"}}>{error}</div>}

                <div style={{"marginBottom": "1rem"}}>
                    <input
                        type="text"
                        value={username}
                        onChange={lambda e: any -> None { username = e.target.value; }}
                        placeholder="Username"
                        style={{"width": "100%", "padding": "0.75rem", "border": "1px solid #ddd", "borderRadius": "4px"}}
                    />
                </div>

                <div style={{"marginBottom": "1rem"}}>
                    <input
                        type="password"
                        value={password}
                        onChange={lambda e: any -> None { password = e.target.value; }}
                        placeholder="Password"
                        style={{"width": "100%", "padding": "0.75rem", "border": "1px solid #ddd", "borderRadius": "4px"}}
                    />
                </div>

                <button
                    type="submit"
                    disabled={loading}
                    style={{
                        "width": "100%",
                        "padding": "0.75rem",
                        "background": "#3b82f6",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer"
                    }}
                >
                    {loading and "Logging in..." or "Login"}
                </button>

                <p style={{"textAlign": "center", "marginTop": "1rem"}}>
                    Need an account? <Link to="/signup">Sign up</Link>
                </p>
            </form>
        </div>;
    }

    # === Signup Page ===
    def:pub SignupPage() -> any {
        has username: str = "";
        has password: str = "";
        has confirmPassword: str = "";
        has error: str = "";
        has loading: bool = False;

        navigate = useNavigate();

        async def handleSignup(e: any) -> None {
            e.preventDefault();
            error = "";

            if not username.trim() or not password {
                error = "Please fill in all fields";
                return;
            }

            if password != confirmPassword {
                error = "Passwords don't match";
                return;
            }

            if password.length < 6 {
                error = "Password must be at least 6 characters";
                return;
            }

            loading = True;
            result = await jacSignup(username, password);
            loading = False;

            if result["success"] {
                navigate("/");
            } else {
                error = result["error"] or "Signup failed";
            }
        }

        return <div style={{"maxWidth": "400px", "margin": "2rem auto", "padding": "2rem"}}>
            <h2>Create Account</h2>
            <form onSubmit={handleSignup}>
                {error and <div style={{"color": "#dc2626", "marginBottom": "1rem"}}>{error}</div>}

                <div style={{"marginBottom": "1rem"}}>
                    <input
                        type="text"
                        value={username}
                        onChange={lambda e: any -> None { username = e.target.value; }}
                        placeholder="Username"
                        style={{"width": "100%", "padding": "0.75rem", "border": "1px solid #ddd", "borderRadius": "4px"}}
                    />
                </div>

                <div style={{"marginBottom": "1rem"}}>
                    <input
                        type="password"
                        value={password}
                        onChange={lambda e: any -> None { password = e.target.value; }}
                        placeholder="Password"
                        style={{"width": "100%", "padding": "0.75rem", "border": "1px solid #ddd", "borderRadius": "4px"}}
                    />
                </div>

                <div style={{"marginBottom": "1rem"}}>
                    <input
                        type="password"
                        value={confirmPassword}
                        onChange={lambda e: any -> None { confirmPassword = e.target.value; }}
                        placeholder="Confirm Password"
                        style={{"width": "100%", "padding": "0.75rem", "border": "1px solid #ddd", "borderRadius": "4px"}}
                    />
                </div>

                <button
                    type="submit"
                    disabled={loading}
                    style={{
                        "width": "100%",
                        "padding": "0.75rem",
                        "background": "#10b981",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer"
                    }}
                >
                    {loading and "Creating account..." or "Sign Up"}
                </button>

                <p style={{"textAlign": "center", "marginTop": "1rem"}}>
                    Already have an account? <Link to="/login">Login</Link>
                </p>
            </form>
        </div>;
    }

    # === Protected Dashboard ===
    def:pub Dashboard() -> any {
        navigate = useNavigate();

        # Redirect if not logged in
        can with entry {
            if not jacIsLoggedIn() {
                navigate("/login");
            }
        }

        def handleLogout() -> None {
            jacLogout();
            navigate("/login");
        }

        if not jacIsLoggedIn() {
            return <p>Redirecting...</p>;
        }

        return <div style={{"padding": "2rem"}}>
            <h1>Dashboard</h1>
            <p>Welcome! You are logged in.</p>
            <button
                onClick={lambda -> None { handleLogout(); }}
                style={{
                    "padding": "0.5rem 1rem",
                    "background": "#ef4444",
                    "color": "white",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer"
                }}
            >
                Logout
            </button>
        </div>;
    }

    # === Main App ===
    def:pub app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/signup" element={<SignupPage />} />
            </Routes>
        </Router>;
    }
}
```

---

## Using AuthGuard for Protected Routes

For file-based routing, use the built-in `AuthGuard` component:

```jac
cl import from "@jac/runtime" { AuthGuard, Outlet }

# pages/(auth)/layout.jac - Protects all routes in (auth) group
cl {
    def:pub layout() -> any {
        return <AuthGuard redirect="/login">
            <Outlet />
        </AuthGuard>;
    }
}
```

The `AuthGuard` component:

- Checks if user is logged in via `jacIsLoggedIn()`
- If authenticated: renders child routes via `<Outlet />`
- If not authenticated: redirects to the specified path

---

## Custom Auth Context (Advanced)

For complex apps that need shared auth state across components:

```jac
cl {
    import from react { createContext, useContext }

    glob AuthContext = createContext(None);

    # Auth Provider component
    def:pub AuthProvider(props: dict) -> JsxElement {
        has user: any = None;
        has loading: bool = True;

        can with entry {
            # Check auth status on mount
            if jacIsLoggedIn() {
                # Optionally fetch user data from backend
                user = {"authenticated": True};
            }
            loading = False;
        }

        async def login(username: str, password: str) -> bool {
            success = await jacLogin(username, password);
            if success {
                user = {"authenticated": True};
            }
            return success;
        }

        def logout() -> None {
            jacLogout();
            user = None;
        }

        value = {
            "user": user,
            "loading": loading,
            "isAuthenticated": user != None,
            "login": login,
            "logout": logout
        };

        return <AuthContext.Provider value={value}>
            {props.children}
        </AuthContext.Provider>;
    }

    def useAuth() -> any {
        return useContext(AuthContext);
    }
}
```

---

## Key Takeaways

| Function | Returns | Description |
|----------|---------|-------------|
| `jacLogin(user, pass)` | `bool` | Login, returns True on success |
| `jacSignup(user, pass)` | `dict` | Signup, returns `{success: bool, ...}` |
| `jacLogout()` | `void` | Clear auth token |
| `jacIsLoggedIn()` | `bool` | Check auth status |
| `AuthGuard` | component | Protect routes in file-based routing |

---

## Next Steps

- [Routing](routing.md) - Multi-page applications with file-based routing
- [Backend Integration](backend.md) - Calling walkers from frontend
