"""Middle of the glob-init ordering chain (issue #7593 item 11).

bval reads the leaf's runtime-initialized glob at init time, so the leaf's
glob initializer must run before this module's initializer.
"""

import from glob_chain_leaf { get_c }

glob bval: int = get_c();

def:pub get_b() -> int {
    return bval;
}
