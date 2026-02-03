cl import from "@jac/runtime" { Outlet }
cl import from ..components.navigation { Navigation }

cl {
    def:pub layout -> JsxElement {
        return
            <>
                <Navigation />
                <div
                    style={{
                        "maxWidth": "960px",
                        "margin": "0 auto",
                        "padding": "0 1rem 3rem 1rem"
                    }}
                >
                    <Outlet />
                </div>
            </>;
    }
}
