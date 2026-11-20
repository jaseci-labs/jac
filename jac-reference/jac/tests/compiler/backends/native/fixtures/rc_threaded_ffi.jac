"""A thread started through a C import. The compiler cannot see what the new
thread runs, so the call itself switches refcount updates to atomic first.
Only compiled to IR, never run."""

import from "libc.so.6" {
    def pthread_create(tid: i64, attr: i64, start: i64, arg: i64) -> i32;
}

def spawn_raw(tid: i64, start: i64) -> int {
    return pthread_create(tid, 0, start, 0);
}
