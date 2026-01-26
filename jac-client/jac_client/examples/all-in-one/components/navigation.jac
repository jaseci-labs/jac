cl import from "@jac/runtime" {
    Link,
    useNavigate,
    useLocation,
    jacLogout,
    jacIsLoggedIn
}

cl {
    def:pub Navigation -> any {
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
                <Link to="/login" style={linkStyle("/login")}>
                    Login
                </Link>
                <Link to="/signup" style={linkStyle("/signup")}>
                    Sign Up
                </Link>
            </>;
        }

        return
            <nav
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
                        style={{
                            "display": "flex",
                            "gap": "1rem",
                            "alignItems": "center"
                        }}
                    >
                        {isLoggedIn
                        and (
                            <>
                                <Link to="/" style={linkStyle("/")}>
                                    Home
                                </Link>
                                <Link to="/nested" style={linkStyle("/nested")}>
                                    Nested Imports
                                </Link>
                                <Link
                                    to="/features-test"
                                    style={linkStyle("/features-test")}
                                >
                                    Features Test
                                </Link>
                                <Link to="/landing" style={linkStyle("/landing")}>
                                    Landing Page
                                </Link>
                                <Link
                                    to="/budget-planner"
                                    style={linkStyle("/budget-planner")}
                                >
                                    Budget Planner
                                </Link>
                            </>
                        )}
                    </div>
                    <div
                        style={{
                            "display": "flex",
                            "gap": "1rem",
                            "alignItems": "center"
                        }}
                    >
                        {authButtons}
                    </div>
                </div>
            </nav>;
    }
}
