"""Test isinstance narrowing within AND conditions.

When isinstance(x, T) is the LHS of an AND expression, the RHS should see
x narrowed to T. This enables patterns like:
    if isinstance(nd, IfStmt) and nd.body { ... }
"""

obj Base {
    has name: str = "";
}

obj Child(Base) {
    has extra: int = 0;
}

obj Other(Base) {
    has label: str = "";
}

# isinstance in AND — RHS should see narrowed type
def check_and(nd: Base) -> int {
    if isinstance(nd, Child) and nd.extra > 10 {
        return nd.extra;
    }
    return 0;
}

# isinstance with tuple of types in AND
def check_tuple_and(nd: Base) -> str {
    if isinstance(nd, (Child, Other)) and nd.name == "test" {
        return nd.name;
    }
    return "";
}

# Multi-condition AND: isinstance first, then attribute access
def check_multi_and(nd: Base, flag: bool) -> int {
    if isinstance(nd, Child) and flag and nd.extra > 0 {
        return nd.extra;
    }
    return 0;
}

# Attribute that only exists on subtype — should NOT error in AND guard
def check_subtype_attr(nd: Base) -> bool {
    if isinstance(nd, Child) and nd.extra == 42 {
        return True;
    }
    return False;
}
