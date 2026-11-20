"""Fixture for implicit-return placement and type rules.

A trailing expression without ';' is an implicit return only at the end of a
function, ability, or lambda body (E2084 elsewhere); it participates in
return-type checking (E1002) like an explicit return.
"""

def ok_tail(n: int) -> int {
    n * 2
}

def misplaced_in_if(n: int) -> int {
    if n > 0 {
        n + 1
    }
    return 0;
}

def wrong_type_tail -> int {
    "not an int"
}

glob misplaced_at_module_level = 5;

with entry {
    misplaced_at_module_level + 1
}
