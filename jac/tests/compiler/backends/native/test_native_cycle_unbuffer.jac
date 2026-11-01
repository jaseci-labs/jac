"""Freeing an object in the cycle collector's root buffer is correct and agrees
with Python.

Freeing a buffered object has to take it out of the root buffer before its
memory goes back to the allocator. The fixture frees many buffered objects in
a loop, so a stale root or a slot cleared for the wrong object shows up as a
wrong count or a crash under the cycle collector.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "cycle_unbuffer.jac");

test "the program prints what the Python backend prints under managed" {
    out = assert_native_identity(FIXTURE, profiles=["managed", "rc"]);
    assert out.splitlines() == ["2691000", "58820650"] , out;
}
