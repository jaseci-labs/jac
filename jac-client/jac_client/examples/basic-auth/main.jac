# Simple Authentication App with Jac Client Utils
cl import from '@jac/runtime' {
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn
}

cl {
    def:pub app -> JsxElement {
        has isLoggedIn: bool = False,
            isSignup: bool = False,
            username: str = "",
            password: str = "",
            error: str = "",
            loading: bool = False;

        # Check login status on mount
        can with entry {
            isLoggedIn = jacIsLoggedIn();
        }

        # Handle login
        async def handleLogin -> None {
            error = "";
            if not username.strip() or not password {
                error = "Please fill in all fields";
                return;
            }
            loading = True;
            success = await jacLogin(username, password);
            loading = False;
            if success {
                isLoggedIn = True;
                username = "";
                password = "";
            } else {
                error = "Invalid username or password";
            }
        }

        # Handle signup
        async def handleSignup -> None {
            error = "";
            if not username.strip() or not password {
                error = "Please fill in all fields";
                return;
            }
            if len(password) < 6 {
                error = "Password must be at least 6 characters";
                return;
            }
            loading = True;
            result = await jacSignup(username, password);
            loading = False;
            if result["success"] {
                isLoggedIn = True;
                username = "";
                password = "";
            } else {
                error = result["error"] if result["error"] else "Signup failed";
            }
        }

        # Handle logout
        def handleLogout -> None {
            jacLogout();
            isLoggedIn = False;
            username = "";
            password = "";
            error = "";
        }

        # Handle form submit
        async def handleSubmit(e: any) -> None {
            e.preventDefault();
            if isSignup {
                await handleSignup();
            } else {
                await handleLogin();
            }
        }

        # Logged in view - Dashboard
        if isLoggedIn {
            return
                <div
                    style={{
                        "minHeight": "100vh",
                        "background": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "fontFamily": "system-ui, -apple-system, sans-serif"
                    }}
                >
                    <div
                        style={{
                            "background": "#ffffff",
                            "borderRadius": "16px",
                            "padding": "48px",
                            "boxShadow": "0 20px 60px rgba(0,0,0,0.3)",
                            "maxWidth": "500px",
                            "width": "90%",
                            "textAlign": "center"
                        }}
                    >
                        <h1
                            style={{
                                "fontSize": "2.5rem",
                                "marginBottom": "16px",
                                "color": "#1f2937",
                                "fontWeight": "700"
                            }}
                        >
                            ✅ Welcome!
                        </h1>
                        <p
                            style={{
                                "fontSize": "1.1rem",
                                "color": "#6b7280",
                                "marginBottom": "32px"
                            }}
                        >
                            You are successfully logged in
                        </p>
                        <div
                            style={{
                                "background": "#f3f4f6",
                                "padding": "24px",
                                "borderRadius": "12px",
                                "marginBottom": "32px"
                            }}
                        >
                            <p
                                style={{
                                    "fontSize": "0.9rem",
                                    "color": "#6b7280",
                                    "marginBottom": "8px"
                                }}
                            >
                                Logged in as:
                            </p>
                            <p
                                style={{
                                    "fontSize": "1.2rem",
                                    "fontWeight": "600",
                                    "color": "#667eea"
                                }}
                            >
                                User
                            </p>
                        </div>
                        <button
                            onClick={handleLogout}
                            style={{
                                "width": "100%",
                                "padding": "14px 24px",
                                "background": "#ef4444",
                                "color": "#ffffff",
                                "border": "none",
                                "borderRadius": "10px",
                                "fontSize": "16px",
                                "fontWeight": "600",
                                "cursor": "pointer",
                                "transition": "all 0.3s",
                                "boxShadow": "0 4px 12px rgba(239,68,68,0.3)"
                            }}
                        >
                            Logout
                        </button>
                    </div>
                </div>;
        }

        # Login/Signup view
        return
            <div
                style={{
                    "minHeight": "100vh",
                    "background": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "fontFamily": "system-ui, -apple-system, sans-serif",
                    "padding": "20px"
                }}
            >
                <div
                    style={{
                        "background": "#ffffff",
                        "borderRadius": "16px",
                        "padding": "48px",
                        "boxShadow": "0 20px 60px rgba(0,0,0,0.3)",
                        "maxWidth": "400px",
                        "width": "100%"
                    }}
                >
                    # Header
                    <div style={{"textAlign": "center", "marginBottom": "32px"}}>
                        <h1
                            style={{
                                "fontSize": "2rem",
                                "fontWeight": "700",
                                "color": "#1f2937",
                                "marginBottom": "8px"
                            }}
                        >
                            {("Create Account" if isSignup else "Welcome Back")}
                        </h1>
                        <p style={{"color": "#6b7280", "fontSize": "0.95rem"}}>
                            {(
                                "Sign up to get started"
                                if isSignup
                                else "Sign in to continue"
                            )}
                        </p>
                    </div>
                    # Form
                    <form onSubmit={handleSubmit} style={{"marginBottom": "24px"}}>
                        <div style={{"marginBottom": "20px"}}>
                            <label
                                style={{
                                    "display": "block",
                                    "marginBottom": "8px",
                                    "color": "#374151",
                                    "fontSize": "14px",
                                    "fontWeight": "600"
                                }}
                            >
                                Username
                            </label>
                            <input
                                type="text"
                                value={username}
                                onChange={lambda e: any  -> None { username = e.target.value;}}
                                placeholder="Enter your username"
                                style={{
                                    "width": "100%",
                                    "padding": "12px 16px",
                                    "border": "2px solid #e5e7eb",
                                    "borderRadius": "10px",
                                    "fontSize": "16px",
                                    "outline": "none",
                                    "transition": "border 0.2s",
                                    "boxSizing": "border-box"
                                }}
                            />
                        </div>
                        <div style={{"marginBottom": "24px"}}>
                            <label
                                style={{
                                    "display": "block",
                                    "marginBottom": "8px",
                                    "color": "#374151",
                                    "fontSize": "14px",
                                    "fontWeight": "600"
                                }}
                            >
                                Password
                            </label>
                            <input
                                type="password"
                                value={password}
                                onChange={lambda e: any  -> None { password = e.target.value;}}
                                placeholder="Enter your password"
                                style={{
                                    "width": "100%",
                                    "padding": "12px 16px",
                                    "border": "2px solid #e5e7eb",
                                    "borderRadius": "10px",
                                    "fontSize": "16px",
                                    "outline": "none",
                                    "transition": "border 0.2s",
                                    "boxSizing": "border-box"
                                }}
                            />
                        </div>
                        {(
                            <div
                                style={{
                                    "padding": "12px",
                                    "background": "#fee2e2",
                                    "border": "1px solid #fecaca",
                                    "borderRadius": "8px",
                                    "marginBottom": "20px"
                                }}
                            >
                                <p
                                    style={{
                                        "color": "#dc2626",
                                        "fontSize": "14px",
                                        "margin": "0"
                                    }}
                                >
                                    {error}
                                </p>
                            </div>
                        )
                        if error
                        else None}
                        <button
                            type="submit"
                            disabled={loading}
                            style={{
                                "width": "100%",
                                "padding": "14px 24px",
                                "background": (("#9ca3af" if loading else "#667eea")),
                                "color": "#ffffff",
                                "border": "none",
                                "borderRadius": "10px",
                                "fontSize": "16px",
                                "fontWeight": "600",
                                "cursor": (("not-allowed" if loading else "pointer")),
                                "transition": "all 0.3s",
                                "boxShadow": "0 4px 12px rgba(102,126,234,0.4)"
                            }}
                        >
                            {(
                                (
                                    "Processing..."
                                    if loading
                                    else ("Sign Up" if isSignup else "Sign In")
                                )
                            )}
                        </button>
                    </form>
                    # Toggle between login/signup
                    <div style={{"textAlign": "center"}}>
                        <p
                            style={{
                                "color": "#6b7280",
                                "fontSize": "14px",
                                "marginBottom": "8px"
                            }}
                        >
                            {(
                                (
                                    "Already have an account?"
                                    if isSignup
                                    else "Don't have an account?"
                                )
                            )}
                        </p>
                        <button
                            onClick={lambda -> None { isSignup = not isSignup;error = "";username = "";password = "";}}
                            style={{
                                "background": "none",
                                "border": "none",
                                "color": "#667eea",
                                "fontSize": "14px",
                                "fontWeight": "600",
                                "cursor": "pointer",
                                "textDecoration": "underline"
                            }}
                        >
                            {(("Sign In" if isSignup else "Create Account"))}
                        </button>
                    </div>
                </div>
            </div>;
    }
}
