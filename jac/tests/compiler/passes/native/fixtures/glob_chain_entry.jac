"""Entry of the glob-init ordering chain (issue #7593 item 11).

Dependencies must run their glob initializers before dependents:
leaf first, then mid, then this module.
"""

import from glob_chain_mid { get_b }

def:pub read_chain() -> int {
    return get_b();
}

with entry {}
