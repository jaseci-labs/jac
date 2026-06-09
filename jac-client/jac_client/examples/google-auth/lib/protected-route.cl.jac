"""Route guard: render children only when a user is authenticated."""

import from react { useContext }
import from "@jac/runtime" { Navigate }
import from '..lib.auth' { AuthContext }

def:pub Protected(children: any) -> JsxElement {
    auth = useContext(AuthContext);
    if (not auth) or (not auth.user) {
        return <Navigate to="/login" replace/>;
    }
    return children;
}
