"""Impl annex for `annex_glob.na.jac` (issue #6754). This is the CANONICAL bare
annex form (`<base>.impl.jac`, base name taken before the variant suffix), the
one `discover_annex_files` resolves for a `.na.jac` head when no bare `.jac`
twin exists. The glob is declared HERE, in the annex, not the head file -- the
regression trigger. Both abilities reference it: `get_sz` as a bare `Name`,
`double_sz` inside a `BinaryExpr`, covering the two reported E5090 variants.
"""

glob SZ: int = 21;

impl get_sz() -> int {
    return SZ;
}

impl double_sz() -> int {
    return SZ * 2;
}
