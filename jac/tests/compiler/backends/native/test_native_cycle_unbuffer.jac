"""Freeing an object in the cycle collector's root buffer takes constant time.

Freeing a buffered object used to search the root buffer backwards for its
slot, so each such free cost time proportional to the buffer. A release build
now records the slot in the low half of the object's alloc-id word when it
buffers the object (only debug builds read that half) and clears that slot
directly; the search remains for a debug build and as a fallback when the
recorded slot does not hold the object. The test pins the program's output
against the Python backend.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "cycle_unbuffer.jac");

test "the program prints what the Python backend prints under managed" {
    out = assert_native_identity(FIXTURE, profiles=["managed", "rc"]);
    assert out.splitlines() == ["2691000", "58820650"] , out;
}
