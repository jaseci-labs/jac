"""`dict.pop` and `dict.get` with a `None` default on dicts of raw values."""

glob tried: dict[str, float] = {"a": 1.5, "b": 2.5};
with entry {
    tried.pop("a", None);
    gone = tried.pop("zz", None);
    kept = tried.pop("b", None);
    print(len(tried), gone, kept);
    if kept is not None {
        print(kept + 1.0);
    }
}

glob counts: dict[str, int] = {"x": 3};
with entry {
    print(
        counts.get("x", None),
        counts.get("y", None),
        counts.pop("x", None),
        counts.pop("x", None)
    );
}
glob flags: dict[int, bool] = {1: True};
with entry {
    print(flags.get(1, None), flags.pop(1, None), flags.pop(2, None));
}
glob names: dict[str, str] = {"k": "v"};
with entry {
    first = names.pop("k", None);
    again = names.pop("k", None);
    print(first, again);
}
