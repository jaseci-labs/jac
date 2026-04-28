"""Test optional chaining (?.) type resolution."""

obj Base {
    has name: str = "";
}

obj Extended(Base) {
    has extra: int = 0;
}

def check_optional_chaining(b: Base, maybe: Base | None) {
    # ?. on attribute that exists — should not produce E1030
    val = b?.name;

    # ?. on attribute that does NOT exist on Base — should NOT error
    missing = b?.extra;

    # ?. on None-able type — should not error
    safe = maybe?.name;

    # ?. on None-able with missing attr — should not error
    also_safe = maybe?.extra;

    # Regular access on missing attr — SHOULD error (E1030)
    bad = b.extra;
}
