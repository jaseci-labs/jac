# Fixture for issue #6357: lowercase `true`/`false`/`null`/`none` parse as
# ordinary (undefined) names rather than the Python-style `True`/`False`/`None`
# literals. They should surface a W2001 "may be undefined" warning carrying a
# targeted "did you mean ...?" hint instead of only a confusing downstream
# type error.
def truthy(n: int) -> bool {
    if n > 0 { return true; }
    return false;
}

def nullable() -> int {
    x = null;
    y = none;
    return 0;
}

with entry { print(truthy(5)); }
