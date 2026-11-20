with entry {
    parametrize(
        "prim equivalence",
        EQUIV_CASES[2::3],
        _equiv_case,
        id_fn=lambda (c: tuple[any, ...]) { c[0]; }
    );
}
