/* The runtime floor for wasm32 (#10219).
 *
 * The bundled native stdlib calls the __jac_* functions that posix_floor.c
 * and win_floor.c define for the other targets. A wasm module gets them from
 * here, inside the module, so none of them becomes a host import. The values
 * are the Linux ABI's, which is what wasm builds resolved to before the floor
 * existed. What the jac_host1 contract has no call for (directories, the
 * account database, the executable's path) fails the way a POSIX call
 * reports it is unsupported.
 *
 * Every signature matches the stdlib's Jac declaration exactly: a Jac `int`
 * is 64 bits, also where it carries a wasm32 pointer, and a direct call whose
 * signature differs from its definition lowers to `unreachable`.
 */
#include <errno.h>
#include <stdint.h>

#pragma STDC FP_CONTRACT OFF

int64_t __jac_errno(void) { return (int64_t)(intptr_t)&errno; }

/* The floor ends a process with _exit once it has flushed stdio itself; a
 * wasm module has no atexit handlers to skip, so it is the host's exit. */
extern void exit(int) __attribute__((noreturn));
void _exit(int code) { exit(code); }

/* The standard streams as tokens: the module has no FILE objects, and every
 * call that takes one (fwrite, fgetc, fflush) is resolved in-module or by
 * the host's stream-free contract. */
void *__jac_stdio(int32_t fd) { return (void *)(intptr_t)(fd + 1); }

/* The jac_host1 contract has no standard input. */
int32_t fgetc(void *stream) {
    (void)stream;
    return -1;
}

/* A module never runs exit handlers: the host ends it. Registration fails,
 * as C lets it, so a caller that needs the handler knows it will not run. */
int atexit(void (*handler)(void)) {
    (void)handler;
    return -1;
}

/* wasm32 has no non-local jump without the exception-handling proposal. A
 * handler still arms (setjmp returns 0, so a body that does not raise runs as
 * it does elsewhere), but a raise that reaches a handler cannot unwind to it:
 * it ends the module the way an uncaught exception does. The pair carries
 * Jac's own names: the C writer that ejects a wasm module treats calls to
 * libc's setjmp/longjmp as jmp_buf intrinsics. */
extern long write(int, const void *, unsigned long);

int __jac_wasm_setjmp(void *env) {
    (void)env;
    return 0;
}

void __jac_wasm_longjmp(void *env, int value) {
    static const char note[] =
        "jac: an exception reached a handler, which wasm32 cannot jump to\n";
    (void)env;
    (void)value;
    write(2, note, sizeof note - 1);
    exit(1);
}

/* sys.platform as the floor numbers it: 0 linux. */
int32_t __jac_platform_id(void) { return 0; }

int32_t __jac_at_fdcwd(void) { return -100; }

/* Linux clock ids, which are also WASI's for 0-3. */
int64_t __jac_clock_id(int32_t jac_clock) {
    switch (jac_clock) {
    case 0: return 0;
    case 1: return 1;
    case 2: return 2;
    case 3: return 3;
    case 4: return 4;
    case 5: return 1;
    default: return -1;
    }
}

/* The host cannot block a wasm caller; its nanosleep returns at once too. */
int32_t __jac_sleep_ns(int64_t ns) {
    (void)ns;
    return 0;
}

/* a * b + c, never fused: wasm32 has no fused multiply-add. */
double __jac_fmadd(double a, double b, double c) { return a * b + c; }

int64_t __jac_opendir(const char *path) {
    (void)path;
    errno = ENOSYS;
    return 0;
}

int64_t __jac_readdir(int64_t dir) {
    (void)dir;
    return 0;
}

int32_t __jac_closedir(int64_t dir) {
    (void)dir;
    errno = ENOSYS;
    return -1;
}

int64_t __jac_dirent_name(int64_t entry) {
    (void)entry;
    return 0;
}

int64_t __jac_home_dir(const char *name, char *buf, int64_t cap) {
    (void)name;
    (void)buf;
    (void)cap;
    return -1;
}

int64_t __jac_executable_path(char *buf, int64_t cap) {
    (void)buf;
    (void)cap;
    return -1;
}

/* struct addrinfo in the Linux layout: 0 the ai_addrlen offset, 1 the ai_addr
 * offset, 2 the ai_next offset, 3 its size, 4 AF_INET6. */
int64_t __jac_addrinfo_layout(int32_t which) {
    switch (which) {
    case 0: return 16;
    case 1: return 24;
    case 2: return 40;
    case 3: return 48;
    case 4: return 10;
    default: return -1;
    }
}

int32_t __jac_sockaddr_family(const void *address) {
    const uint8_t *raw = (const uint8_t *)address;
    return raw[0] | (raw[1] << 8);
}
