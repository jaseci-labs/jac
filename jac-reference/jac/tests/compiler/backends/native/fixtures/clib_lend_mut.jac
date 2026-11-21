"""Lends locals with `&mut` to C functions: a pointer variable whose callee
takes a plain pointer to a pointer (the shape dict.jac gives PyDict_Pop while
other modules declare it `&mut`) gets its address, an obj gets its storage."""
import from .clib_lend_mut_def { lend_target_address }
import from c {
    obj LendBox {
        has first: i64 = 0,
            second: i64 = 0;
    }  def lend_store(out: ptr[ptr[i64]]) -> i32;  def lend_box(
        slots: &mut LendBox
    ) -> i64;
}

def:pub lend_run -> i64 {
    seen = ptr[i64]();
    if lend_store(&mut seen) != 0 {
        return -1;
    }
    if int(seen) == lend_target_address() {
        return 1;
    }
    return 0;
}

def:pub lend_box_run -> i64 {
    slots = LendBox();
    return lend_box(&mut slots);
}
