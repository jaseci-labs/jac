"""The process environment as it is now: the C `environ` array, which setenv
and putenv update. /proc/self/environ holds only the environment the process
started with, so it misses what the launcher sets before running the engine
(the engine's own `bin` on PATH, SSL_CERT_FILE) and anything set since."""

import from engine.src.runtime.mem { read_ptr, str_from_foreign_cstr }
import from engine.src.ffi.libdl { dlsym, RTLD_DEFAULT }

"""Every KEY=VALUE entry of the live environment, in order. libc's `environ`
is read through its address, since setenv may move the array."""
def:pub environ_entries -> list[str] {
    out: list[str] = [];
    slot: int = dlsym(RTLD_DEFAULT, "environ");
    if slot == 0 {
        return out;
    }
    table: int = read_ptr(slot, 0);
    if table == 0 {
        return out;
    }
    i: int = 0;
    while True {
        item: int = read_ptr(table, 8 * i);
        if item == 0 {
            return out;
        }
        out.append(str_from_foreign_cstr(item));
        i = i + 1;
    }
}
