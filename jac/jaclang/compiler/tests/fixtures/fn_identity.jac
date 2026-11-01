"""A function value keeps one identity for as long as it is the same function.

Cross-backend equivalence fixture. Executing a `def` makes one function object,
so reading its name twice gives values that compare equal, and executing the
`def` again (another factory call, another loop pass) makes a different one.
"""

def fn_identity_py -> dict[str, any] {
    def make -> Callable[[int], int] {
        def inner(x: int) -> int {
            return x + 1;
        }
        return inner;
    }

    def plain(x: int) -> int {
        return x;
    }

    def inner(x: int) -> int {
        return x + 2;
    }

    def holds(cbs: list[Callable[[int], int]], cb: Callable[[int], int]) -> int {
        n = 0;
        for c in cbs {
            if c == cb {
                n += 1;
            }
        }
        return n;
    }

    a: Callable[[int], int] = inner;
    b: Callable[[int], int] = inner;
    c: Callable[[int], int] = plain;

    made_a = make();
    made_b = make();

    cbs: list[Callable[[int], int]] = [];
    cbs.append(inner);

    per_pass: list[Callable[[int], int]] = [];
    pass_same = 0;
    for i in [1, 2] {
        def looped(x: int) -> int {
            return x;
        }
        first: Callable[[int], int] = looped;
        second: Callable[[int], int] = looped;
        if first == second {
            pass_same += 1;
        }
        per_pass.append(first);
    }

    return {
        "two_reads_equal": a == b,
        "two_reads_not_differ": not (a != b),
        "other_function_differs": a != c,
        "reads_still_call": a(1) + b(2),
        "factory_values_differ": made_a != made_b,
        "factory_value_equals_itself": made_a == made_a,
        "registered_found": holds(cbs, inner),
        "each_pass_consistent": pass_same,
        "each_pass_new_function": per_pass[0] != per_pass[1]
    };
}


def fn_identity_cl -> dict[str, any] {
    def make -> Callable[[int], int] {
        def inner(x: int) -> int {
            return x + 1;
        }
        return inner;
    }

    def plain(x: int) -> int {
        return x;
    }

    def inner(x: int) -> int {
        return x + 2;
    }

    def holds(cbs: list[Callable[[int], int]], cb: Callable[[int], int]) -> int {
        n = 0;
        for c in cbs {
            if c == cb {
                n += 1;
            }
        }
        return n;
    }

    a: Callable[[int], int] = inner;
    b: Callable[[int], int] = inner;
    c: Callable[[int], int] = plain;

    made_a = make();
    made_b = make();

    cbs: list[Callable[[int], int]] = [];
    cbs.append(inner);

    per_pass: list[Callable[[int], int]] = [];
    pass_same = 0;
    for i in [1, 2] {
        def looped(x: int) -> int {
            return x;
        }
        first: Callable[[int], int] = looped;
        second: Callable[[int], int] = looped;
        if first == second {
            pass_same += 1;
        }
        per_pass.append(first);
    }

    return {
        "two_reads_equal": a == b,
        "two_reads_not_differ": not (a != b),
        "other_function_differs": a != c,
        "reads_still_call": a(1) + b(2),
        "factory_values_differ": made_a != made_b,
        "factory_value_equals_itself": made_a == made_a,
        "registered_found": holds(cbs, inner),
        "each_pass_consistent": pass_same,
        "each_pass_new_function": per_pass[0] != per_pass[1]
    };
}


def fn_identity_na -> dict[str, any] {
    def make -> Callable[[int], int] {
        def inner(x: int) -> int {
            return x + 1;
        }
        return inner;
    }

    def plain(x: int) -> int {
        return x;
    }

    def inner(x: int) -> int {
        return x + 2;
    }

    def holds(cbs: list[Callable[[int], int]], cb: Callable[[int], int]) -> int {
        n = 0;
        for c in cbs {
            if c == cb {
                n += 1;
            }
        }
        return n;
    }

    a: Callable[[int], int] = inner;
    b: Callable[[int], int] = inner;
    c: Callable[[int], int] = plain;

    made_a = make();
    made_b = make();

    cbs: list[Callable[[int], int]] = [];
    cbs.append(inner);

    per_pass: list[Callable[[int], int]] = [];
    pass_same = 0;
    for i in [1, 2] {
        def looped(x: int) -> int {
            return x;
        }
        first: Callable[[int], int] = looped;
        second: Callable[[int], int] = looped;
        if first == second {
            pass_same += 1;
        }
        per_pass.append(first);
    }

    return {
        "two_reads_equal": a == b,
        "two_reads_not_differ": not (a != b),
        "other_function_differs": a != c,
        "reads_still_call": a(1) + b(2),
        "factory_values_differ": made_a != made_b,
        "factory_value_equals_itself": made_a == made_a,
        "registered_found": holds(cbs, inner),
        "each_pass_consistent": pass_same,
        "each_pass_new_function": per_pass[0] != per_pass[1]
    };
}
