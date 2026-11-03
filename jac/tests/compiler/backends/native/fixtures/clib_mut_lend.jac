"""`&mut x` passed through a C declaration to a symbol a Jac module defines."""
import from .clib_mut_lend_lib { lend_lib_ready }

import from c {
    def lend_store_i32(target: &mut i32, value: i32);  def lend_store_i64(
        target: &mut i64, value: i64
    ) -> i32;
}

# The out-variable is never read again: the call must still lend its address.
def:pub store_unread -> i64 {
    overflow = i32(0);
    lend_store_i32(&mut overflow, i32(5));
    return lend_lib_ready();
}

# The out-variable is reassigned after the call on one path.
def:pub store_reassigned(fallback: i64) -> i64 {
    value: i64 = 0;
    if lend_store_i64(&mut value, 41) == i32(0) {
        value = fallback;
    }
    return value + 1;
}
