"""A list's element-kind word holds a small kind or an enum descriptor, and
the lent mark of a list of borrows on a bit no descriptor address occupies.

The mark used to be bit 8, which an enum descriptor's address often has set:
a list of enum members could read as lent, and lending one rewrote the
descriptor pointer. Every reader and writer now goes through
`__jac_rt_list_kind` and `__jac_rt_list_is_lent`.
"""
import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "list_kind_word.jac"
     );

test "owned and lent lists of enum members read as in Python under rc and nogc" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "nogc"]);
    lines = out.splitlines();
    assert "lent True False False" in lines , out;
    assert lines[-1] == "done" , out;
}
