"""Home page fixture for the Solid file-based-routing jsdom test.

Renders an identifiable node plus `<Link>`s (mapped to `@solidjs/router`'s `<A>`
by the shim) so the harness can click to navigate and assert the route swaps.
As a `.cl.jac` the whole module is client codespace.
"""

import from "@jac/runtime" { Link }

def:pub page -> JsxElement {
    return <div data-testid="home">
        <h1>Home</h1>
        <Link to="/about" data-testid="to-about">About</Link>
        <Link to="/dashboard" data-testid="to-dashboard">Dashboard</Link>
    </div>;
}
