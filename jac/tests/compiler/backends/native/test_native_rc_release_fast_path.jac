"""A release that is not the last one only decrements, and frees nothing early.

The fixture keeps the previous `cur` alive in `held` across its reassignment,
so the reassignment's release only decrements, and the next `held = cur` drops
the last reference. Run as an `rc` executable, its output must match the
Python backend: a release that freed early reads `held.v` from freed memory.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "rc_release_fast_path.jac");

test "an rc executable, which takes the inlined decrement, matches the Python backend" {
    # `held` keeps the previous `cur` alive across its reassignment, so the
    # reassignment's release only decrements, and the next `held = cur` drops
    # the last reference; reading `held.v` after both checks neither freed early
    assert assert_native_identity(FIXTURE, profiles=["rc"]) == "81\n";
}
