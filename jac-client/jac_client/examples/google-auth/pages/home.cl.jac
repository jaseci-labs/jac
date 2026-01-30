import from "@jac/runtime" { Link }

def:pub Home -> any {
    return
        <p>
            Welcome!
            <Link to="/dashboard">
                Go to Dashboard
            </Link>
            Go to Sample Page:
            <Link to="/sample">
                Sample
            </Link>
        </p>;
}
