"""Droppless affine inference for unannotated locals (#7857 Phase E).

A LOCAL binding with no ownership annotation whose object never escapes --
scalar field reads under calls and returns included -- may live on the stack
in managed modes too, because for a type with no `drop` hook the reclamation
point is unobservable. Types with a `drop` hook are excluded, so hook timing
never changes: the program prints what the Python backend prints, `bye`
included, in the same place.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "affine_inference.jac"
     );

test "promotion leaves output and drop-hook timing as the Python backend has them" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert "bye" in out.splitlines() and out.splitlines()[-1] == "end" , out;
}
