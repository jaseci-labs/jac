# Nested folder imports (same pattern as nested-basic/)
cl import from ..components.nestedDemo.CustomButton.tsx {
    CustomButton
}
cl import from ..button { CustomButtonRoot }
cl import from "@jac/runtime" { Navigate, jacIsLoggedIn }

cl {
    def:pub NestedImportsDemo -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return
                <Navigate to="/login" />;
        }

        return
            <div
                style={{
                    "padding": "2rem",
                    "fontFamily": "system-ui, -apple-system, sans-serif"
                }}
            >
                <h1>
                    📁 Nested Folder Imports
                </h1>
                <p>
                    This page mirrors the
                    {" "}
                    <code>
                        nested-folders/nested-basic
                    </code>
                    {" "}
                    example by importing components from both
                    {" "}
                    <code>
                        components.button
                    </code>
                    {" "}
                    and
                    {" "}
                    <code>
                        button
                    </code>
                </p>
                <p style={{"marginTop": "0.75rem"}}>
                    Both buttons below are rendered via relative imports:
                </p>
                <div style={{"display": "flex", "gap": "1rem", "marginTop": "1.5rem"}}>
                    <CustomButton />
                    <CustomButtonRoot />
                </div>
            </div>;
    }
}
