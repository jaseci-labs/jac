/* The Windows floor: the C library a PE image's native runtime stands on.
 *
 * The native runtime and standard library are written against a POSIX C
 * library with the Linux x86-64 ABI: musl, which a Linux executable links
 * statically. A Windows image imports the Universal C Runtime instead. This
 * file defines, with the meaning and the record layouts they have on Linux,
 * the names the runtime calls that the UCRT lacks or defines differently, over
 * ucrtbase.dll and kernel32.dll. Everything it does not define is imported
 * from ucrtbase.dll by the PE linker.
 *
 * It is compiled to LLVM IR, not to an object: win_floor_ir.jac holds the IR
 * as text and the link glue of every PE artifact carries it, so a Windows
 * image is built without a C toolchain. Regenerate that file after a change
 * here with scripts/gen_win_floor.jac.
 *
 * Conventions:
 *   - No headers. The declarations below are the whole interface to Windows.
 *   - A UCRT function this file also defines is reached as __ucrt_<name>; the
 *     PE linker imports it under <name>.
 *   - Strings are UTF-8. The UCRT's narrow functions take UTF-8 once the
 *     floor has set LC_CTYPE (see __jac_win_floor_init); Win32 calls go
 *     through the wide API.
 *   - Paths are returned with forward slashes, which Windows accepts
 *     everywhere and the POSIX path helpers of the standard library expect.
 */

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;
typedef int i32;
typedef long long i64;
typedef u64 size_t;
typedef i64 ssize_t;
typedef u16 wchar;
typedef void *HANDLE;
typedef __builtin_va_list va_list;
#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_end(ap) __builtin_va_end(ap)
#define NULL ((void *)0)
#define INVALID_HANDLE ((HANDLE)(i64)-1)

/* ---- ucrtbase.dll ---- */
void *__acrt_iob_func(u32 index);
int __stdio_common_vfprintf(u64 options, void *stream, const char *format, void *locale, va_list args);
int __stdio_common_vsprintf(u64 options, char *buffer, size_t count, const char *format, void *locale, va_list args);
int __stdio_common_vsscanf(u64 options, const char *buffer, size_t count, const char *format, void *locale, va_list args);
char *setlocale(int category, const char *locale);
int *_errno(void);
void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void free(void *block);
size_t strlen(const char *text);
void *memcpy(void *dst, const void *src, size_t count);
void *memset(void *dst, int value, size_t count);
int memcmp(const void *a, const void *b, size_t count);
void *memchr(const void *block, int value, size_t count);
char *getenv(const char *name);
int _putenv_s(const char *name, const char *value);
void *__ucrt_fopen(const char *path, const char *mode);
int __ucrt_rename(const char *from, const char *to);
int _open(const char *path, int flags, int mode);
int _close(int fd);
int _mkdir(const char *path);
int _access(const char *path, int mode);
char *_fullpath(char *buffer, const char *path, size_t size);
char *_getcwd(char *buffer, int size);
i64 _findfirst64(const char *pattern, void *data);
int _findnext64(i64 handle, void *data);
int _findclose(i64 handle);
int _stat64(const char *path, void *record);
int _fstat64(int fd, void *record);
int _gmtime64_s(void *out, const i64 *when);
int _localtime64_s(void *out, const i64 *when);

/* ---- kernel32.dll ---- */
u32 FlsAlloc(void *callback);
void *FlsGetValue(u32 index);
int FlsSetValue(u32 index, void *value);
int SetConsoleOutputCP(u32 codepage);
int SetConsoleCP(u32 codepage);
u32 GetLastError(void);
int MultiByteToWideChar(u32 codepage, u32 flags, const char *text, int bytes, wchar *wide, int count);
int WideCharToMultiByte(u32 codepage, u32 flags, const wchar *wide, int count, char *text, int bytes, const char *fallback, int *used);
int MoveFileExW(const wchar *from, const wchar *to, u32 flags);
void GetSystemTimePreciseAsFileTime(u64 *filetime);
int QueryPerformanceCounter(i64 *count);
int QueryPerformanceFrequency(i64 *frequency);
HANDLE GetCurrentProcess(void);
HANDLE GetCurrentThread(void);
int GetProcessTimes(HANDLE process, u64 *created, u64 *exited, u64 *kernel, u64 *user);
int GetThreadTimes(HANDLE thread, u64 *created, u64 *exited, u64 *kernel, u64 *user);
void Sleep(u32 milliseconds);
HANDLE CreateWaitableTimerExW(void *security, const wchar *name, u32 flags, u32 access);
int SetWaitableTimer(HANDLE timer, const i64 *due, i32 period, void *routine, void *argument, int resume);
u32 WaitForSingleObject(HANDLE handle, u32 milliseconds);
int CloseHandle(HANDLE handle);
HANDLE CreateThread(void *security, size_t stack, void *start, void *argument, u32 flags, u32 *id);
int GetExitCodeThread(HANDLE thread, u32 *code);
HANDLE LoadLibraryW(const wchar *path);
void *GetProcAddress(HANDLE module, const char *name);
int FreeLibrary(HANDLE module);
HANDLE GetModuleHandleW(const wchar *name);
u32 GetModuleFileNameW(HANDLE module, wchar *path, u32 size);

#define CP_UTF8 65001u

/* ---- errno ---- */

/* Linux numbers for the errors the floor reports itself. The UCRT's own
   errno values agree with Linux through ERANGE (34). */
#define L_ENOENT 2
#define L_EIO 5
#define L_ENOMEM 12
#define L_EACCES 13
#define L_EEXIST 17
#define L_ENOTDIR 20
#define L_EINVAL 22
#define L_ERANGE 34
#define L_ENOSYS 38

int *__errno_location(void) { return _errno(); }

static void set_errno(int code) { *_errno() = code; }

/* errno for the Win32 error a failed call left. */
static int errno_of_win32(u32 code) {
    switch (code) {
    case 2: case 3: case 15: case 53: case 67: case 123: case 161: return L_ENOENT;
    case 5: case 19: case 32: case 33: case 108: return L_EACCES;
    case 8: case 14: return L_ENOMEM;
    case 80: case 183: return L_EEXIST;
    case 267: return L_ENOTDIR;
    case 87: return L_EINVAL;
    default: return L_EIO;
    }
}

/* ---- text ---- */

/* `text` as a new wide string, or NULL with errno set. */
static wchar *wide_of(const char *text) {
    int count = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
    if (count <= 0) { set_errno(L_EINVAL); return NULL; }
    wchar *wide = malloc((size_t)count * sizeof(wchar));
    if (!wide) { set_errno(L_ENOMEM); return NULL; }
    MultiByteToWideChar(CP_UTF8, 0, text, -1, wide, count);
    return wide;
}

static void slashes_forward(char *path) {
    for (; *path; path++) if (*path == '\\') *path = '/';
}

void *memmem(const void *hay, size_t hay_len, const void *needle, size_t needle_len) {
    const u8 *h = hay;
    const u8 *n = needle;
    if (needle_len == 0) return (void *)h;
    if (hay_len < needle_len) return NULL;
    const u8 *last = h + (hay_len - needle_len);
    while (h <= last) {
        const u8 *hit = memchr(h, n[0], (size_t)(last - h) + 1);
        if (!hit) return NULL;
        if (memcmp(hit, n, needle_len) == 0) return (void *)hit;
        h = hit + 1;
    }
    return NULL;
}

/* ---- stdio ---- */

void *stdin;
void *stdout;
void *stderr;

/* C99 snprintf truncation: return the length the text needed. */
#define PRINTF_STANDARD_SNPRINTF 2

int printf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int n = __stdio_common_vfprintf(0, stdout, format, NULL, args);
    va_end(args);
    return n;
}

int fprintf(void *stream, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int n = __stdio_common_vfprintf(0, stream, format, NULL, args);
    va_end(args);
    return n;
}

int vsnprintf(char *buffer, size_t size, const char *format, va_list args) {
    int n = __stdio_common_vsprintf(PRINTF_STANDARD_SNPRINTF, buffer, size, format, NULL, args);
    return n < 0 ? -1 : n;
}

int snprintf(char *buffer, size_t size, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int n = vsnprintf(buffer, size, format, args);
    va_end(args);
    return n;
}

int sprintf(char *buffer, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int n = vsnprintf(buffer, (size_t)-1, format, args);
    va_end(args);
    return n;
}

int sscanf(const char *text, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int n = __stdio_common_vsscanf(0, text, (size_t)-1, format, NULL, args);
    va_end(args);
    return n;
}

/* A stream carries bytes: no newline translation, as on POSIX. */
void *fopen(const char *path, const char *mode) {
    char binary[16];
    size_t n = strlen(mode);
    if (n > 12) { set_errno(L_EINVAL); return NULL; }
    int has_b = 0;
    for (size_t i = 0; i < n; i++) {
        binary[i] = mode[i];
        if (mode[i] == 'b') has_b = 1;
    }
    if (!has_b) binary[n++] = 'b';
    binary[n] = 0;
    return __ucrt_fopen(path, binary);
}

/* ---- thread-specific storage and threads ---- */

/* A pthread key is a fiber-local storage index: FLS runs a slot's destructor
   when its thread exits, as a pthread key does. */
int pthread_key_create(u64 *key, void (*destructor)(void *)) {
    u32 index = FlsAlloc(destructor);
    *key = index;
    return index == 0xffffffffu ? 11 : 0;
}

void *pthread_getspecific(u64 key) { return FlsGetValue((u32)key); }

int pthread_setspecific(u64 key, void *value) {
    return FlsSetValue((u32)key, value) ? 0 : L_EINVAL;
}

struct thread_start {
    void *(*entry)(void *);
    void *argument;
    void *result;
    HANDLE handle;
};

static u32 thread_main(void *raw) {
    struct thread_start *start = raw;
    start->result = start->entry(start->argument);
    return 0;
}

/* A pthread_t is the address of the thread's start record. */
int pthread_create(u64 *thread, const void *attributes, void *(*entry)(void *), void *argument) {
    (void)attributes;
    struct thread_start *start = malloc(sizeof *start);
    if (!start) return L_ENOMEM;
    start->entry = entry;
    start->argument = argument;
    start->result = NULL;
    start->handle = CreateThread(NULL, 0, thread_main, start, 0, NULL);
    if (!start->handle) { free(start); return 11; }
    *thread = (u64)start;
    return 0;
}

int pthread_join(u64 thread, void **result) {
    struct thread_start *start = (struct thread_start *)thread;
    WaitForSingleObject(start->handle, 0xffffffffu);
    CloseHandle(start->handle);
    if (result) *result = start->result;
    free(start);
    return 0;
}

/* ---- files ---- */

/* struct stat as Linux x86-64 lays it out. */
struct linux_timespec { i64 sec; i64 nsec; };
struct linux_stat {
    u64 dev; u64 ino; u64 nlink;
    u32 mode; u32 uid; u32 gid; u32 pad0;
    u64 rdev; i64 size; i64 blksize; i64 blocks;
    struct linux_timespec atim, mtim, ctim;
    i64 unused[3];
};

/* struct _stat64 of the UCRT. */
struct ucrt_stat64 {
    u32 dev; u16 ino; u16 mode; short nlink; short uid; short gid;
    u32 rdev; i64 size; i64 atime; i64 mtime; i64 ctime;
};

static void stat_from_ucrt(struct linux_stat *out, const struct ucrt_stat64 *in) {
    memset(out, 0, sizeof *out);
    out->dev = in->dev;
    out->ino = in->ino;
    out->nlink = (u64)in->nlink;
    out->mode = in->mode;
    out->rdev = in->rdev;
    out->size = in->size;
    out->blksize = 4096;
    out->blocks = (in->size + 511) / 512;
    out->atim.sec = in->atime;
    out->mtim.sec = in->mtime;
    out->ctim.sec = in->ctime;
}

/* The UCRT refuses a directory named with a trailing separator, which POSIX
   accepts: drop it, except from a root. */
static char *without_trailing_slash(const char *path, char *buffer, size_t size) {
    size_t n = strlen(path);
    if (n + 1 > size) return NULL;
    memcpy(buffer, path, n + 1);
    while (n > 1 && (buffer[n - 1] == '/' || buffer[n - 1] == '\\') && buffer[n - 2] != ':') {
        buffer[--n] = 0;
    }
    return buffer;
}

int stat(const char *path, struct linux_stat *out) {
    char trimmed[1040];
    struct ucrt_stat64 record;
    const char *name = without_trailing_slash(path, trimmed, sizeof trimmed);
    if (!name) { set_errno(L_ENOENT); return -1; }
    if (_stat64(name, &record) != 0) return -1;
    stat_from_ucrt(out, &record);
    return 0;
}

int lstat(const char *path, struct linux_stat *out) { return stat(path, out); }

int fstat(int fd, struct linux_stat *out) {
    struct ucrt_stat64 record;
    if (_fstat64(fd, &record) != 0) return -1;
    stat_from_ucrt(out, &record);
    return 0;
}

/* open(2) flags as Linux numbers them, to the UCRT's. Files are binary and
   are not inherited by child processes unless asked. */
static int open_flags(int flags) {
    int out = 0x8000 /* _O_BINARY */ | (flags & 3);
    if (flags & 0x40) out |= 0x100;    /* O_CREAT */
    if (flags & 0x80) out |= 0x400;    /* O_EXCL */
    if (flags & 0x200) out |= 0x200;   /* O_TRUNC */
    if (flags & 0x400) out |= 0x8;     /* O_APPEND */
    if (flags & 0x80000) out |= 0x80;  /* O_CLOEXEC -> _O_NOINHERIT */
    return out;
}

/* A file mode to the UCRT's read and write permission bits. */
static int open_mode(int mode) {
    return ((mode & 0444) ? 0x100 : 0) | ((mode & 0222) ? 0x80 : 0);
}

int open(const char *path, int flags, ...) {
    int mode = 0;
    if (flags & 0x40) {
        va_list args;
        va_start(args, flags);
        mode = __builtin_va_arg(args, int);
        va_end(args);
    }
    return _open(path, open_flags(flags), open_mode(mode));
}

#define L_AT_FDCWD (-100)

int openat(int dirfd, const char *path, int flags, ...) {
    int mode = 0;
    if (flags & 0x40) {
        va_list args;
        va_start(args, flags);
        mode = __builtin_va_arg(args, int);
        va_end(args);
    }
    if (dirfd != L_AT_FDCWD) { set_errno(L_ENOSYS); return -1; }
    return _open(path, open_flags(flags), open_mode(mode));
}

int creat(const char *path, int mode) {
    return _open(path, open_flags(0x40 | 0x200 | 1), open_mode(mode));
}

int mkdir(const char *path, int mode) {
    (void)mode;
    return _mkdir(path);
}

/* The UCRT's access rejects the execute bit, which Windows does not keep. */
int access(const char *path, int mode) { return _access(path, mode & 6); }

/* POSIX rename replaces an existing destination; the UCRT's does not. */
int rename(const char *from, const char *to) {
    wchar *wide_from = wide_of(from);
    if (!wide_from) return -1;
    wchar *wide_to = wide_of(to);
    if (!wide_to) { free(wide_from); return -1; }
    int ok = MoveFileExW(wide_from, wide_to, 1 /* REPLACE_EXISTING */ | 2 /* COPY_ALLOWED */);
    if (!ok) set_errno(errno_of_win32(GetLastError()));
    free(wide_from);
    free(wide_to);
    return ok ? 0 : -1;
}

int renameat(int from_fd, const char *from, int to_fd, const char *to) {
    if (from_fd != L_AT_FDCWD || to_fd != L_AT_FDCWD) { set_errno(L_ENOSYS); return -1; }
    return rename(from, to);
}

char *realpath(const char *path, char *resolved) {
    struct ucrt_stat64 record;
    char trimmed[1040];
    const char *name = without_trailing_slash(path, trimmed, sizeof trimmed);
    if (!name || _stat64(name, &record) != 0) { set_errno(L_ENOENT); return NULL; }
    char *out = resolved ? resolved : malloc(4096);
    if (!out) { set_errno(L_ENOMEM); return NULL; }
    if (!_fullpath(out, name, 4096)) {
        if (!resolved) free(out);
        set_errno(L_ERANGE);
        return NULL;
    }
    slashes_forward(out);
    return out;
}

char *getcwd(char *buffer, size_t size) {
    char *out = _getcwd(buffer, size > 0x7fffffff ? 0x7fffffff : (int)size);
    if (out) slashes_forward(out);
    return out;
}

ssize_t readlink(const char *path, char *buffer, size_t size) {
    (void)path; (void)buffer; (void)size;
    set_errno(L_EINVAL);
    return -1;
}

/* ---- directories ---- */

/* struct dirent as Linux x86-64 lays it out. */
struct linux_dirent {
    u64 ino; i64 off; u16 reclen; u8 type;
    char name[256];
};

/* struct __finddata64_t of the UCRT. */
struct ucrt_finddata {
    u32 attrib; i64 time_create; i64 time_access; i64 time_write; i64 size;
    char name[260];
};

struct floor_dir {
    i64 handle;
    int pending;            /* `found` holds an entry not yet returned */
    struct ucrt_finddata found;
    struct linux_dirent entry;
};

void *opendir(const char *path) {
    struct ucrt_stat64 record;
    char pattern[1044];
    const char *name = without_trailing_slash(path, pattern, sizeof pattern - 4);
    if (!name || _stat64(name, &record) != 0) { set_errno(L_ENOENT); return NULL; }
    if ((record.mode & 0170000) != 0040000) { set_errno(L_ENOTDIR); return NULL; }
    size_t n = strlen(pattern);
    if (pattern[n - 1] != '/' && pattern[n - 1] != '\\') pattern[n++] = '/';
    pattern[n++] = '*';
    pattern[n] = 0;
    struct floor_dir *dir = malloc(sizeof *dir);
    if (!dir) { set_errno(L_ENOMEM); return NULL; }
    dir->handle = _findfirst64(pattern, &dir->found);
    dir->pending = dir->handle != -1;
    if (dir->handle == -1 && *_errno() != L_ENOENT) { free(dir); return NULL; }
    return dir;
}

struct linux_dirent *readdir(void *raw) {
    struct floor_dir *dir = raw;
    if (dir->handle == -1) return NULL;
    if (!dir->pending) {
        int saved = *_errno();
        if (_findnext64(dir->handle, &dir->found) != 0) {
            set_errno(saved);       /* the end of a directory is not an error */
            return NULL;
        }
    }
    dir->pending = 0;
    size_t n = strlen(dir->found.name);
    if (n > 255) n = 255;
    memcpy(dir->entry.name, dir->found.name, n);
    dir->entry.name[n] = 0;
    dir->entry.ino = 1;
    dir->entry.off = 0;
    dir->entry.reclen = sizeof dir->entry;
    dir->entry.type = (dir->found.attrib & 0x10) ? 4 /* DT_DIR */ : 8 /* DT_REG */;
    return &dir->entry;
}

int closedir(void *raw) {
    struct floor_dir *dir = raw;
    if (dir->handle != -1) _findclose(dir->handle);
    free(dir);
    return 0;
}

/* ---- environment and users ---- */

int setenv(const char *name, const char *value, int overwrite) {
    if (!overwrite && getenv(name)) return 0;
    if (_putenv_s(name, value) != 0) { set_errno(L_EINVAL); return -1; }
    return 0;
}

int unsetenv(const char *name) {
    if (_putenv_s(name, "") != 0) { set_errno(L_EINVAL); return -1; }
    return 0;
}

u32 getuid(void) { return 0; }
u32 geteuid(void) { return 0; }
u32 getgid(void) { return 0; }
u32 getegid(void) { return 0; }

/* struct passwd as Linux x86-64 lays it out. */
struct linux_passwd {
    char *name; char *passwd; u32 uid; u32 gid;
    char *gecos; char *dir; char *shell;
};

/* The one account a Windows process can describe without a directory query:
   its own, from the environment. */
static int current_user(struct linux_passwd *out, char *buffer, size_t size, struct linux_passwd **result) {
    const char *name = getenv("USERNAME");
    const char *home = getenv("USERPROFILE");
    *result = NULL;
    if (!name || !home) return 0;
    size_t name_len = strlen(name) + 1;
    size_t home_len = strlen(home) + 1;
    if (name_len + home_len + 1 > size) return L_ERANGE;
    memcpy(buffer, name, name_len);
    memcpy(buffer + name_len, home, home_len);
    slashes_forward(buffer + name_len);
    buffer[name_len + home_len] = 0;
    out->name = buffer;
    out->passwd = buffer + name_len + home_len;
    out->uid = 0;
    out->gid = 0;
    out->gecos = out->passwd;
    out->dir = buffer + name_len;
    out->shell = out->passwd;
    *result = out;
    return 0;
}

int getpwuid_r(u32 uid, struct linux_passwd *out, char *buffer, size_t size, struct linux_passwd **result) {
    *result = NULL;
    if (uid != 0) return 0;
    return current_user(out, buffer, size, result);
}

int getpwnam_r(const char *name, struct linux_passwd *out, char *buffer, size_t size, struct linux_passwd **result) {
    const char *self = getenv("USERNAME");
    *result = NULL;
    if (!self || strlen(self) != strlen(name) || memcmp(self, name, strlen(name)) != 0) return 0;
    return current_user(out, buffer, size, result);
}

/* ---- time ---- */

#define L_CLOCK_REALTIME 0
#define L_CLOCK_MONOTONIC 1
#define L_CLOCK_PROCESS_CPUTIME 2
#define L_CLOCK_THREAD_CPUTIME 3

/* 100 ns intervals between 1601-01-01 and 1970-01-01. */
#define FILETIME_UNIX_EPOCH 116444736000000000ULL

int clock_gettime(int clock, struct linux_timespec *out) {
    if (clock == L_CLOCK_REALTIME) {
        u64 now;
        GetSystemTimePreciseAsFileTime(&now);
        now -= FILETIME_UNIX_EPOCH;
        out->sec = (i64)(now / 10000000);
        out->nsec = (i64)(now % 10000000) * 100;
        return 0;
    }
    if (clock == L_CLOCK_PROCESS_CPUTIME || clock == L_CLOCK_THREAD_CPUTIME) {
        u64 created, exited, kernel, user;
        int ok = clock == L_CLOCK_PROCESS_CPUTIME
            ? GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user)
            : GetThreadTimes(GetCurrentThread(), &created, &exited, &kernel, &user);
        if (!ok) { set_errno(L_EINVAL); return -1; }
        u64 spent = kernel + user;
        out->sec = (i64)(spent / 10000000);
        out->nsec = (i64)(spent % 10000000) * 100;
        return 0;
    }
    /* CLOCK_MONOTONIC and its variants */
    i64 count, frequency;
    QueryPerformanceCounter(&count);
    QueryPerformanceFrequency(&frequency);
    out->sec = count / frequency;
    out->nsec = (count % frequency) * 1000000000 / frequency;
    return 0;
}

/* Setting the system clock needs a privilege a program does not hold. */
int clock_settime(int clock, const struct linux_timespec *when) {
    (void)clock; (void)when;
    set_errno(1 /* EPERM */);
    return -1;
}

int clock_getres(int clock, struct linux_timespec *out) {
    (void)clock;
    out->sec = 0;
    out->nsec = 100;
    return 0;
}

/* Sleep for a span of nanoseconds. A high-resolution waitable timer wakes
   within a fraction of a millisecond; Sleep rounds up to the scheduler tick
   (about 16 ms), so it is only the fallback for a system without the timer. */
static void sleep_ns(i64 ns) {
    if (ns <= 0) return;
    HANDLE timer = CreateWaitableTimerExW(NULL, NULL, 2 /* HIGH_RESOLUTION */, 0x1f0003);
    if (timer) {
        i64 due = -((ns + 99) / 100);
        if (SetWaitableTimer(timer, &due, 0, NULL, NULL, 0)) {
            WaitForSingleObject(timer, 0xffffffffu);
            CloseHandle(timer);
            return;
        }
        CloseHandle(timer);
    }
    Sleep((u32)((ns + 999999) / 1000000));
}

int nanosleep(const struct linux_timespec *span, struct linux_timespec *remaining) {
    if (span->sec < 0 || span->nsec < 0 || span->nsec > 999999999) { set_errno(L_EINVAL); return -1; }
    sleep_ns(span->sec * 1000000000 + span->nsec);
    if (remaining) { remaining->sec = 0; remaining->nsec = 0; }
    return 0;
}

#define L_TIMER_ABSTIME 1

/* Returns the error, as clock_nanosleep does, not -1. */
int clock_nanosleep(int clock, int flags, const struct linux_timespec *span, struct linux_timespec *remaining) {
    if (span->nsec < 0 || span->nsec > 999999999) return L_EINVAL;
    i64 ns = span->sec * 1000000000 + span->nsec;
    if (flags & L_TIMER_ABSTIME) {
        struct linux_timespec now;
        clock_gettime(clock, &now);
        ns -= now.sec * 1000000000 + now.nsec;
    }
    sleep_ns(ns);
    if (remaining) { remaining->sec = 0; remaining->nsec = 0; }
    return 0;
}

int usleep(u32 microseconds) { sleep_ns((i64)microseconds * 1000); return 0; }

u32 sleep(u32 seconds) { sleep_ns((i64)seconds * 1000000000); return 0; }

/* struct tm as Linux lays it out: the UCRT's nine ints, then the offset from
   UTC and the zone name. */
struct linux_tm {
    int sec, min, hour, mday, mon, year, wday, yday, isdst;
    i64 gmtoff;
    const char *zone;
};

struct linux_tm *gmtime_r(const i64 *when, struct linux_tm *out) {
    if (_gmtime64_s(out, when) != 0) return NULL;
    out->gmtoff = 0;
    out->zone = "UTC";
    return out;
}

i64 _mkgmtime64(void *broken_down);

struct linux_tm *localtime_r(const i64 *when, struct linux_tm *out) {
    if (_localtime64_s(out, when) != 0) return NULL;
    int fields[9];
    memcpy(fields, out, sizeof fields);
    out->gmtoff = _mkgmtime64(fields) - *when;
    out->zone = "";
    return out;
}

/* ---- dynamic loading ---- */

static u32 dl_last_error;

void *dlopen(const char *path, int flags) {
    (void)flags;
    if (!path) return GetModuleHandleW(NULL);
    wchar *wide = wide_of(path);
    if (!wide) { dl_last_error = 87; return NULL; }
    HANDLE module = LoadLibraryW(wide);
    if (!module) dl_last_error = GetLastError();
    free(wide);
    return module;
}

void *dlsym(void *module, const char *name) {
    void *address = GetProcAddress(module, name);
    if (!address) dl_last_error = GetLastError();
    return address;
}

int dlclose(void *module) { return FreeLibrary(module) ? 0 : -1; }

char *dlerror(void) {
    static char text[48];
    if (!dl_last_error) return NULL;
    snprintf(text, sizeof text, "Windows error %u", dl_last_error);
    dl_last_error = 0;
    return text;
}

/* The image's own path, UTF-8 with forward slashes; 0 if it does not fit. */
size_t __jac_win_executable_path(char *buffer, size_t size) {
    wchar wide[1024];
    u32 n = GetModuleFileNameW(NULL, wide, 1024);
    if (n == 0 || n >= 1024) return 0;
    int bytes = WideCharToMultiByte(CP_UTF8, 0, wide, (int)n, buffer, (int)size - 1, NULL, NULL);
    if (bytes <= 0) return 0;
    buffer[bytes] = 0;
    slashes_forward(buffer);
    return (size_t)bytes;
}

/* ---- the runtime floor (#10219) ---- */

/* The __jac_* functions posix_floor.c defines for ELF and Mach-O targets,
   over this file's Linux-ABI names, so generated code calls the same functions
   on every target. */

size_t _msize(void *block);

int *__jac_errno(void) { return _errno(); }

void *__jac_stdio(int fd) {
    if (fd == 0) return stdin;
    if (fd == 1) return stdout;
    return stderr;
}

int __jac_platform_id(void) { return 2; }

int __jac_stat(const char *path, i64 *out) {
    struct linux_stat st;
    if (stat(path, &st) != 0) return -1;
    out[0] = (i64)st.mode;
    out[1] = st.size;
    out[2] = st.mtim.sec;
    out[3] = st.mtim.nsec;
    return 0;
}

void *__jac_opendir(const char *path) { return opendir(path); }

void *__jac_readdir(void *dir) { return readdir(dir); }

int __jac_closedir(void *dir) { return closedir(dir); }

const char *__jac_dirent_name(void *entry) { return ((struct linux_dirent *)entry)->name; }

int __jac_at_fdcwd(void) { return -100; }

i64 __jac_executable_path(char *buf, i64 cap) {
    i64 n = (i64)__jac_win_executable_path(buf, (size_t)cap);
    return n > 0 ? n : -1;
}

/* struct addrinfo of ws2_32: four ints, then ai_addrlen as a size_t at 16,
   ai_canonname at 24, ai_addr at 32 and ai_next at 40; AF_INET6 is 23. */
i64 __jac_addrinfo_layout(int which) {
    switch (which) {
    case 0: return 16;
    case 1: return 32;
    case 2: return 40;
    case 3: return 48;
    case 4: return 23;
    default: return -1;
    }
}

int __jac_sockaddr_family(const void *address) {
    const u8 *raw = (const u8 *)address;
    return raw[0] | (raw[1] << 8);
}

i64 __jac_home_dir(const char *name, char *buf, i64 cap) {
    struct linux_passwd pw;
    struct linux_passwd *found = NULL;
    char scratch[1024];
    int rc = name[0] ? getpwnam_r(name, &pw, scratch, sizeof scratch, &found)
                     : getpwuid_r(0, &pw, scratch, sizeof scratch, &found);
    if (rc != 0 || found == NULL) return -1;
    if (pw.dir == NULL) return -2;
    size_t n = strlen(pw.dir);
    if ((i64)n < cap) memcpy(buf, pw.dir, n + 1);
    return (i64)n;
}

/* This file's clock_gettime takes Linux clock ids. */
i64 __jac_clock_id(int jac_clock) {
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

int __jac_sleep_ns(i64 ns) {
    sleep_ns(ns);
    return 0;
}

size_t __jac_malloc_size(void *p) { return _msize(p); }

#pragma STDC FP_CONTRACT OFF
double __jac_fmadd(double a, double b, double c) { return a * b + c; }

/* A Win64 va_list is a char* cursor: the VaList variable holds it. */
void *__jac_va_list(void *state) { return *(void **)state; }

i64 __jac_va_i64(void **slot) { return __builtin_va_arg(*(va_list *)slot, i64); }

double __jac_va_f64(void **slot) { return __builtin_va_arg(*(va_list *)slot, double); }

/* ---- startup ---- */

/* Run before any Jac code. Binds the standard streams, and makes UTF-8 the
   encoding of the console and of the narrow strings the UCRT takes for
   paths: LC_CTYPE only, so numbers keep the C locale's formatting. */
void __jac_win_floor_init(void) {
    stdin = __acrt_iob_func(0);
    stdout = __acrt_iob_func(1);
    stderr = __acrt_iob_func(2);
    setlocale(2 /* LC_CTYPE */, ".UTF-8");
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
}
