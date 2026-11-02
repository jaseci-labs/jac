"""Borrow inference: a local that only names what something else keeps alive is not counted.

The ownership pass infers a local a borrow when every bind is `None` or a
place (`.field` and `list[index]` steps from a parameter, `self`, another
borrow or a local bound once), and nothing in the function may write that
path or run code it cannot see; codegen then binds it without a retain and
never releases it. The fixture's `must_*` functions would read a freed object
if a counted local were wrongly treated as a borrow, so the program must print
what the Python backend prints under both refcounting profiles.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "borrow_infer.jac");

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
}
