"""Defines the C symbol slot_store in Jac, taking a pointer to a pointer."""
import from c {
    def slot_store(target: ptr[ptr[u8]]) {
        target.view(1)[0] = ptr[u8]();
    }
}

def:pub def_ready -> i64 {
    return 1;
}
