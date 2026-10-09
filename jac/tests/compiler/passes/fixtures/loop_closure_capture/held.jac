"""Fixture: closures the loop provably keeps past the iteration that created them.

Every function below holds one shape that must be an error (E2097): the
closure is stored in a container, a field or a subscript that outlives the
iteration, is yielded, or is captured by a closure that is. No opaque call
stands between the closure and the place that keeps it. The captured names
are unique so the test can name each case.
"""

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

obj Watcher {
    has on_done: Callable[[], int] | None = None,
        seen: set[Callable[[], int]] = set();

    def watch(xs: list[int]) {
        for x in xs {
            fieldVal = x + 1;
            if x > 0 {
                self.on_done = lambda -> int { return fieldVal; };
            }
        }
    }

    def collect(xs: list[int]) {
        for x in xs {
            setVal = x + 1;
            self.seen.add(lambda -> int { return setVal; });
        }
    }
}

def inside_a_stored_literal(
    names: list[str]
) -> dict[str, dict[str, Callable[[], str]]] {
    table: dict[str, dict[str, Callable[[], str]]] = {};
    for nm in names {
        literalVal = nm.upper();
        table[nm] = {"run": lambda -> str { return literalVal; }};
    }
    return table;
}

def carried_by_rebinding(xs: list[int]) -> list[Callable[[], int]] {
    rows: list[Callable[[], int]] = [];
    for x in xs {
        carriedVal = x * 2;
        rows = rows + [lambda -> int { return carriedVal; }];
    }
    return rows;
}

def carried_by_augmented_assignment(xs: list[int]) -> list[Callable[[], int]] {
    acc: list[Callable[[], int]] = [];
    for x in xs {
        augVal = x * 2;
        acc += [lambda -> int { return augVal; }];
    }
    return acc;
}

def extended_and_inserted(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        extendVal = x * 2;
        out.extend([lambda -> int { return extendVal; }]);
        insertVal = x * 3;
        out.insert(0, lambda -> int { return insertVal; });
    }
    return out;
}

def captured_by_a_kept_closure(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        viaVal = x + 1;
        def helper -> int {
            return viaVal;
        }
        out.append(lambda -> int { return helper(); });
    }
    return out;
}

def kept_through_a_fresh_list(xs: list[int]) -> list[list[Callable[[], int]]] {
    out: list[list[Callable[[], int]]] = [];
    for x in xs {
        freshVal = x + 1;
        batch: list[Callable[[], int]] = [];
        batch.append(lambda -> int { return freshVal; });
        out.append(batch);
    }
    return out;
}

def handler_that_updates_the_name(xs: list[int]) -> list[Callable[[], None]] {
    out: list[Callable[[], None]] = [];
    for x in xs {
        bumpVal = x;
        out.append(lambda { bumpVal += 1; });
    }
    return out;
}

def generator_made_in_the_loop(xs: list[int]) -> list[Generator[int, None, None]] {
    out: list[Generator[int, None, None]] = [];
    for x in xs {
        genVal = x + 1;
        def later -> Generator[int, None, None] {
            yield genVal;
        }
        out.append(later());
    }
    return out;
}

async def coroutine_made_in_the_loop(xs: list[int]) -> list[int] {
    pending: list[Coroutine[any, any, int]] = [];
    for x in xs {
        asyncVal = x + 1;
        async def read -> int {
            return asyncVal;
        }
        pending.append(read());
    }
    return [await p for p in pending];
}

glob entryHandlers: list[Callable[[], int]] = [];

with entry {
    for e in [1, 2, 3] {
        entryLocal = e * 3;
        entryHandlers.append(lambda -> int { return entryLocal; });
    }
}
