"""The positive control for prim_sort_key_gradual: a semantic `-> str` sort
key lowers natively through the string comparator, never through strcmp."""
node Gthing {
    has name: str = "";
}

def grad_str_na -> dict[str, str] {
    things: list[Gthing] = [Gthing(name="b2"), Gthing(name="a9")];
    by_name: list[Gthing] = sorted(things, key=lambda (t: Gthing) -> str { t.name; });
    return {"s0": by_name[0].name};
}
