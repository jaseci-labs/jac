


"""Main entry point for google-auth with backend SSO.

This example demonstrates proper Google OAuth authentication using jac-scale's backend.
The backend returns JSON with the token, which we handle in the callback page.
"""

# Client-side imports
cl import from react { useEffect }
cl import from '.lib.auth-backend' { AuthProvider }
cl import from '.lib.protected-route' { Protected }
cl import from '.pages.login-backend' { Login }
cl import from '.pages.callback' { OAuthCallback }
cl import from '.pages.home' { Home }
cl import from '.pages.dashboard' { Dashboard }
cl import from "@jac/runtime" {
    Router,
    Routes,
    Route
}

# Client-side component
cl {
    def:pub app() -> any {
        return <AuthProvider>
            <Router>
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/login" element={<Login />} />
                    <Route path="/auth/callback" element={<OAuthCallback />} />
                    <Route path="/sso/google/login/callback" element={<OAuthCallback />} />
                    <Route path="/sso/google/register/callback" element={<OAuthCallback />} />
                    <Route
                        path="/dashboard"
                        element={
                            <Protected>
                                <Dashboard />
                            </Protected>
                        }
                    />
                </Routes>
            </Router>
        </AuthProvider>;
    }
}
