"""Main entry point for google-auth-v2."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect }
cl import from .components.Button { Button }
cl import from "@jac/runtime" {
    Router,
    Routes,
    Route,
    Link
}

# Client-side component
cl {
    def Home() -> any {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to the Google Auth V2 Example!</p>
            <p>
                <Link to="/dashboard">Go to Dashboard</Link>
            </p>
        </div>;
    }

    def Dashboard() -> any {
        return <div>
            <h1>Dashboard</h1>
            <p>This is a protected dashboard page.</p>
            <p>
                <Link to="/">Go to Home</Link>
            </p>
        </div>;
    }
    def:pub app() -> any {
        
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/dashboard" element={<Dashboard />} />
            </Routes>
        </Router>;
    }
}
