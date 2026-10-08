"""Fixture: closures in loops that must stay silent (no E2097, no W2084).

Each function is one exemption or one binding the loop does not share:
the closure cannot outlive its iteration, the name is not free in it, the
loop does not reassign the binding, or the binding belongs to the loop
itself.
"""

glob tally: int = 0;

def run_now(fn: Callable[[], int]) -> list[int] {
    return [fn()];
}

def invoked_immediately(xs: list[int]) -> list[int] {
    out: list[int] = [];
    for x in xs {
        iifeVal = x * 2;
        out.append((lambda -> int { return iifeVal; })());
    }
    return out;
}

def returned_from_the_loop(xs: list[int]) -> Callable[[], int] | None {
    for x in xs {
        retVal = x * 2;
        if retVal > 2 {
            return lambda -> int { return retVal; };
        }
    }
    return None;
}

def bound_through_a_parameter(xs: list[int]) -> list[Callable[[], int]] {
    def make(v: int) -> Callable[[], int] {
        return lambda -> int { return v; };
    }
    out: list[Callable[[], int]] = [];
    for x in xs {
        paramVal = x * 2;
        out.append(make(paramVal));
    }
    return out;
}

def bound_through_a_default(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        defaultVal = x * 2;
        out.append(lambda (v: int = defaultVal) -> int { return v; });
    }
    return out;
}

def assigned_before_the_loop(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    fixedVal = 10;
    for x in xs {
        out.append(lambda -> int { return fixedVal + x; });
    }
    return out;
}

def assigned_in_another_loop(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    otherVal = 0;
    for x in xs {
        otherVal = x;
    }
    for y in xs {
        out.append(lambda -> int { return otherVal + y; });
    }
    return out;
}

def loop_target(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for tgt in xs {
        out.append(lambda -> int { return tgt; });
    }
    return out;
}

def helper_called_in_its_iteration(xs: list[int]) -> list[int] {
    out: list[int] = [];
    for x in xs {
        helperVal = x * 2;
        def twice -> int {
            return helperVal * 2;
        }
        out.append(twice());
    }
    return out;
}

def sort_key(rows: list[list[int]]) -> list[list[list[int]]] {
    out: list[list[list[int]]] = [];
    for col in [0, 1] {
        keyCol = col;
        out.append(
            sorted(rows, key=lambda (r: list[int]) -> int { return r[keyCol]; })
        );
    }
    return out;
}

def builtin_combinators(xs: list[int]) -> list[list[int]] {
    out: list[list[int]] = [];
    for x in xs {
        combVal = x;
        out.append(list(map(lambda (v: int) -> int { return v + combVal; }, xs)));
        out.append(list(filter(lambda (v: int) -> bool { return v > combVal; }, xs)));
    }
    return out;
}

def local_owned_by_the_lambda(groups: list[list[int]]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for g in groups {
        out.extend(
            list(
                map(
                    lambda (v: int) -> Callable[[], int] {
                        ownVal = v * 2;
                        return lambda -> int { return ownVal; };
                    },
                    g
                )
            )
        );
    }
    return out;
}

def shadowed_by_a_parameter(xs: list[int]) -> list[Callable[[int], int]] {
    out: list[Callable[[int], int]] = [];
    for x in xs {
        shadowVal = x;
        out.append(lambda (shadowVal: int) -> int { return shadowVal + 1; });
    }
    return out;
}

def closure_after_the_loop(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    elseVal = 0;
    for x in xs {
        elseVal = x;
    } else {
        out.append(lambda -> int { return elseVal; });
    }
    return out;
}

def closure_in_the_collection(xs: list[int]) -> int {
    collVal = 1;
    for x in run_now(lambda -> int { return collVal; }) {
        collVal = x;
    }
    return collVal;
}

def named_callback_of_a_combinator(xs: list[int]) -> list[list[int]] {
    out: list[list[int]] = [];
    for x in xs {
        scaleVal = x;
        def scaled(v: int) -> int {
            return v * scaleVal;
        }
        out.append(list(map(scaled, xs)));
    }
    return out;
}

def fresh_list_used_in_its_iteration(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        localVal = x;
        batch = [lambda -> int { return localVal; }];
        total += batch[0]();
    }
    return total;
}

def kept_only_after_the_loop(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    last: Callable[[], int] | None = None;
    for x in xs {
        tailVal = x;
        last = lambda -> int { return tailVal; };
    }
    if last is not None {
        out.append(last);
    }
    return out;
}

def declared_global(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        tally += x;
        out.append(lambda -> int { return tally; });
    }
    return out;
}
