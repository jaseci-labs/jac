def sum_roundtrip(p: ptr[i64], n: i64) -> i64 {
    i: i64 = 0;
    while i < n {
        p[i] = i * 10;
        i = i + 1;
    }
    total: i64 = 0;
    j: i64 = 0;
    while j < n {
        total = total + p[j];
        j = j + 1;
    }
    return total;
}

def write_then_read(p: ptr[i64], idx: i64, val: i64) -> i64 {
    p[idx] = val;
    return p[idx];
}
