/* i64 ABI adapters between the jac native floor and the wasm32 libc.
 *
 * The floor declares libc externs with 64-bit size_t/long (jac ints are i64);
 * on wasm32 the real libc uses i32. A direct call with a mismatched signature
 * is lowered by the wasm backend to `unreachable` — the module traps at the
 * first strlen. So wasm_build renames the floor's mismatched declarations to
 * __jac64_<name> before linking, and these adapters (whose signatures match
 * the floor's declarations exactly) truncate/extend and forward.
 *
 * Only functions DEFINED in the vendored libc need adapters — imports keep
 * the floor's declared signature, and the JS host is signature-agnostic.
 * The list must stay in sync with _ABI64_ADAPTED in wasm_build.jac.
 */
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef long long i64;

extern void *memmem(const void *, size_t, const void *, size_t);
extern size_t malloc_usable_size(void *);

i64 __jac64_strlen(const char *s) { return (i64)strlen(s); }

void *__jac64_malloc(i64 n) { return malloc((size_t)n); }

void *__jac64_calloc(i64 a, i64 b) { return calloc((size_t)a, (size_t)b); }

void *__jac64_realloc(void *p, i64 n) { return realloc(p, (size_t)n); }

i64 __jac64_malloc_usable_size(void *p) { return (i64)malloc_usable_size(p); }

void *__jac64_memcpy(void *d, const void *s, i64 n) {
    return memcpy(d, s, (size_t)n);
}

void *__jac64_memmove(void *d, const void *s, i64 n) {
    return memmove(d, s, (size_t)n);
}

void *__jac64_memset(void *p, int v, i64 n) {
    return memset(p, v, (size_t)n);
}

int __jac64_memcmp(const void *a, const void *b, i64 n) {
    return memcmp(a, b, (size_t)n);
}

void *__jac64_memmem(const void *h, i64 hl, const void *nd, i64 nl) {
    return memmem(h, (size_t)hl, nd, (size_t)nl);
}

int __jac64_strncmp(const char *a, const char *b, i64 n) {
    return strncmp(a, b, (size_t)n);
}

i64 __jac64_strtol(const char *s, char **end, int base) {
    return (i64)strtol(s, end, base);
}

int __jac64_snprintf(char *buf, i64 n, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int r = vsnprintf(buf, (size_t)n, fmt, ap);
    va_end(ap);
    return r;
}
