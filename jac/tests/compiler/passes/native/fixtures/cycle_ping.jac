"""Entry module of a two-file import cycle (issue #7593 item 11).

Imports pong from cycle_pong, which imports ping back from this module.
Mutual recursion across the cycle: ping(n) counts n down to 0, so
ping(n) == n for any non-negative n.
"""

import from cycle_pong { pong }

def:pub ping(n: int) -> int {
    if n <= 0 {
        return 0;
    }
    return pong(n - 1) + 1;
}

with entry {}
