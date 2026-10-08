"""Fixture: closures that outlive their iteration and capture a binding the loop reassigns.

Every function below holds exactly one shape that must be reported
(E2097). The captured names are unique so the test can name each case:
forLocal, typedLocal, whileLocal, stepIdx, defLocal, leftPart, rightPart,
walrusVal, rowSum, seed, deepVal, runTotal, dictKey, regVal, namedVal,
yieldVal, mapOuter, facVal, implLocal, methodVal, entryLocal.
"""

obj Registry {
    has handlers: list[Callable[[], int]] = [];

    def add(fn: Callable[[], int]) {
        self.handlers.append(fn);
    }
}

def for_body_local(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        forLocal = x * 10;
        out.append(lambda -> int { return forLocal; });
    }
    return out;
}

def typed_body_local(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        typedLocal: int = x * 10;
        out.append(lambda -> int { return typedLocal; });
    }
    return out;
}

def while_body_local(n: int) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    k = 0;
    while k < n {
        whileLocal = k * 2;
        out.append(lambda -> int { return whileLocal; });
        k += 1;
    }
    return out;
}

def counter_loop(n: int) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for stepIdx = 0 while stepIdx < n with stepIdx += 1 {
        out.append(lambda -> int { return stepIdx; });
    }
    return out;
}

def nested_def_escapes(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        defLocal = x + 1;
        def read -> int {
            return defLocal;
        }
        out.append(read);
    }
    return out;
}

def unpacked(pairs: list[tuple[int, int]]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for p in pairs {
        (leftPart, rightPart) = p;
        out.append(lambda -> int { return leftPart + rightPart; });
    }
    return out;
}

def walrus_bound(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        if (walrusVal := x * 2) > 2 {
            out.append(lambda -> int { return walrusVal; });
        }
    }
    return out;
}

def nested_loops(grid: list[list[int]]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for row in grid {
        rowSum = sum(row);
        for cell in row {
            out.append(lambda -> int { return rowSum + cell; });
        }
    }
    return out;
}

def param_reassigned(seed: int, xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        seed = seed + x;
        out.append(lambda -> int { return seed; });
    }
    return out;
}

def nested_closure(xs: list[int]) -> list[Callable[[], Callable[[], int]]] {
    out: list[Callable[[], Callable[[], int]]] = [];
    for x in xs {
        deepVal = x;
        out.append(
            lambda -> Callable[[], int] { return lambda -> int { return deepVal; }; }
        );
    }
    return out;
}

def augmented(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    runTotal = 0;
    for x in xs {
        runTotal += x;
        out.append(lambda -> int { return runTotal; });
    }
    return out;
}

def stored_in_dict(names: list[str]) -> dict[str, Callable[[], str]] {
    table: dict[str, Callable[[], str]] = {};
    for nm in names {
        dictKey = nm.upper();
        table[nm] = lambda -> str { return dictKey; };
    }
    return table;
}

def passed_to_a_callee(reg: Registry, xs: list[int]) {
    for x in xs {
        regVal = x;
        reg.add(lambda -> int { return regVal; });
    }
}

def named_then_stored(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        namedVal = x;
        handler = lambda -> int { return namedVal; };
        out.append(handler);
    }
    return out;
}

def yielded(xs: list[int]) -> Generator[Callable[[], int], None, None] {
    for x in xs {
        yieldVal = x;
        yield lambda -> int { return yieldVal; };
    }
}

def created_inside_a_combinator(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        mapOuter = x;
        out.extend(
            list(
                map(
                    lambda (v: int) -> Callable[[], int] { return lambda -> int { return v
                        + mapOuter; }; },
                    xs
                )
            )
        );
    }
    return out;
}

def parameterless_factory(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        facVal = x;
        def make -> Callable[[], int] {
            return lambda -> int { return facVal; };
        }
        out.append(make());
    }
    return out;
}

def impl_split(xs: list[int]) -> list[Callable[[], int]];

impl impl_split(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        implLocal = x;
        out.append(lambda -> int { return implLocal; });
    }
    return out;
}

obj Board {
    has cells: list[int] = [];

    def watchers -> list[Callable[[], int]] {
        out: list[Callable[[], int]] = [];
        for c in self.cells {
            methodVal = c + 1;
            out.append(lambda -> int { return methodVal; });
        }
        return out;
    }
}

glob entryHandlers: list[Callable[[], int]] = [];

with entry {
    for e in [1, 2, 3] {
        entryLocal = e * 3;
        entryHandlers.append(lambda -> int { return entryLocal; });
    }
}
