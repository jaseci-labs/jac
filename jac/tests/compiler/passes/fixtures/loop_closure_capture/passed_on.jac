"""Fixture: closures handed to code the compiler cannot see into.

Every function below holds one shape that must be a warning (W2084), not
an error: the closure reaches a callee that may run it before returning
or may keep it, and nothing in this file settles which. The captured
names are unique so the test can name each case.
"""

obj Registry {
    has handlers: list[Callable[[], int]] = [];

    def add(fn: Callable[[], int]) {
        self.handlers.append(fn);
    }
}

def run_all(fns: list[Callable[[], int]]) -> int {
    return sum([fn() for fn in fns]);
}

def run_named(name: str, fns: dict[str, Callable[[], int]]) -> int {
    return fns[name]();
}

def call_with(*, target: Callable[[], int]) -> int {
    return target();
}

def passed_to_a_method(reg: Registry, xs: list[int]) {
    for x in xs {
        regVal = x;
        reg.add(lambda -> int { return regVal; });
    }
}

def passed_to_a_function(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        argVal = x;
        total += run_all([lambda -> int { return argVal; }]);
    }
    return total;
}

def passed_by_keyword(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        kwVal = x;
        total += call_with(target=lambda -> int { return kwVal; });
    }
    return total;
}

def named_then_passed(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        namedArgVal = x;
        def read -> int {
            return namedArgVal;
        }
        total += call_with(target=read);
    }
    return total;
}

def inside_a_passed_literal(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        propsVal = x;
        total += run_named("run", {"run": lambda -> int { return propsVal; }});
    }
    return total;
}

def stored_through_an_untyped_receiver(sink: any, xs: list[int]) {
    for x in xs {
        anyVal = x;
        sink.append(lambda -> int { return anyVal; });
    }
}

def fresh_list_then_passed(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        batchVal = x;
        batch: list[Callable[[], int]] = [];
        batch.append(lambda -> int { return batchVal; });
        total += run_all(batch);
    }
    return total;
}

def created_inside_a_combinator(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        mapOuter = x;
        out.extend(
            list(
                map(
                    lambda (v: int) -> Callable[[], int] {
                        return lambda -> int { return v + mapOuter; };
                    },
                    xs
                )
            )
        );
    }
    return out;
}

def captured_by_a_passed_closure(reg: Registry, xs: list[int]) {
    for x in xs {
        hopVal = x + 1;
        def helper -> int {
            return hopVal;
        }
        reg.add(lambda -> int { return helper(); });
    }
}
