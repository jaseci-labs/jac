/*
 * glibc large-file (LFS64) entry points for static musl links.
 *
 * The Linux floor archives (libcrypto.a, libsqlite3.a, ...) come from the
 * glibc-built Python distribution, so they call fopen64, pread64, stat64 and
 * friends. musl 1.2.4 and later export those names for dynamic linking only,
 * which leaves a static `jac build --native` executable with calls through
 * address 0. Every 64-bit musl target already has a 64-bit off_t and the
 * glibc stat64/dirent64 layouts, so each entry forwards to the plain call.
 *
 * The payload vendor compiles this file once per entry point (-DL_<name>) so
 * the archive linker pulls only the members a link references.
 */
#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

_Static_assert(sizeof(off_t) == 8, "LFS64 forwarding needs a 64-bit off_t");

#if defined(L_fopen64)
FILE *fopen64(const char *path, const char *mode) { return fopen(path, mode); }
#elif defined(L_fseeko64)
int fseeko64(FILE *f, off_t off, int whence) { return fseeko(f, off, whence); }
#elif defined(L_ftello64)
off_t ftello64(FILE *f) { return ftello(f); }
#elif defined(L_open64)
int open64(const char *path, int flags, ...) {
    mode_t mode = 0;
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }
    return open(path, flags, mode);
}
#elif defined(L_openat64)
int openat64(int dir, const char *path, int flags, ...) {
    mode_t mode = 0;
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }
    return openat(dir, path, flags, mode);
}
#elif defined(L_lseek64)
off_t lseek64(int fd, off_t off, int whence) { return lseek(fd, off, whence); }
#elif defined(L_pread64)
ssize_t pread64(int fd, void *buf, size_t n, off_t off) { return pread(fd, buf, n, off); }
#elif defined(L_pwrite64)
ssize_t pwrite64(int fd, const void *buf, size_t n, off_t off) {
    return pwrite(fd, buf, n, off);
}
#elif defined(L_ftruncate64)
int ftruncate64(int fd, off_t len) { return ftruncate(fd, len); }
#elif defined(L_truncate64)
int truncate64(const char *path, off_t len) { return truncate(path, len); }
#elif defined(L_mmap64)
void *mmap64(void *addr, size_t len, int prot, int flags, int fd, off_t off) {
    return mmap(addr, len, prot, flags, fd, off);
}
#elif defined(L_stat64)
int stat64(const char *path, struct stat *st) { return stat(path, st); }
#elif defined(L_lstat64)
int lstat64(const char *path, struct stat *st) { return lstat(path, st); }
#elif defined(L_fstat64)
int fstat64(int fd, struct stat *st) { return fstat(fd, st); }
#elif defined(L_fstatat64)
int fstatat64(int dir, const char *path, struct stat *st, int flags) {
    return fstatat(dir, path, st, flags);
}
#elif defined(L_readdir64)
struct dirent *readdir64(DIR *d) { return readdir(d); }
#else
#error "define L_<entry point> to select one LFS64 forwarder"
#endif
