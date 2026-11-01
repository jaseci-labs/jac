"""List loops agree with Python whether or not their body can change the list.

A range loop whose body cannot change a list header (no calls but a few
builtins, no reassignment of the list, no slice store, no `del`) indexes a
list whose length and data cannot move under it; a loop whose body runs user
code (a shadowed builtin, a nested call, an append, a getter) can change the
list it indexes, and every element read and write must see that change, and
anything out of range must raise.

Both fixtures print what the Python backend prints under rc and managed.
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

test "loops whose body can run user code see the list it changes" {
    out = assert_native_identity(USER_CODE_FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[:4]
        == ["caught 5", "caught 6", "150 411", "caught 6"] , out;
}
