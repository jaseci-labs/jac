"""Must fail (E1406): a local bound to a string literal infers `imm`, and an
`imm` value enters an owned list only by copy."""
def run -> int {
    lit = "x";
    xs: own list[str] = [];
    xs.append(lit);
    return len(xs);
}

with entry {
    print(run());
}
