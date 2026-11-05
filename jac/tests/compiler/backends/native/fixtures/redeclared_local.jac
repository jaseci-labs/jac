"""One local name declared with a different type in two places of a function,
as js_engine's ToTemporalDurationValue reuses `s` (a str, then an int)."""

def seconds_of(item: list[any], text: bool) -> float {
    if text {
        s: str = "PT5S";
        return float(len(s));
    }
    s: int = item[0];
    return float(s) * 2.0;
}

def label_then_count(row: list[any]) -> int {
    v: str = "row";
    print(v, len(row));
    v: int = row[0];
    return int(v) + 1;
}

with entry {
    print(seconds_of([21], False), seconds_of([21], True));
    print(label_then_count([12, 30]));
}
