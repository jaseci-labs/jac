"""AuthGuard - redirects unauthenticated users to /auth."""
import from "@jac/runtime" { jacIsLoggedIn, Navigate }

"""Wraps protected routes. Redirects to /auth if not logged in."""
def:pub AuthGuard(props: Any) -> Any {
    if not jacIsLoggedIn() {
        return <Navigate to="/auth" replace={True} />;
    }
    return props.children;
}
