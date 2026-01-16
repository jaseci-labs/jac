# Simple Authentication App with React Router
cl import from react {
    useState,
    useEffect
}
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

cl {
    # Navigation Component
    def Navigation -> any {
        isLoggedIn = jacIsLoggedIn();
        navigate = useNavigate();

        def handleLogout(e: any) -> None {
            e.preventDefault();
            jacLogout();
            navigate("/login");
        }

        if isLoggedIn {
            return <nav
                style={{
                    "padding": "16px 24px",
                    "background": "#667eea",
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center"
                }}
            >
                <div
                    style={{
                        "fontSize": "1.25rem",
                        "fontWeight": "600",
                        "color": "#ffffff"
                    }}
                >
                    MyApp
                </div>
                <div
                    style={{"display": "flex", "gap": "16px"}}
                >
                    <Link
                        to="/dashboard"
                        style={{"color": "#ffffff", "textDecoration": "none"}}
                    >
                        Dashboard
                    </Link>
                    <button
                        onClick={handleLogout}
                        style={{
                            "background": "none",
                            "color": "#ffffff",
                            "border": "1px solid #ffffff",
                            "padding": "4px 12px",
                            "borderRadius": "4px",
                            "cursor": "pointer"
                        }}
                    >
                        Logout
                    </button>
                </div>
            </nav>;
        }

        return <nav
            style={{
                "padding": "16px 24px",
                "background": "#667eea",
                "display": "flex",
                "justifyContent": "space-between",
                "alignItems": "center"
            }}
        >
            <div
                style={{"fontSize": "1.25rem", "fontWeight": "600", "color": "#ffffff"}}
            >
                MyApp
            </div>
            <div
                style={{"display": "flex", "gap": "16px"}}
            >
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
        has username: str = "";
        has password: str = "";
        has error: str = "";
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
                navigate("/dashboard");
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
                        type="text"
                        value={username}
                        onChange={handleUsernameChange}
                        placeholder="Username"
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
                            "background": "#667eea",
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
                    <Link to="/signup">
                        Sign up
                    </Link>
                </p>
            </div>
        </div>;
    }

    # Signup Page
    def SignupPage -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";
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
                navigate("/dashboard");
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
                        type="text"
                        value={username}
                        onChange={handleUsernameChange}
                        placeholder="Username"
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
                            "background": "#667eea",
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
                    <Link to="/login">
                        Login
                    </Link>
                </p>
            </div>
        </div>;
    }

    # Dashboard Page (Protected Route)
    def DashboardPage -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return <Navigate to="/login" />;
        }

        return <div
            style={{
                "minHeight": "calc(100vh - 56px)",
                "padding": "40px 20px",
                "background": "#f5f5f5"
            }}
        >
            <div
                style={{
                    "maxWidth": "800px",
                    "margin": "0 auto",
                    "background": "#ffffff",
                    "padding": "40px",
                    "borderRadius": "8px",
                    "boxShadow": "0 2px 8px rgba(0,0,0,0.1)"
                }}
            >
                <h1
                    style={{"marginBottom": "16px"}}
                >
                    🎉 Welcome to Your Dashboard
                </h1>
                <p
                    style={{"color": "#666", "lineHeight": "1.6"}}
                >
                    You are now logged in and can access protected content.
                </p>
                <p
                    style={{"color": "#666", "lineHeight": "1.6", "marginTop": "16px"}}
                >
                    This is a simple dashboard page demonstrating authenticationwith React Router in Jac. You can add your own content and functionality here.
                </p>
                <div
                    style={{
                        "marginTop": "24px",
                        "padding": "16px",
                        "background": "#f0f9ff",
                        "borderRadius": "4px",
                        "border": "1px solid #bae6fd"
                    }}
                >
                    <h3
                        style={{"marginBottom": "8px", "color": "#0369a1"}}
                    >
                        Protected Route Demo
                    </h3>
                    <p
                        style={{"color": "#0c4a6e", "fontSize": "14px"}}
                    >
                        This page is only accessible to authenticated users. Try logging outand accessing this page - you'll be redirected to the login page!
                    </p>
                </div>
            </div>
        </div>;
    }

    # Home/Landing Page - auto-redirect based on auth status
    def HomePage -> any {
        if jacIsLoggedIn() {
            return <Navigate to="/dashboard" />;
        }
        return <Navigate to="/login" />;
    }

    # Main App with React Router
    def:pub app -> any {
        return <Router>
            <div
                style={{
                    "fontFamily": "system-ui, -apple-system, sans-serif",
                    "minHeight": "100vh"
                }}
            >
                <Navigation />
                <Routes>
                    <Route
                        path="/"
                        element={<HomePage />}
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
                        path="/dashboard"
                        element={<DashboardPage />}
                    />
                </Routes>
            </div>
        </Router>;
    }
}
