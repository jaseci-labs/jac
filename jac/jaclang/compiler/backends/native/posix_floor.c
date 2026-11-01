/*
 * The native runtime's POSIX floor (#10219).
 *
 * Generated code and the bundled native stdlib call these __jac_* functions
 * instead of reading a C library's record layouts, symbol spellings or
 * constants themselves, so the IR they lower to is the same for every 64-bit
 * target. This file holds what differs: it is compiled once per target
 * against that target's own C headers (scripts/gen_posix_floor.jac, which
 * writes posix_floor_ir.jac), and the link glue of an ELF or Mach-O artifact
 * carries the target's IR. A Windows artifact gets the same functions from
 * win_floor.c.
 *
 * Every function is hidden: the floor is part of each artifact, never part of
 * a shared library's exported surface.
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <netdb.h>
#include <stddef.h>
#include <sys/socket.h>
#include <netinet/in.h>
#if defined(__APPLE__)
#include <mach-o/dyld.h>
#include <malloc/malloc.h>
#include <sys/mount.h>
#else
#include <malloc.h>
#include <sys/statfs.h>
#include <sys/syscall.h>
#endif
#define JAC_FLOOR __attribute__((visibility("hidden")))

/* ---- errno and the standard streams ---- */

JAC_FLOOR int *__jac_errno(void) { return &errno; }

JAC_FLOOR FILE *__jac_stdio(int fd) {
    if (fd == 0) return stdin;
    if (fd == 1) return stdout;
    return stderr;
}

/* Which sys.platform this is: 0 linux, 1 darwin, 2 win32. */
JAC_FLOOR int __jac_platform_id(void) {
#if defined(__APPLE__)
    return 1;
#else
    return 0;
#endif
}

/* ---- files and directories ---- */

/* stat(2) without its record: out[0] mode, out[1] size, out[2] and out[3]
 * the modification time's seconds and nanoseconds. Linux goes through the
 * newfstatat system call, which every glibc reaches the same way (glibc
 * before 2.33 exports no `stat` symbol at all). */
JAC_FLOOR int __jac_stat(const char *path, int64_t *out) {
    struct stat st;
#if defined(__APPLE__)
    if (stat(path, &st) != 0) return -1;
    out[2] = (int64_t)st.st_mtimespec.tv_sec;
    out[3] = (int64_t)st.st_mtimespec.tv_nsec;
#else
    if (syscall(SYS_newfstatat, AT_FDCWD, path, &st, 0) != 0) return -1;
    out[2] = (int64_t)st.st_mtim.tv_sec;
    out[3] = (int64_t)st.st_mtim.tv_nsec;
#endif
    out[0] = (int64_t)st.st_mode;
    out[1] = (int64_t)st.st_size;
    return 0;
}

JAC_FLOOR void *__jac_opendir(const char *path) { return opendir(path); }

JAC_FLOOR void *__jac_readdir(void *dir) { return readdir((DIR *)dir); }

JAC_FLOOR int __jac_closedir(void *dir) { return closedir((DIR *)dir); }

JAC_FLOOR const char *__jac_dirent_name(void *entry) {
    return ((struct dirent *)entry)->d_name;
}

JAC_FLOOR int __jac_at_fdcwd(void) { return AT_FDCWD; }

/* A directory entry's d_type (DT_UNKNOWN where the C library records none)
 * and inode number. */
JAC_FLOOR int64_t __jac_dirent_type(void *entry) {
#if defined(_DIRENT_HAVE_D_TYPE) || defined(__APPLE__)
    return ((struct dirent *)entry)->d_type;
#else
    (void)entry;
    return DT_UNKNOWN;
#endif
}

JAC_FLOOR uint64_t __jac_dirent_ino(void *entry) {
    return (uint64_t)((struct dirent *)entry)->d_ino;
}

JAC_FLOOR int __jac_dirfd(void *dir) { return dirfd((DIR *)dir); }

JAC_FLOOR void *__jac_fdopendir(int fd) { return fdopendir(fd); }

JAC_FLOOR void __jac_rewinddir(void *dir) { rewinddir((DIR *)dir); }

/* The target's whole struct stat of a path, of a symbolic link itself, of an
 * open descriptor and of a path relative to a directory descriptor. Linux
 * makes the system calls glibc's wrappers make (its struct stat is the
 * kernel's on x86-64 and AArch64), since glibc before 2.33 exports no stat
 * symbols. */
JAC_FLOOR int __jac_stat_record(const char *path, void *out) {
#if defined(__APPLE__)
    return stat(path, (struct stat *)out);
#else
    return (int)syscall(SYS_newfstatat, AT_FDCWD, path, out, 0);
#endif
}

JAC_FLOOR int __jac_lstat_record(const char *path, void *out) {
#if defined(__APPLE__)
    return lstat(path, (struct stat *)out);
#else
    return (int)syscall(SYS_newfstatat, AT_FDCWD, path, out, AT_SYMLINK_NOFOLLOW);
#endif
}

JAC_FLOOR int __jac_fstat_record(int fd, void *out) {
#if defined(__APPLE__)
    return fstat(fd, (struct stat *)out);
#else
    return (int)syscall(SYS_fstat, fd, out);
#endif
}

JAC_FLOOR int __jac_fstatat_record(int dir_fd, const char *path, void *out, int flags) {
#if defined(__APPLE__)
    return fstatat(dir_fd, path, (struct stat *)out, flags);
#else
    return (int)syscall(SYS_newfstatat, dir_fd, path, out, flags);
#endif
}

/* The target's struct statfs of a path and of an open descriptor. */
JAC_FLOOR int __jac_statfs_record(const char *path, void *out) {
    return statfs(path, (struct statfs *)out);
}

JAC_FLOOR int __jac_fstatfs_record(int fd, void *out) {
    return fstatfs(fd, (struct statfs *)out);
}

/* The home directory of user `name` (the calling user when it is empty):
 * its length, -1 when there is no such user, or -2 when the user has no home
 * directory. It is copied into buf only when it fits; a length of cap or more
 * asks the caller to call again with a larger buf. The record buffer grows
 * while the lookup reports ERANGE, so a large account record still resolves. */
JAC_FLOOR int64_t __jac_home_dir(const char *name, char *buf, int64_t cap) {
    struct passwd pw;
    struct passwd *found = NULL;
    size_t size = 4096;
    char *scratch = NULL;
    int rc;
    for (;;) {
        char *grown = realloc(scratch, size);
        if (grown == NULL) {
            free(scratch);
            return -1;
        }
        scratch = grown;
        rc = name[0] ? getpwnam_r(name, &pw, scratch, size, &found)
                     : getpwuid_r(getuid(), &pw, scratch, size, &found);
        if (rc != ERANGE) break;
        size *= 2;
    }
    int64_t out;
    if (rc != 0 || found == NULL) {
        out = -1;
    } else if (pw.pw_dir == NULL) {
        out = -2;
    } else {
        size_t n = strlen(pw.pw_dir);
        if ((int64_t)n < cap) memcpy(buf, pw.pw_dir, n + 1);
        out = (int64_t)n;
    }
    free(scratch);
    return out;
}

/* The running executable's path copied into buf: its length, or -1. */
JAC_FLOOR int64_t __jac_executable_path(char *buf, int64_t cap) {
#if defined(__APPLE__)
    uint32_t size = (uint32_t)cap;
    if (_NSGetExecutablePath(buf, &size) != 0) return -1;
    return (int64_t)strlen(buf);
#else
    ssize_t n = readlink("/proc/self/exe", buf, (size_t)(cap - 1));
    if (n <= 0) return -1;
    buf[n] = 0;
    return (int64_t)n;
#endif
}

/* ---- sockets ---- */

/* struct addrinfo's layout and the IPv6 family: 0 the ai_addrlen offset,
 * 1 the ai_addr offset, 2 the ai_next offset, 3 sizeof(struct addrinfo),
 * 4 AF_INET6. */
JAC_FLOOR int64_t __jac_addrinfo_layout(int which) {
    switch (which) {
    case 0: return (int64_t)offsetof(struct addrinfo, ai_addrlen);
    case 1: return (int64_t)offsetof(struct addrinfo, ai_addr);
    case 2: return (int64_t)offsetof(struct addrinfo, ai_next);
    case 3: return (int64_t)sizeof(struct addrinfo);
    case 4: return (int64_t)AF_INET6;
    default: return -1;
    }
}

JAC_FLOOR int __jac_sockaddr_family(const void *address) {
    return ((const struct sockaddr *)address)->sa_family;
}

/* ---- clocks ---- */

/* The runtime names a clock by its Jac id: 0 realtime, 1 monotonic, 2 process
 * CPU time, 3 thread CPU time, 4 raw monotonic, 5 the clock Python's
 * time.monotonic() reads. The target's clockid_t for it, or -1. */
JAC_FLOOR int64_t __jac_clock_id(int jac_clock) {
    switch (jac_clock) {
    case 0: return (int64_t)CLOCK_REALTIME;
    case 1: return (int64_t)CLOCK_MONOTONIC;
    case 2: return (int64_t)CLOCK_PROCESS_CPUTIME_ID;
    case 3: return (int64_t)CLOCK_THREAD_CPUTIME_ID;
    case 4: return (int64_t)CLOCK_MONOTONIC_RAW;
#if defined(__APPLE__)
    case 5: return (int64_t)CLOCK_UPTIME_RAW;
#else
    case 5: return (int64_t)CLOCK_MONOTONIC;
#endif
    default: return -1;
    }
}

/* Sleep `ns` nanoseconds, resuming across signals. 0, or the errno code. */
JAC_FLOOR int __jac_sleep_ns(int64_t ns) {
#if defined(__APPLE__)
    struct timespec req = {(time_t)(ns / 1000000000), (long)(ns % 1000000000)};
    struct timespec rem;
    while (nanosleep(&req, &rem) != 0) {
        if (errno != EINTR) return errno;
        req = rem;
    }
    return 0;
#else
    struct timespec deadline;
    if (clock_gettime(CLOCK_MONOTONIC, &deadline) != 0) return errno;
    deadline.tv_sec += (time_t)(ns / 1000000000);
    deadline.tv_nsec += (long)(ns % 1000000000);
    if (deadline.tv_nsec >= 1000000000) {
        deadline.tv_nsec -= 1000000000;
        deadline.tv_sec += 1;
    }
    int rc;
    do {
        rc = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &deadline, NULL);
    } while (rc == EINTR);
    return rc;
#endif
}

/* ---- memory and arithmetic ---- */

JAC_FLOOR size_t __jac_malloc_size(void *p) {
#if defined(__APPLE__)
    return malloc_size(p);
#else
    return malloc_usable_size(p);
#endif
}

/* a * b + c the way the target's own Python computes it: fused on aarch64,
 * where C compilers contract it by default, separate on x86-64. */
JAC_FLOOR double __jac_fmadd(double a, double b, double c) {
#if defined(__aarch64__)
    return __builtin_fma(a, b, c);
#else
    return a * b + c;
#endif
}

/* CPUID leaf `leaf`, sub-leaf `subleaf` as eax, ebx, ecx and edx in out[0..3];
 * zeros off x86-64. */
JAC_FLOOR void __jac_cpuid(uint32_t leaf, uint32_t subleaf, uint32_t *out) {
#if defined(__x86_64__)
    /* A plain cpuid statement rather than <cpuid.h>'s macro, whose dialect
     * alternatives (xchg%(q%|%)) the C backend cannot hand to a C compiler. */
    __asm__ volatile("cpuid"
                     : "=a"(out[0]), "=b"(out[1]), "=c"(out[2]), "=d"(out[3])
                     : "a"(leaf), "c"(subleaf));
#else
    (void)leaf;
    (void)subleaf;
    out[0] = out[1] = out[2] = out[3] = 0;
#endif
}

/* Write `text` to the unified system log at os_log type `type` (macOS); a
 * no-op elsewhere. This is <os/log.h>'s os_log_with_type(OS_LOG_DEFAULT,
 * type, "%{public}s", text) written out, so the floor builds without the
 * macOS SDK: the record is formatted by the compiler's os_log builtins from a
 * format string in the image's __oslogstring section, where the log reader
 * looks it up. */
#if defined(__APPLE__)
struct os_log_s;
extern struct os_log_s _os_log_default;
extern void *__dso_handle;
extern _Bool os_log_type_enabled(struct os_log_s *log, uint8_t type);
extern void _os_log_impl(void *dso, struct os_log_s *log, uint8_t type,
                         const char *format, uint8_t *buf, uint32_t size);
__attribute__((section("__TEXT,__oslogstring,cstring_literals")))
static const char jac_system_log_format[] = "%{public}s";
#endif

JAC_FLOOR void __jac_system_log(int type, const char *text) {
#if defined(__APPLE__)
    struct os_log_s *log = &_os_log_default;
    uint8_t level = (uint8_t)type;
    if (os_log_type_enabled(log, level)) {
        uint8_t _Alignas(16) buf[__builtin_os_log_format_buffer_size("%{public}s", text)];
        _os_log_impl(&__dso_handle, log, level, jac_system_log_format,
                     (uint8_t *)__builtin_os_log_format(buf, "%{public}s", text),
                     (uint32_t)sizeof(buf));
    }
#else
    (void)type;
    (void)text;
#endif
}

/* ---- variadic arguments ---- */

/* Generated code starts a va_list with llvm.va_start in a 32-byte, 8-aligned
 * state slot, which holds any target's va_list, and keeps in its VaList
 * variable what a C function taking a `va_list` receives: the state itself
 * where va_list is a char* cursor (arm64 Darwin), a pointer to the state where
 * it is a record (SysV x86-64, Linux AArch64). */
#if defined(__APPLE__) && defined(__aarch64__)
#define JAC_VA_CURSOR 1
#else
#define JAC_VA_CURSOR 0
#endif

JAC_FLOOR void *__jac_va_list(void *state) {
#if JAC_VA_CURSOR
    return *(void **)state;
#else
    return state;
#endif
}

/* The next argument of the va_list a VaList variable at `slot` holds. */
JAC_FLOOR int64_t __jac_va_i64(void **slot) {
#if JAC_VA_CURSOR
    return va_arg(*(va_list *)slot, int64_t);
#else
    return va_arg(*(va_list *)(*slot), int64_t);
#endif
}

JAC_FLOOR double __jac_va_f64(void **slot) {
#if JAC_VA_CURSOR
    return va_arg(*(va_list *)slot, double);
#else
    return va_arg(*(va_list *)(*slot), double);
#endif
}
