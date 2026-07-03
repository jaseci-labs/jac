/* Console output bridge for the jac native wasm floor.
 *
 * Formatting happens IN-MODULE (musl's vsnprintf, linked from the vendored
 * bitcode), so the host never sees C varargs: the whole legacy JS dance of
 * walking va_list slots out of wasm memory to implement `env.printf` is gone.
 * The only thing that crosses the boundary is `write(fd, ptr, len)` — part of
 * the versioned jac_host1 import contract.
 *
 * LLVM's printf simplification may rewrite printf("...\n") into puts and
 * printf("%c") into putchar, so both are provided here too.
 */
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define FMT_BUF 4096

int printf(const char *fmt, ...) {
    char buf[FMT_BUF];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (n < 0) { return n; }
    size_t out = (size_t)n < sizeof buf ? (size_t)n : sizeof buf - 1;
    write(1, buf, out);
    return n;
}

int puts(const char *s) {
    size_t n = strlen(s);
    write(1, s, n);
    write(1, "\n", 1);
    return (int)(n + 1);
}

int putchar(int c) {
    unsigned char b = (unsigned char)c;
    write(1, &b, 1);
    return c;
}
