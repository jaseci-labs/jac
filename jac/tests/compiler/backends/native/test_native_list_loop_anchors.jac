"""List loops that may or may not change the list they index.

A range loop whose body cannot change a list header may read the list's length
and data pointer once before the loop; a loop whose body can run user code,
reassign the list, store into a slice or `del` from it must see every change.
Either way an out-of-range access raises as before. The fixtures print what
the Python backend prints under rc and managed.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "list_loop_anchors.jac"),
     USER_CODE_FIXTURE: str = os.path.join(
         NATIVE_FIXTURES, "list_loop_anchors_user_code.jac"
     );

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert "caught 2.0 4.0" in out , out;
}

test "loops whose body can run user code keep the old access" {
    out = assert_native_identity(USER_CODE_FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[:4]
        == ["caught 5", "caught 6", "150 411", "caught 6"] , out;
}
