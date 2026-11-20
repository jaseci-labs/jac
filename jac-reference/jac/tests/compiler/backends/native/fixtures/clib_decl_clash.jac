"""Declares slot_store with a plain pointer and passes a pointer it was given."""
import from .clib_decl_clash_def { def_ready }
import from .clib_decl_clash_mut { via_mut }
import from c { def slot_store(target: ptr[ptr[u8]]);  }

def:pub via_ptr(cell: ptr[ptr[u8]]) -> i64 {
    slot_store(cell);
    return via_mut() + def_ready();
}
