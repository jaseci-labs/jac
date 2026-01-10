cl import from "@jac-client/utils" {
    Link
}
cl {
    def:pub NotFound -> any {
    return <div
        style={{
            "padding": "2rem",
            "textAlign": "center",
            "fontFamily": "system-ui, -apple-system, sans-serif"
        }}
    >
        <h1>
            🔍 404 - Page Not Found
        </h1>
        <p>
            The page you are looking for does not exist.
        </p>
        <Link to="/">
            ← Back to Home
        </Link>
    </div>;
}
}
