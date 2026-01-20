cl import from "@jac-client/utils" {
    Link
}
cl import "..styles/notFoundPage/NotFoundstyle.css";
cl {
    def:pub NotFound -> any {
    return <div className="not-found-container">
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
