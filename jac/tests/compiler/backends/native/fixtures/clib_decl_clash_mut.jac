"""Declares slot_store with `&mut`, the way object.jac declares _PyUnicode_InternMortal."""
import from c { def slot_store(target: &mut ptr[u8]);  }

def:pub via_mut -> i64 {
    value = ptr[u8]();
    slot_store(&mut value);
    return 1;
}
