"""Fixture: identity tests against another module's untyped singletons.

The importer has to see `FIRST` and `SECOND` with the type their initializer
gives them, as the declaring module does; read as bare integers, `is` against
an option either refused to lower or compared the wrong words.
"""
import from glob_identity_lib { Code, FIRST, SECOND }

obj Report {
    has code: (Code | None) = None;
}

def matches_first(item: Report) -> bool {
    return item.code is FIRST;
}

def identity_mask -> int {
    first = Report(code=FIRST);
    second = Report(code=SECOND);
    missing = Report();
    return (1 if matches_first(first) else 0) * 100
        + (1 if matches_first(second) else 0) * 10
        + (1 if matches_first(missing) else 0)
        + (1000 if FIRST is SECOND else 0);
}

def singleton_name_length -> int {
    return len(SECOND.name);
}
