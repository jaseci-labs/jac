"""Root layout fixture for the Solid routing jsdom test.

Authored exactly as a real Jac layout (`def:pub layout`, no params, `<Outlet/>`
where the matched route goes). The harness asserts the chrome persists across
navigations while the `<Outlet/>` content swaps -- exercising `<Router root=...>`
plus the `__JacOutletContext` bridge that delivers `props.children` to `Outlet`.
"""

import from "@jac/runtime" { Outlet }

def:pub layout -> JsxLayout {
    return <div data-testid="layout">
        <nav data-testid="chrome">chrome</nav>
        <Outlet/>
    </div>;
}
