"""Per-member narrowing must not lose precision the whole-union narrow had."""

obj Base {
    has label: str = "b";
}

obj Mid(Base) {
    has mid: int = 0;
}

obj Other {
    has weight: int = 0;
}

def take_mid(m: Mid) {
    print(m);
}

# Nothing survives the filter, so the narrow still falls back to the filter
# class itself rather than leaving the declared type in place.
def nothing_survives(x: (Base | None)) {
    if isinstance(x, Other) {
        print(x.weight);
    }
}

# The false edge still subtracts the filter, so `.label` on a still-optional
# value stays an error.
def negative_edge_keeps_declared(x: (Base | None)) -> str {
    if isinstance(x, Mid) {
        return "m";
    }
    return x.label;
}

# A narrowed member exposes exactly its own surface, nothing more.
def no_invented_members(x: (Base | None)) {
    if isinstance(x, Mid) {
        take_mid(x);
        print(x.missing);
    }
}
