"""Bug #ANY-IN-1: `x in any_value` rejected with false E1111.

Per PEP 484, Any supports all operations. Expected: 0 errors.
"""

def check(x: any) -> bool {
    return "key" in x;
}
