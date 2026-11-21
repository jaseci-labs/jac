"""Bug #LITWIDEN: literal types inferred from initializers must widen for
mutable variables and container elements.

When a mutable variable or container element type is inferred from a
literal initializer, the checker kept the `Literal[...]` type instead of
widening to the base type (`str`/`int`/`bool`). Any later store of a
different value then failed with E1001. Standard checkers (mypy, pyright)
widen literals in these mutable-declaration positions and reserve
`Literal` for explicit annotations, `Final`, and expression-position
inference.

Every mutation below is legal once literals widen, so this fixture must
type-check with zero errors.
"""

def scalar_local {
    # Already widened before the fix; kept as a guard.
    x = "";
    x = "hello";
}

def list_literal {
    # ["."] must infer list[str], not list[Literal["."]].
    xs = ["."];
    xs[0] = "B";
}

def list_multiply {
    # The issue's canonical repro: ["."] * 3 -> list[str].
    row = ["."] * 3;
    row[0] = "B";
}

def nested_grid {
    # list[list[str]], not list[list[Literal["."]]] — a game grid where
    # no tile could otherwise ever be placed.
    grid = [["." for _c in range(3)] for _r in range(3)];
    grid[0][0] = "B";
}

def dict_values {
    # {"key": "value"} must infer dict[str, str].
    d = {"seed": "value"};
    d["seed"] = "other";
    d["fresh"] = "entry";
}

def literal_narrowing_preserved(flag: str) -> int {
    # Widening applies only to the *declared* type; the expression itself
    # keeps its literal type so equality narrowing still works.
    if flag == "on" {
        return 1;
    }
    return 0;
}
