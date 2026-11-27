"""Share 3 of 4 of the prim equivalence cases (see prim_equiv_cases.jac)."""

with entry {
    parametrize(
        "prim equivalence",
        EQUIV_CASES[2::4],
        equiv_case,
        id_fn=lambda (c: tuple[any, ...]) { c[0]; }
    );
}
