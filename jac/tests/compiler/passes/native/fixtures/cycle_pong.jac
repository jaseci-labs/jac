"""Back-edge module of a two-file import cycle (issue #7593 item 11).

Imports ping back from cycle_ping, completing the cycle. Its definition
arrives at link time; the back-edge import must resolve against the entry
module's own definition instead of recompiling the entry as a dependency.
"""

import from cycle_ping { ping }

def:pub pong(n: int) -> int {
    if n <= 0 {
        return 0;
    }
    return ping(n - 1) + 1;
}
