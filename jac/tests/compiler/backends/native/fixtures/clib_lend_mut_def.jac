"""Defines the C symbol lend_store in Jac, taking a pointer to a pointer."""
import from c {
    glob lend_target: i64 = 0; def lend_store(out: ptr[ptr[i64]]) -> i32 {
        out.view(1)[0] = ptr[i64](addressof(lend_target));
        return 0;
    }
}

def:pub lend_target_address -> i64 {
    return int(addressof(lend_target));
}
