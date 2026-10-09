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

def list_reset_on_some_paths(xs: list[int]) -> list[Callable[[], int]] {
    batch: list[Callable[[], int]] = [];
    for x in xs {
        resetVal = x;
        if x == 0 {
            batch = [];
        }
        batch.append(lambda -> int { return resetVal; });
    }
    return batch;
}

def taken_out_of_a_fresh_list(xs: list[int]) -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in xs {
        extractVal = x + 1;
        batch = [lambda -> int { return extractVal; }];
        out.append(batch[0]);
    }
    return out;
}

def one_field_of_a_fresh_dict_is_stored(xs: list[int]) -> list[any] {
    out: list[any] = [];
    for x in xs {
        pickVal = x;
        record: dict[str, any] = {"run": lambda -> int { return pickVal; }, "id": x};
        record["run"]();
        out.append(record["id"]);
    }
    return out;
}

obj Button {
    has label: str,
        on_click: Callable[[], str] | None = None;
}

def field_of_the_loop_target(buttons: list[Button]) {
    for btn in buttons {
        targetVal = btn.label.upper();
        btn.on_click = lambda -> str { return targetVal; };
    }
}

def stored_through_an_alias(table: list[list[Callable[[], int]]], xs: list[int]) {
    for x in xs {
        aliasVal = x;
        row = table[x % 2];
        row.append(lambda -> int { return aliasVal; });
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

def captured_by_a_passed_closure(reg: Registry, xs: list[int]) {
    for x in xs {
        hopVal = x + 1;
        def helper -> int {
            return hopVal;
        }
        reg.add(lambda -> int { return helper(); });
    }
}
