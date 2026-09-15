"""Deliberately ill-typed fixture -- this file must NEVER type-check.

test_cli.jac's "jac check reports errors for files inside jaclang source
tree" uses it to prove that `jac check` ()
surfaces diagnostics for files inside the jaclang package instead of
routing them to the self-host program where errors are invisible. Do not fix
the type error below; the test depends on it.
"""

def returns_wrong_type -> int {
    return "definitely not an int";
}
