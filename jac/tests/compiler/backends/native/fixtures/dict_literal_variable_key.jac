"""Dict literals whose first key is a string held in a variable.

Each literal here is the first of its dict type in the module, so the
backend picks the dict's storage from the literal's own first pair.
"""

glob MARK: str = "_digger";

def nones(pairs: dict[str, str | None]) -> int {
    count = 0;
    for (key, value) in pairs.items() {
        if value is None {
            count += 1;
        }
    }
    return count;
}

def keyed_by_global -> dict[str, str | None] {
    return {MARK: None};
}

def keyed_by_param(name: str, off: bool) -> dict[str, str | None] {
    return {name: None if off else "1"};
}

def keyed_by_param_then_literal(name: str) -> dict[str, str | None] {
    return {name: "on", "second": None};
}

def weights(name: str) -> dict[str, float] {
    return {name: 1.5, "other": 2.5};
}

def nested(name: str) -> dict[str, list[int]] {
    return {name: [1, 2, 3]};
}

with entry {
    by_global = keyed_by_global();
    print(nones(by_global), MARK in by_global, by_global[MARK], len(by_global));
    off = keyed_by_param("door", True);
    on = keyed_by_param("door", False);
    print(nones(off), nones(on), on["door"], "door" in off, "window" in off);
    both = keyed_by_param_then_literal("first");
    print(nones(both), both["first"], both["second"], sorted(both.keys()));
    heavy = weights("lead");
    print(heavy["lead"], heavy["other"], sorted(heavy.keys()));
    held = nested("row");
    print(held["row"], len(held));
}
