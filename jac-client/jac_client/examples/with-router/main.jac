# React Router HashRouter Example
cl import from react { useEffect }
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,
    useNavigate,
    useLocation,
    useParams
}

cl {
    # Home Page Component
    def Home -> any {
        location = useLocation();
        navigate = useNavigate();

        def goToAbout(e: any) -> None {
            navigate("/about");
        }

        return <div>
            <h1>
                🏠 Home Page
            </h1>
            <p>
                Welcome to the home page!
            </p>
            <p>
                This example uses React Router's
                <strong>
                    HashRouter
                </strong>
                #  for client-side routing.
            </p>
            <p>
                Current path:
                <code>
                    {location.pathname}
                </code>
            </p>
            <button
                onClick={goToAbout}
            >
                Go to About →
            </button>
        </div>;
    }

    # About Page Component
    def About -> any {
        location = useLocation();

        return <div>
            <h1>
                ℹ️ About Page
            </h1>
            <p>
                This is the about page.
            </p>
            <p>
                Learn more about our application here.
            </p>
            <p>
                Current path:
                <code>
                    {location.pathname}
                </code>
            </p>
            <div
                style={{"marginTop": "1rem"}}
            >
                <Link to="/about/team">
                    View Team →
                </Link>
            </div>
        </div>;
    }

    # Team Page Component (nested route example)
    def Team -> any {
        return <div>
            <h1>
                👥 Our Team
            </h1>
            <p>
                Meet the amazing team behind this project!
            </p>
            <Link to="/about">
                ← Back to About
            </Link>
        </div>;
    }

    # User Profile Component (with URL parameters)
    def UserProfile -> any {
        params = useParams();
        userId = params.id if params.id else "Unknown";

        return <div>
            <h1>
                👤 User Profile
            </h1>
            <p>
                Viewing profile for user:
                <strong>
                    {userId}
                </strong>
            </p>
            <p>
                This demonstrates URL parameters using
                <code>
                    /user/:id
                </code>
            </p>
            <Link to="/">
                ← Back to Home
            </Link>
        </div>;
    }

    # Contact Page Component
    def Contact -> any {
        has submitted: bool = False;

        def handleSubmit(e: any) -> None {
            e.preventDefault();
            submitted = True;
        }

        def resetForm(e: any) -> None {
            submitted = False;
        }

        if submitted {
            return <div>
                <h1>
                    📧 Contact Page
                </h1>
                <div
                    style={{"color": "green"}}
                >
                    <p>
                        ✓ Thank you! Your message has been sent.
                    </p>
                    <button
                        onClick={resetForm}
                    >
                        Send another
                    </button>
                </div>
            </div>;
        }

        return <div>
            <h1>
                📧 Contact Page
            </h1>
            <p>
                Get in touch with us!
            </p>
            <form
                onSubmit={handleSubmit}
            >
                <input
                    type="text"
                    placeholder="Your name"
                    style={{"margin": "0.5rem 0", "display": "block"}}
                />
                <input
                    type="text"
                    placeholder="Your username"
                    style={{"margin": "0.5rem 0", "display": "block"}}
                />
                <textarea
                    placeholder="Your message"
                    style={{"margin": "0.5rem 0", "display": "block"}}
                ></textarea>
                <button type="submit">
                    Send Message
                </button>
            </form>
        </div>;
    }

    # 404 Not Found Component
    def NotFound -> any {
        location = useLocation();
        navigate = useNavigate();

        def goHome(e: any) -> None {
            navigate("/");
        }

        return <div
            style={{"textAlign": "center", "padding": "2rem"}}
        >
            <h1>
                🔍 404 - Page Not Found
            </h1>
            <p>
                The page
                <code>
                    {location.pathname}
                </code>
                does not exist.
            </p>
            <button
                onClick={goHome}
            >
                Go Home
            </button>
        </div>;
    }

    # Navigation Component with active link styling
    def Navigation -> any {
        location = useLocation();

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
                    "alignItems": "center"
                }}
            >
                <Link
                    to="/"
                    style={linkStyle("/")}
                >
                    Home
                </Link>
                <Link
                    to="/about"
                    style={linkStyle("/about")}
                >
                    About
                </Link>
                <Link
                    to="/contact"
                    style={linkStyle("/contact")}
                >
                    Contact
                </Link>
                <Link
                    to="/user/123"
                    style={linkStyle("/user/123")}
                >
                    Profile Demo
                </Link>
            </div>
        </nav>;
    }

    # Main App Component with React Router HashRouter
    def:pub app -> any {
        return <Router>
            <div
                style={{"fontFamily": "system-ui, -apple-system, sans-serif"}}
            >
                <Navigation />
                <div
                    style={{
                        "maxWidth": "1200px",
                        "margin": "0 auto",
                        "padding": "0 1rem"
                    }}
                >
                    <Routes>
                        <Route
                            path="/"
                            element={<Home />}
                        />
                        <Route
                            path="/about"
                            element={<About />}
                        />
                        <Route
                            path="/about/team"
                            element={<Team />}
                        />
                        <Route
                            path="/contact"
                            element={<Contact />}
                        />
                        <Route
                            path="/user/:id"
                            element={<UserProfile />}
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
