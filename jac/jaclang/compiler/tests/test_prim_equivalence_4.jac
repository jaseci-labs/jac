"""Share 4 of 4 of the prim equivalence cases (see prim_equiv_cases.jac)."""
with entry {
    parametrize(
        "prim equivalence",
        EQUIV_CASES[3::4],
        equiv_case,
        id_fn=lambda (c: tuple[any, ...]) { c[0]; }
    );
}
