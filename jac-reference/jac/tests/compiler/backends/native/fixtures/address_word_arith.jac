"""Offsets from an address taken as a word: a constant offset cannot overflow,
an arbitrary integer can."""
import from c { glob addr_target: i64 = 0; }

def:pub addr_offset(n: i64) -> i64 {
    base = int(addressof(addr_target)) + 16;
    return base + n;
}
