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
