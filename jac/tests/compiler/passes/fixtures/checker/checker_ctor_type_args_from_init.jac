"""A class whose `__new__` takes anything is typed by the `__init__` a call matches.

`dict` declares `__new__(cls, *args, **kwargs)`, which says nothing of the
keys or the values; its `__init__` overloads do. Every use below is right,
and each reads the copy as the typed dict it is.
"""
import from collections { OrderedDict }

def copied(fields: dict[str, str]) -> str {
    copy = dict(fields);
    return copy.get("angle", "0").strip();
}

def paired(pairs: list[tuple[str, int]]) -> int {
    table = dict(pairs);
    total: int = table["a"];
    for (name, count) in table.items() {
        total += count + len(name);
    }
    return total;
}

def from_items(fields: dict[str, str]) -> dict[str, str] {
    made = dict(fields.items());
    return made;
}

def by_keywords -> dict[str, int] {
    made = dict(a=1, b=2);
    return made;
}

def with_more(fields: dict[str, str]) -> dict[str, str] {
    made = dict(fields, extra="x");
    return made;
}

def from_literal -> dict[int, str] {
    made = dict({1: "one"});
    return made;
}

def from_literal_pairs -> dict[str, float] {
    made = dict([("a", 1.5), ("b", 2.5)]);
    return made;
}

def ordered(pairs: list[tuple[str, int]]) -> OrderedDict[str, int] {
    made = OrderedDict(pairs);
    return made;
}

def empty_then_filled -> dict[str, float] {
    made: dict[str, float] = dict();
    made["a"] = 1.5;
    return made;
}

def a_list_still(names: list[str]) -> list[str] {
    made = list(names);
    return made;
}
