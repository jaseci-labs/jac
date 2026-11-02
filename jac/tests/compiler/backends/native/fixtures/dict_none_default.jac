"""`dict.pop` and `dict.get` with a `None` default on dicts of raw values."""

with entry {
    tried: dict[str, float] = {"a": 1.5, "b": 2.5};
    tried.pop("a", None);
    gone = tried.pop("zz", None);
    kept = tried.pop("b", None);
    print(len(tried), gone, kept);
    if kept is not None {
        print(kept + 1.0);
    }
}

with entry {
    counts: dict[str, int] = {"x": 3};
    print(
        counts.get("x", None),
        counts.get("y", None),
        counts.pop("x", None),
        counts.pop("x", None)
    );
}

with entry {
    flags: dict[int, bool] = {1: True};
    print(flags.get(1, None), flags.pop(1, None), flags.pop(2, None));
}

with entry {
    names: dict[str, str] = {"k": "v"};
    first = names.pop("k", None);
    again = names.pop("k", None);
    print(first, again);
}
