"""Bug #15: No generic type argument checking in class assignment.

When assigning between generic types (e.g., list[int] to list[str]),
the type checker only checks if the class is the same (shared ==)
but does NOT validate that type arguments are compatible.

Expected: list[int] should NOT be assignable to list[str].
"""

def make_int_list -> list[int] {
    return [1, 2, 3];
}

def take_str_list(items: list[str]) -> None {
    for item in items {
        ;  # Would crash at runtime if items contains ints
    }
}

with entry {
    int_list: list[int] = make_int_list();

    # This should be an error: list[int] is not assignable to list[str]
    str_list: list[str] = int_list;  # <-- Should be Error (no generic variance check)

    # Same issue through function calls
    take_str_list(int_list);  # <-- Should be Error
}
