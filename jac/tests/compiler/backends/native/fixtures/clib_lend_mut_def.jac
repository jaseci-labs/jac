"""Defines the C symbols lend_store and lend_box in Jac: lend_store takes a
pointer to a pointer, lend_box the address of a two-word record."""
import from c {
    glob lend_target: i64 = 0; def lend_store(out: ptr[ptr[i64]]) -> i32 {
        out.view(1)[0] = ptr[i64](addressof(lend_target));
        return 0;
    }  def lend_box(slots: ptr[i64]) -> i64 {
        words = slots.view(2);
        words[0] = 40;
        return words[0] + words[1] + 2;
    }
}

def:pub lend_target_address -> i64 {
    return int(addressof(lend_target));
}
