# Lambda with parenthesized typed parameters, and subscripted generic
# annotations on paren-less params (#6773).
with entry {
    add = lambda (x: int, y: int) -> int { x + y; };
    first = lambda (d: list[int]) { d[0]; };
    lookup = lambda (d: dict[str, int]) { d["n"]; };
    print(add(2, 3), first([9, 8]), lookup({"n": 5}));
}
