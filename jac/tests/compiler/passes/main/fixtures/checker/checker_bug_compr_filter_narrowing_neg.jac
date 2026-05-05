obj NameAtom { has sym_name: str = ""; }
obj OtherPattern { has code: int = 0; }

def bad_no_filter(items: list[NameAtom | OtherPattern]) -> list[str] {
    return [x.sym_name for x in items];  # error: no isinstance filter, x is still NameAtom | OtherPattern
}

def bad_wrong_attr(items: list[NameAtom | OtherPattern]) -> list[int] {
    return [x.code for x in items if isinstance(x, NameAtom)];  # error: code is on OtherPattern not NameAtom
}
