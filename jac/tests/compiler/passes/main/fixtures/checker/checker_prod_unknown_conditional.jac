"""Production test: Unknown in conditionals must not bypass type narrowing.

When Unknown values are used in if/elif conditions or isinstance checks,
the type checker should not silently accept them. Narrowing Unknown
should either preserve Unknown or produce a diagnostic.

Unknown source: magic method resolution on Any-typed values fails,
producing genuine Unknown (e.g. Any + 1 -> Unknown).

Expected errors: 3
  1. bad1: str = x after isinstance  — type should be narrowed or flagged
  2. bad2: str = x in else branch    — Unknown not narrowable to str
  3. bad3: int = val                 — ternary with Unknown -> not int
"""

with entry {
    # Any + int -> Unknown (magic method __add__ unresolved on Any)
    items: list = [1, 2, 3];
    any_val = items.pop();
    x = any_val + 1;

    # isinstance on Unknown — should narrow or flag
    if isinstance(x, int) {
        result: int = x;            # If narrowed: Ok. If Unknown: should warn
        bad1: str = x;              # Error: narrowed int -> str (or Unknown -> str)
    } else {
        bad2: str = x;              # Error: Unknown not guaranteed to be str
    }

    # Ternary with Unknown
    val = x if isinstance(x, int) else "fallback";
    bad3: int = val;                # Error: int|str not assignable to int
}
