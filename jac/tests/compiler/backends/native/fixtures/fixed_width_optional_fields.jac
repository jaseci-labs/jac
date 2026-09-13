"""Sized casts consume flow-narrowed optional fields through inherited layouts."""
obj Position {
    has end: int | None;
}

obj Pattern(Position) {
    has end: int | None;
}

def read_end(value: Pattern) -> i64 {
    if value.end is not None {
        return i64(value.end);
    }
    return i64(-1);
}

def present_end -> int {
    return int(read_end(Pattern(end=42)));
}
def absent_end -> int {
    return int(read_end(Pattern(end=None)));
}
