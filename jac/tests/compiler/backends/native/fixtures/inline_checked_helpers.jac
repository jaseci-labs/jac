"""Accessors a few loads long whose every step is checked, called from
several sites, in the shape of JacPython's dict entry accessors.

A table is a header (a size-shift byte and a kind byte) followed by the
entries. `entry_key` reads one entry: the shift, the multiply by the entry
size and the view can each raise, so its body is a handful of loads plus one
raise site per check."""

import from c { def malloc(size: u64) -> ptr[u8];  def free(p: ptr[u8]);  }

glob HEADER: i64 = 16,
     SHIFT_AT: i64 = 0,
     KIND_AT: i64 = 1;

def table_shift(k: ptr[u8]) -> i64 {
    return i64((k + SHIFT_AT).view(1)[0]);
}

def table_is_wide(k: ptr[u8]) -> bool {
    return (k + KIND_AT).view(1)[0] != u8(0);
}

def table_entries(k: ptr[u8]) -> ptr[u8] {
    return k + HEADER + (1 << table_shift(k));
}

def entry_key(k: ptr[u8], ix: i64) -> i64 {
    if table_is_wide(k) {
        return ptr[i64](table_entries(k) + ix * i64(24)).view(2)[1];
    }
    return ptr[i64](table_entries(k) + ix * i64(16)).view(1)[0];
}

def set_entry_key(k: ptr[u8], ix: i64, key: i64) {
    if table_is_wide(k) {
        ptr[i64](table_entries(k) + ix * i64(24)).view(2)[1] = key;
    } else {
        ptr[i64](table_entries(k) + ix * i64(16)).view(1)[0] = key;
    }
}

def sum_keys(k: ptr[u8], n: i64) -> i64 {
    total = i64(0);
    i = i64(0);
    while i < n {
        total = total + entry_key(k, i);
        i = i + i64(1);
    }
    return total;
}

def first_and_last(k: ptr[u8], n: i64) -> i64 {
    return entry_key(k, i64(0)) * i64(1000) + entry_key(k, n - i64(1));
}

def key_or_flag(k: ptr[u8], ix: i64) -> i64 {
    try {
        return entry_key(k, ix);
    } except OverflowError {
        return i64(-1);
    }
}

with entry {
    for wide in [False, True] {
        k = malloc(u64(16 + 8 + 24 * 8));
        (k + SHIFT_AT).view(1)[0] = u8(3);
        (k + KIND_AT).view(1)[0] = u8(1) if wide else u8(0);
        i = i64(0);
        while i < i64(8) {
            set_entry_key(k, i, i * i64(10) + i64(1));
            i = i + i64(1);
        }
        print(sum_keys(k, i64(8)), first_and_last(k, i64(8)));
        print(key_or_flag(k, i64(2)), key_or_flag(k, i64(1) << i64(62)));
        free(k);
    }
}
