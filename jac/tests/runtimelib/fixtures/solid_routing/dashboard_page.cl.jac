"""Protected page fixture (`auth: true`) for the Solid routing jsdom test.

Mounts only when `AuthGuard` sees a logged-in session; otherwise the guard
redirects to the login path and this node never renders.
"""

def:pub page -> JsxPage {
    return <div data-testid="dashboard"><h1>Dashboard</h1></div>;
}
