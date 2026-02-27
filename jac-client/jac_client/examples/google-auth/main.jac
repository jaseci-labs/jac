"""Main entry point for google-auth with backend SSO.

This example demonstrates proper Google OAuth authentication using jac-scale's backend.
The backend returns JSON with the token, which we handle in the callback page.
"""

# Client-side imports
cl import from react { useEffect }
cl import from '.lib.auth' { AuthProvider }
cl import from '.lib.protected-route' { Protected }
cl import from '.pages.login' { Login }
cl import from '.pages.callback' { OAuthCallback }
cl import from '.pages.home' { Home }
cl import from '.pages.dashboard' { Dashboard }
cl import from '.pages.sample' { Sample }
cl import from "@jac/runtime" { Router, Routes, Route, Link }
cl import ".styles.css";

# Client-side component
cl {
    def NavigationMenu -> JsxElement {
        return
            <nav style={{"display": "flex", "gap": "10px", "marginBottom": "20px"}}>
                <button>
                    <Link to="/">
                        Home
                    </Link>
                </button>
                <button>
                    <Link to="/login">
                        Login
                    </Link>
                </button>
                <button>
                    <Link to="/dashboard">
                        Dashboard
                    </Link>
                </button>
                <button>
                    <Link to="/sample">
                        Sample
                    </Link>
                </button>
            </nav>;
    }

    def:pub app -> any {
        return
            <AuthProvider>
                <Router>
                    <NavigationMenu/>
                    <Routes>
                        <Route path="/" element={<Home/>}/>
                        <Route path="/login" element={<Login/>}/>
                        <Route path="/auth/callback" element={<OAuthCallback/>}/>
                        <Route
                            path="/sample"
                            element={<Protected>
                                <Sample/>
                            </Protected>}
                        />
                        <Route
                            path="/dashboard"
                            element={<Protected>
                                <Dashboard/>
                            </Protected>}
                        />
                    </Routes>
                </Router>
            </AuthProvider>;
    }
}
