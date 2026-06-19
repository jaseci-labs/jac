"""Impl annex for `annex_glob.na.jac` (issue #6754). The glob is declared HERE,
in the annex, not the head file — this is the regression trigger. Both abilities
reference it: `get_sz` as a bare `Name`, `double_sz` inside a `BinaryExpr`,
covering the two reported E5090 variants.
"""

glob SZ: int = 21;

impl get_sz() -> int {
    return SZ;
}

impl double_sz() -> int {
    return SZ * 2;
}
