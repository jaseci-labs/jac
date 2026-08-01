"""Entry module that includes a native library and calls an absorbed name."""

include na_star_reexport_lib;

def:pub inc_use(x: int) -> int {
    return star_helper(x);
}

with entry {
    print(inc_use(4));
}
