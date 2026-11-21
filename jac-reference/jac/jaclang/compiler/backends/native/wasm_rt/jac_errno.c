/* errno storage, wasi-libc model: the public headers declare
 * `extern _Thread_local int errno` and this TU defines it (wasm MVP has one
 * thread, so the TLS qualifier lowers to a plain global). musl's own
 * __errno_location.c is not usable here — it routes through the pthread
 * self-structure this floor doesn't carry. */
#include <errno.h>
#undef errno

_Thread_local int errno = 0;

int *__errno_location(void) {
    return &errno;
}
