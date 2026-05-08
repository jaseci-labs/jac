"""Test declarative routing system.

Uses the React Router v6-shaped surface that bare-serve and jac-client both
expose: `<Routes>` + `<Route path element/>` for declaration, `<Link to/>`
for navigation, and `useNavigate` / `useLocation` / `useParams` for
programmatic access. The fixture's bundle output is asserted against by
`test_router.jac` (sibling) to verify these symbols flow through codegen.
"""

cl import from "@jac/runtime" {
    Router, Routes, Route, Link, Navigate, Outlet,
    useNavigate, useLocation, useParams, useRouter, navigate
}

cl {
    # Mock components for testing
    def HomePage  -> JsxElement {
        return <div id="home-page">Home Page</div>;
    }

    def AboutPage  -> JsxElement {
        return <div id="about-page">About Page</div>;
    }

    def ProfilePage  -> JsxElement {
        return <div id="profile-page">Profile Page</div>;
    }

    def UserPage  -> JsxElement {
        params = useParams();
        return <div id="user-page">User: {params.id}</div>;
    }

    def LoginPage  -> JsxElement {
        return <div id="login-page">Login Page</div>;
    }

    # Test 1: Declarative route tree compiles via JSX.
    def test_router_basic  -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/home" element={<HomePage />} />
                <Route path="/about" element={<AboutPage />} />
                <Route path="/profile" element={<ProfilePage />} />
                <Route path="/users/:id" element={<UserPage />} />
            </Routes>
        </Router>;
    }

    # Test 2: Programmatic navigation via the imperative `navigate` helper.
    def test_router_navigation  -> dict {
        navigate("/home");
        initialPath = useLocation();
        navigate("/about");
        aboutPath = useLocation();
        navigate("/profile");
        profilePath = useLocation();
        return {
            "initialPath": initialPath.pathname,
            "aboutPath": aboutPath.pathname,
            "profilePath": profilePath.pathname
        };
    }

    # Test 3: Auth-gated route — `<Navigate to>` redirects when guard fails.
    def AuthedProfile  -> JsxElement {
        # In real apps this would check a session. Fixture inlines False so
        # codegen emits the redirect branch.
        isAuthed = False;
        if isAuthed {
            return <ProfilePage />;
        }
        return <Navigate to="/login" />;
    }

    def test_router_guards  -> JsxElement {
        return <Routes>
            <Route path="/profile" element={<AuthedProfile />} />
            <Route path="/login" element={<LoginPage />} />
        </Routes>;
    }

    # Test 4: <Link to/> renders an anchor that intercepts clicks.
    def test_link_component  -> JsxElement {
        return <Link to="/about">Go to About</Link>;
    }

    # Test 5: Hooks return router state.
    def test_router_hooks  -> dict {
        nav = useNavigate();
        loc = useLocation();
        return {"hasNavigate": nav != None, "pathname": loc.pathname};
    }

    # Test entry point
    def test_all_router_features  -> dict {
        return {
            "navigation": test_router_navigation(),
            "hooks": test_router_hooks()
        };
    }
}
