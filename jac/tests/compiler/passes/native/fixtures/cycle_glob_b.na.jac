"""Back-edge of the cyclic glob pair (issue #7593 item 11).

Has its own runtime-initialized glob and imports a getter back from
cycle_glob_a, completing the cycle.
"""

import from cycle_glob_a { get_av }

def:pub mk_bv() -> int {
    return 11 + 11;
}

glob bv: int = mk_bv();

def:pub get_bv() -> int {
    return bv;
}

def:pub read_av() -> int {
    return get_av();
}
