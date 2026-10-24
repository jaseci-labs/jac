"""Consumer whose only import is typed and goes through a pure re-export module."""

import type from na_star_reexport_mid { StarPoint }

def:pub typed_x(p: StarPoint) -> int {
    return p.x;
}
