"""A bare `set()` / `list()` in a ternary arm takes the other arm's flavor.

A no-argument constructor names a container and nothing about what it holds,
so the element flavor has to come from context. On one side of a branch there
is no context at all, and the only constraint in reach is the sibling arm --
the two have to agree for the ternary to have a type.

Both ways of learning that are exercised. `typed_arm` gets it from inference,
which annotates the sibling call `set[str]`. `bare_arm` cannot: its sibling is
declared `-> set` with no argument, exactly as `ts_decl_parser.collect_generics`
is, so the answer has to be read back off the arm the backend already lowered.
"""

def gen_typed -> set[str] {
    return {"a", "b"};
}


def gen_bare -> set {
    return {"a", "b", "c"};
}


def lst_bare -> list {
    return ["a", "b", "c", "d"];
}


def typed_arm(flag: bool) -> int {
    tvs = gen_typed() if flag else set();
    return len(tvs);
}


def bare_arm(flag: bool) -> int {
    tvs = gen_bare() if flag else set();
    return len(tvs);
}


def bare_list_arm(flag: bool) -> int {
    vals = lst_bare() if flag else list();
    return len(vals);
}


def grows_after_empty(flag: bool) -> int {
    tvs = gen_typed() if flag else set();
    tvs.add("z");
    tvs.add("z");
    return len(tvs);
}
