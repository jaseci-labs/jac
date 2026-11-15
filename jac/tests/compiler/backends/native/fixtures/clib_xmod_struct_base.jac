"""A foreign struct declared in one module and embedded by value in another."""

import from c {
    obj timeval {
        has tv_sec: i64,
            tv_usec: i64;
    }
}

def total_micros(t: &timeval) -> int {
    return t.tv_sec * 1000000 + t.tv_usec;
}
