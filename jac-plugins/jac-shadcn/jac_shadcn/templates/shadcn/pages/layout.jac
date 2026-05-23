"""Root layout -- wraps every page in this app.

Add headers, footers, or sidebars here. The `<Outlet />` is where the
matched page renders. See https://reactrouter.com/start/library/routing#nested-routes
for the React Router pattern this follows.
"""

cl import from "@jac/runtime" { Outlet }

cl {
    def:pub layout -> JsxElement {
        return
            <>
                <Outlet/>
            </>;
    }
}
