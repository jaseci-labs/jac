with entry {
    parametrize(
        "prim equivalence",
        EQUIV_CASES[1::3],
        _equiv_case,
        id_fn=lambda (c: tuple[any, ...]) { c[0]; }
    );
}
