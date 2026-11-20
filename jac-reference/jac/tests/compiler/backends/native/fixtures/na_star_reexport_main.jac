"""Consumer importing names that na_star_reexport_mid re-exports via include."""

import from na_star_reexport_mid { star_helper, StarPoint, star_make }

def:pub use_star(x: int) -> int {
    return star_helper(x);
}

def:pub use_star_obj(x: int, y: int) -> int {
    p: StarPoint = star_make(x, y);
    return p.x;
}

with entry {
    print(use_star(5));
}
