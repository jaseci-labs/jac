"""Regression: `@jac/runtime` virtual module must be resolvable by the type checker.

The ECMAScript bundler already maps `@jac/runtime` to
`jaclang/runtimelib/client_runtime.cl.jac`. The type checker should agree so that
imported symbols keep their declared types instead of collapsing to Unknown.
"""

import from "@jac/runtime" { jacIsLoggedIn, jacLogout }

def check -> bool {
    jacLogout();
    return jacIsLoggedIn();
}

with entry {
    print(check());
}
