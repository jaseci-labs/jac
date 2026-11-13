"""C-layout records whose sized fields default to negative literals."""

import from c {
    obj fd_pair {
        has read_end: i32 = -1,
            write_end: i32 = -1;
    }  obj narrow_values {
        has small: i8 = -128,
            short: i16 = -2,
            wide: i64 = -9223372036854775807;
    }
}

with entry {
    pair = fd_pair();
    values = narrow_values();
    print("pair", pair.read_end, pair.write_end);
    print("narrow", values.small, values.short, values.wide);
    pair.read_end = 3;
    print("set", pair.read_end, -pair.read_end);
}
