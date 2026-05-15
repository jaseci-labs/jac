"""Multi-segment route test fixture."""
cl import from "@jac/runtime" { Router, Routes, Route, Outlet, Link }

to cl:

def:pub app() -> JsxElement {
    return <Router>
        <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Multi-segment Route Test Fixture</h1>
            <nav style={{marginBottom: "1rem", display: "flex", gap: "10px"}}>
                <Link id="home-link" to="/">Home</Link> |
                <Link id="dash-link" to="/dashboard">Dashboard</Link> |
                <Link id="settings-link" to="/dashboard/settings">Settings</Link>
            </nav>
            <hr />
            <Routes>
                <Route path="/" element={<div id="home-content">Home Content</div>} />
                <Route path="/dashboard" element={<Dashboard />}>
                    <Route path="settings" element={<div id="settings-content">Settings Content</div>} />
                </Route>
            </Routes>
        </div>
    </Router>;
}

def:pub Dashboard() -> JsxElement {
    return <div>
        <h2>Dashboard</h2>
        <div id="outlet-wrapper" style={{padding: "1rem", border: "1px solid #ccc"}}>
            <Outlet />
        </div>
    </div>;
}
