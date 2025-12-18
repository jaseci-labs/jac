#
# Combined example: auth + routing + CSS styling + asset serving + nested folder imports
#
cl import from react { useState, useEffect }
cl import from "@jac-client/utils" {
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

# Pure CSS + asset-in-CSS example
cl import ".styles.css";

# Nested folder imports (same pattern as nested-basic/)
cl import from .components.button {
    CustomButton
}
cl import from .button { CustomButtonRoot }

# TypeScript component import
cl import from ".components/Card.tsx" { Card }

#
# Basic backend walkers
#
node Todo {
    has text: str,
        done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}

walker ping_server {
    can ping with `root entry {
        report "pong from backend!" ;
    }
}

walker get_server_message {
    can info with `root entry {
        report "hello from a basic walker!" ;
    }
}

cl {
    # Login Page
    def LoginPage -> any {
        [email, setEmail] = useState("");
        [password, setPassword] = useState("");
        [error, setError] = useState("");
        navigate = useNavigate();

        async def handleLogin(e: any) -> None {
            e.preventDefault();
            setError("");
            if not email or not password {
                setError("Please fill in all fields");
                return;
            }
            success = await jacLogin(email, password);
            if success {
                navigate("/");
            } else {
                setError("Invalid credentials");
            }
        }

        def handleEmailChange(e: any) -> None {
            setEmail(e.target.value);
        }

        def handlePasswordChange(e: any) -> None {
            setPassword(e.target.value);
        }

        errorDisplay = None;
        if error {
            errorDisplay = <div
                style={{"color": "#dc2626", "fontSize": "14px", "marginBottom": "12px"}}
            >
                {error}
            </div>;
        }

        return <div
            style={{
                "minHeight": "calc(100vh - 56px)",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "background": "#f5f5f5"
            }}
        >
            <div
                style={{
                    "background": "#ffffff",
                    "padding": "32px",
                    "borderRadius": "8px",
                    "width": "300px",
                    "boxShadow": "0 2px 8px rgba(0,0,0,0.1)"
                }}
            >
                <h2
                    style={{"marginBottom": "24px", "textAlign": "center"}}
                >
                    Login
                </h2>
                <form
                    onSubmit={handleLogin}
                >
                    <input
                        type="email"
                        value={email}
                        onChange={handleEmailChange}
                        placeholder="Email"
                        style={{
                            "width": "100%",
                            "padding": "10px",
                            "marginBottom": "12px",
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
                            "padding": "10px",
                            "marginBottom": "12px",
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
                            "padding": "10px",
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
                        "marginTop": "16px",
                        "fontSize": "14px"
                    }}
                >
                    Need an account?
                    {" "}
                    <Link to="/signup">
                        Sign up
                    </Link>
                </p>
            </div>
        </div>;
    }

    # Signup Page
    def SignupPage -> any {
        [email, setEmail] = useState("");
        [password, setPassword] = useState("");
        [error, setError] = useState("");
        navigate = useNavigate();

        async def handleSignup(e: any) -> None {
            e.preventDefault();
            setError("");
            if not email or not password {
                setError("Please fill in all fields");
                return;
            }
            result = await jacSignup(email, password);
            if result["success"] {
                navigate("/");
            } else {
                setError(result["error"] if result["error"] else "Signup failed");
            }
        }

        def handleEmailChange(e: any) -> None {
            setEmail(e.target.value);
        }

        def handlePasswordChange(e: any) -> None {
            setPassword(e.target.value);
        }

        errorDisplay = None;
        if error {
            errorDisplay = <div
                style={{"color": "#dc2626", "fontSize": "14px", "marginBottom": "12px"}}
            >
                {error}
            </div>;
        }

        return <div
            style={{
                "minHeight": "calc(100vh - 56px)",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "background": "#f5f5f5"
            }}
        >
            <div
                style={{
                    "background": "#ffffff",
                    "padding": "32px",
                    "borderRadius": "8px",
                    "width": "300px",
                    "boxShadow": "0 2px 8px rgba(0,0,0,0.1)"
                }}
            >
                <h2
                    style={{"marginBottom": "24px", "textAlign": "center"}}
                >
                    Sign Up
                </h2>
                <form
                    onSubmit={handleSignup}
                >
                    <input
                        type="email"
                        value={email}
                        onChange={handleEmailChange}
                        placeholder="Email"
                        style={{
                            "width": "100%",
                            "padding": "10px",
                            "marginBottom": "12px",
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
                            "padding": "10px",
                            "marginBottom": "12px",
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
                            "padding": "10px",
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
                        "marginTop": "16px",
                        "fontSize": "14px"
                    }}
                >
                    Have an account?
                    {" "}
                    <Link to="/login">
                        Login
                    </Link>
                </p>
            </div>
        </div>;
    }

    # Home page demonstrating CSS styling + direct asset usage + basic walkers
    def Home -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return <Navigate to="/login" />;
        }
        [count, setCount] = useState(0);
        [pingResult, setPingResult] = useState("");
        [serverMessage, setServerMessage] = useState("");
        [lastTodoMessage, setLastTodoMessage] = useState("");

        useEffect(
            lambda   -> None{ console.log("Home count changed: ", count);} , [count]
        );

        # Call simple backend walkers
        async def handlePing -> None {
            result = root spawn ping_server();
            if result.reports and result.reports.length > 0 {
                setPingResult(result.reports[0][0]);
            }
        }

        async def loadServerMessage -> None {
            result = root spawn get_server_message();
            if result.reports and result.reports.length > 0 {
                setServerMessage(result.reports[0][0]);
            }
        }

        # Create a sample Todo node in the graph with a hardcoded payload
        async def handleCreateSampleTodo -> None {
            result = root spawn create_todo(text="Sample todo from all-in-one app");
            if result.reports and result.reports.length > 0 {
                todo = result.reports[0][0];
                setLastTodoMessage("Created Todo: " + todo.text);
                console.log("Created Todo node:", todo);
            }
        }

        useEffect(lambda   -> None{ loadServerMessage();} , []);

        return <div
            style={{
                "padding": "2rem",
                "fontFamily": "system-ui, -apple-system, sans-serif"
            }}
        >
            <h1>
                🍔 Router + Styling + Assets Demo
            </h1>
            <p>
                This home page combines
                {" "}
                <strong>
                    React Router,
                </strong>
                {" "}
                <strong>
                    pure CSS styling,
                </strong>
                {" "}
                <strong>
                    static assets
                </strong>
                {" "}
                and
                {" "}
                <strong>
                    nested folder imports
                </strong>
            </p>
            <div className="container">
                <h2
                    style={{
                        "color": "white",
                        "textShadow": "2px 2px 4px rgba(0,0,0,0.6)"
                    }}
                >
                    CSS Background Image
                </h2>
                <p
                    style={{
                        "color": "white",
                        "maxWidth": "480px",
                        "textShadow": "1px 1px 3px rgba(0,0,0,0.7)"
                    }}
                >
                    This section uses the burger image as a background via CSS, just like the
                    {" "}
                    <code>
                        asset-serving/css-with-image
                    </code>
                    {" "}
                    example.
                </p>
            </div>
            <Card
                title="TypeScript Card Component"
                description="This card is built with TypeScript and demonstrates type-safe component usage in Jac"
                variant="highlighted"
            >
                <p
                    style={{"margin": "0.5rem 0", "color": "#374151"}}
                >
                    This is a TypeScript component imported and used in Jac code!
                </p>
            </Card>
            <div className="card">
                <h3>
                    Direct &lt;img&gt; asset
                </h3>
                <img
                    src="/static/assets/burger.png"
                    alt="Burger asset served by Jac"
                    className="burgerImage"
                />
                <p
                    style={{"marginTop": "0.75rem", "color": "#555"}}
                >
                    This image is served from the project
                    {" "}
                    <code>
                        assets/
                    </code>
                    {" "}
                    folder using the
                    {" "}
                    <code>
                        /static/assets/
                    </code>
                    {" "}
                    path.
                </p>
            </div>
            <div
                style={{"marginTop": "2rem"}}
            >
                <h3>
                    Counter with pure CSS classes
                </h3>
                <p>
                    You've clicked the burger
                    {" "}
                    <strong>
                        {count}
                    </strong>
                    {" "}
                    times.
                </p>
                <button
                    onClick={lambda  e: any  -> None{ setCount(count + 1);} }
                    style={{
                        "padding": "0.6rem 1.4rem",
                        "fontSize": "1rem",
                        "backgroundColor": "#ff6b35",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "6px",
                        "cursor": "pointer",
                        "boxShadow": "0 2px 4px rgba(0,0,0,0.2)"
                    }}
                >
                    Click the Burger! 🍔
                </button>
            </div>
            <div
                style={{"marginTop": "2rem"}}
            >
                <h3>
                    Backend Walkers
                </h3>
                <p>
                    Basic example walkers:
                    {" "}
                    <code>
                        ping_server
                    </code>
                    {" "}
                    and
                    {" "}
                    <code>
                        get_server_message
                    </code>
                </p>
                <button
                    onClick={lambda  e: any  -> None{ handlePing();} }
                    style={{
                        "padding": "0.5rem 1.2rem",
                        "marginRight": "0.75rem",
                        "backgroundColor": "#3b82f6",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "6px",
                        "cursor": "pointer"
                    }}
                >
                    Ping Backend
                </button>
                <button
                    onClick={lambda  e: any  -> None{ handleCreateSampleTodo();} }
                    style={{
                        "padding": "0.5rem 1.2rem",
                        "backgroundColor": "#10b981",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "6px",
                        "cursor": "pointer"
                    }}
                >
                    Create Sample Todo
                </button>
                {pingResult
                and (
                    <span
                        style={{"marginLeft": "0.5rem", "color": "#374151"}}
                    >
                        Result:
                        {" "}
                        <code>
                            {pingResult}
                        </code>
                    </span>
                )}
                {serverMessage
                and (
                    <p
                        style={{"marginTop": "0.75rem", "color": "#374151"}}
                    >
                        Message:
                        {" "}
                        <code>
                            {serverMessage}
                        </code>
                    </p>
                )}
                {lastTodoMessage
                and (
                    <p
                        style={{"marginTop": "0.5rem", "color": "#111827"}}
                    >
                        {lastTodoMessage}
                    </p>
                )}
            </div>
        </div>;
    }

    # Page showing nested imports from different folders
    def NestedImportsDemo -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return <Navigate to="/login" />;
        }

        return <div
            style={{
                "padding": "2rem",
                "fontFamily": "system-ui, -apple-system, sans-serif"
            }}
        >
            <h1>
                📁 Nested Folder Imports
            </h1>
            <p>
                This page mirrors the
                {" "}
                <code>
                    nested-folders/nested-basic
                </code>
                {" "}
                example by importing components from both
                {" "}
                <code>
                    components.button
                </code>
                {" "}
                and
                {" "}
                <code>
                    button
                </code>
            </p>
            <p
                style={{"marginTop": "0.75rem"}}
            >
                Both buttons below are rendered via relative imports:
            </p>
            <div
                style={{"display": "flex", "gap": "1rem", "marginTop": "1.5rem"}}
            >
                <CustomButton />
                <CustomButtonRoot />
            </div>
        </div>;
    }

    # Simple 404 page
    def NotFound -> any {
        return <div
            style={{
                "padding": "2rem",
                "textAlign": "center",
                "fontFamily": "system-ui, -apple-system, sans-serif"
            }}
        >
            <h1>
                🔍 404 - Page Not Found
            </h1>
            <p>
                The page you are looking for does not exist.
            </p>
            <Link to="/">
                ← Back to Home
            </Link>
        </div>;
    }

    # Navigation component with active link styling and auth
    def Navigation -> any {
        location = useLocation();
        isLoggedIn = jacIsLoggedIn();
        navigate = useNavigate();

        def linkStyle(path: str) -> dict {
            isActive = location.pathname == path;
            return {
                "padding": "0.5rem 1rem",
                "textDecoration": "none",
                "color": "#0066cc" if isActive else "#333",
                "fontWeight": "bold" if isActive else "normal",
                "backgroundColor": "#e3f2fd" if isActive else "transparent",
                "borderRadius": "4px",
                "display": "inline-block"
            };
        }

        def handleLogout(e: any) -> None {
            e.preventDefault();
            jacLogout();
            navigate("/login");
        }

        authButtons = None;
        if isLoggedIn {
            authButtons = <button
                onClick={handleLogout}
                style={{
                    "padding": "0.5rem 1rem",
                    "background": "#ef4444",
                    "color": "#ffffff",
                    "border": "none",
                    "borderRadius": "4px",
                    "cursor": "pointer",
                    "fontWeight": "600"
                }}
            >
                Logout
            </button>;
        } else {
            authButtons = <>
                <Link
                    to="/login"
                    style={linkStyle("/login")}
                >
                    Login
                </Link>
                <Link
                    to="/signup"
                    style={linkStyle("/signup")}
                >
                    Sign Up
                </Link>
            </>;
        }

        return <nav
            style={{
                "padding": "1rem",
                "backgroundColor": "#f5f5f5",
                "marginBottom": "2rem",
                "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
            }}
        >
            <div
                style={{
                    "maxWidth": "1200px",
                    "margin": "0 auto",
                    "display": "flex",
                    "gap": "1rem",
                    "alignItems": "center",
                    "justifyContent": "space-between"
                }}
            >
                <div
                    style={{"display": "flex", "gap": "1rem", "alignItems": "center"}}
                >
                    {isLoggedIn
                    and (
                        <>
                            <Link
                                to="/"
                                style={linkStyle("/")}
                            >
                                Home
                            </Link>
                            <Link
                                to="/nested"
                                style={linkStyle("/nested")}
                            >
                                Nested Imports
                            </Link>
                        </>
                    )}
                </div>
                <div
                    style={{"display": "flex", "gap": "1rem", "alignItems": "center"}}
                >
                    {authButtons}
                </div>
            </div>
        </nav>;
    }

    # Main app wrapped in Router (same API as with-router/ example)
    def app -> any {
        return <Router>
            <div
                style={{"fontFamily": "system-ui, -apple-system, sans-serif"}}
            >
                <Navigation />
                <div
                    style={{
                        "maxWidth": "960px",
                        "margin": "0 auto",
                        "padding": "0 1rem 3rem 1rem"
                    }}
                >
                    <Routes>
                        <Route
                            path="/"
                            element={<Home />}
                        />
                        <Route
                            path="/login"
                            element={<LoginPage />}
                        />
                        <Route
                            path="/signup"
                            element={<SignupPage />}
                        />
                        <Route
                            path="/nested"
                            element={<NestedImportsDemo />}
                        />
                        <Route
                            path="*"
                            element={<NotFound />}
                        />
                    </Routes>
                </div>
            </div>
        </Router>;
    }
}
