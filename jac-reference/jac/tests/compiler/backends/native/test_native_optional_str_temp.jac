"""`str()` on an owned `T | None` temp must not hand back a dangling pointer.

`_emit_optional_str` extracted the optional's raw i8* payload and returned it
borrowed, while the owned optional temp was released by
`_release_owned_args(op="builtin1_arg")` immediately after the builtin call.
The `str()` result then pointed at freed memory, and the very next
`_str_alloc` -- the concat buffer for `"p=" + str(opt_call())` -- reused that
exact chunk, producing garbage like "p=p=efined signal 1". `print`-only uses
of the same expression happened to print before the block was reused, so the
use-after-free hid until a concat landed on it.

The fix gives the payload its own heap copy when the source optional is
owned -- an RC retain would be a no-op under nogc -- and marks the resulting
phi owned so the copy is released exactly once. The "None" incoming is
heap-allocated in that case too, because nogc's release is a plain free()
with no RC magic check and would free the static literal.

The fixture runs under every memory profile plus the Python backend; the
managed lane is the one that showed the corruption, since it is the profile
where the payload buffer is actually refcounted and reused.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "str() on an owned optional temp answers what CPython answers" {
    out = assert_native_identity(os.path.join(FIXTURES, "optional_str_owned_temp.jac"));
    assert "a=signal 10" in out , out;
    assert "b=None" in out , out;
    assert "c=signal 7" in out , out;
    assert "d=signal 30 tail" in out , out;
}
