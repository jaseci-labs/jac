"""A cast target that is not a type expression is rejected (E1044)."""

def bad_parens(x: any) -> bool {
    return x as (int == 0);
}

def bad_value(x: any, y: int) -> int {
    return x as y;
}

def good_union(x: any) -> int | None {
    return x as int | None;
}

def good_generic(x: any) -> dict[str, int] {
    return x as dict[str, int];
}
