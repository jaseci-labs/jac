//! The configure results pyconfig.h records, as probes for bootstrap/pyconfig.zig.
//! Entries before the alphabetical list carry configure's own tests and build
//! decisions; the list is configure.ac's header, function, declaration, size
//! and member checks with the includes configure passes them.
const Probe = @import("pyconfig.zig").Probe;

pub const probes = [_]Probe{
    // Build decisions: the configure options build.sh passed
    // (--enable-shared, --with-tail-call-interp, --without-remote-debug,
    // defaults for the rest) and what configure derives from the platform
    // name alone.
    .{ .name = "Py_ENABLE_SHARED", .kind = .value },
    .{ .name = "Py_TAIL_CALL_INTERP", .kind = .value },
    .{ .name = "Py_REMOTE_DEBUG", .kind = .value, .value = "" },
    .{ .name = "Py_DEBUG", .kind = .value, .value = "" },
    .{ .name = "Py_GIL_DISABLED", .kind = .value, .value = "" },
    .{ .name = "Py_STATS", .kind = .value, .value = "" },
    .{ .name = "Py_TRACE_REFS", .kind = .value, .value = "" },
    .{ .name = "Py_HASH_ALGORITHM", .kind = .value, .value = "" },
    .{ .name = "Py_SUNOS_VERSION", .kind = .value, .value = "" },
    .{ .name = "Py_RL_STARTUP_HOOK_TAKES_ARGS", .kind = .value, .value = "" },
    .{ .name = "PY_SUPPORT_TIER", .kind = .value, .value = "2", .os = .linux },
    .{ .name = "PY_SUPPORT_TIER", .kind = .value, .value = "1", .os = .macos },
    .{ .name = "PY_BUILTIN_HASHLIB_HASHES", .kind = .value, .value = "\"md5,sha1,sha2,sha3,blake2\"" },
    .{ .name = "PY_COERCE_C_LOCALE", .kind = .value },
    // Perf trampolines are not part of JacPython (interpreter/perf_trampoline.jac).
    .{ .name = "PY_HAVE_PERF_TRAMPOLINE", .kind = .value, .value = "" },
    .{ .name = "PY_SQLITE_ENABLE_LOAD_EXTENSION", .kind = .value, .value = "" },
    .{ .name = "PY_SSL_DEFAULT_CIPHERS", .kind = .value },
    .{ .name = "PY_SSL_DEFAULT_CIPHER_STRING", .kind = .value, .value = "" },
    .{ .name = "PYLONG_BITS_IN_DIGIT", .kind = .value, .value = "" },
    .{ .name = "WITH_DECIMAL_CONTEXTVAR", .kind = .value },
    .{ .name = "WITH_DOC_STRINGS", .kind = .value },
    .{ .name = "WITH_DTRACE", .kind = .value, .value = "" },
    .{ .name = "WITH_DYLD", .kind = .value, .os = .macos },
    .{ .name = "WITH_EDITLINE", .kind = .value, .value = "" },
    .{ .name = "WITH_MIMALLOC", .kind = .value },
    .{ .name = "WITH_NEXT_FRAMEWORK", .kind = .value, .value = "" },
    .{ .name = "WITH_PYMALLOC", .kind = .value },
    .{ .name = "WITH_VALGRIND", .kind = .value, .value = "" },
    .{ .name = "USE_COMPUTED_GOTOS", .kind = .value, .value = "" },
    .{ .name = "_PYTHONFRAMEWORK", .kind = .value, .value = "\"\"" },
    .{ .name = "_PYTHREAD_NAME_MAXLEN", .kind = .value, .value = "15", .os = .linux },
    .{ .name = "_PYTHREAD_NAME_MAXLEN", .kind = .value, .value = "63", .os = .macos },
    .{ .name = "_Py_STACK_GROWS_DOWN", .kind = .value },
    // The ld64 default main-thread stack is too small for the default
    // recursion limit; configure raises it, and the thread size with it.
    .{ .name = "THREAD_STACK_SIZE", .kind = .value, .value = "0x1000000", .os = .macos },
    .{ .name = "_REENTRANT", .kind = .value },
    .{ .name = "_POSIX_THREADS", .kind = .value, .value = "" },
    .{ .name = "RETSIGTYPE", .kind = .value, .value = "void" },
    .{ .name = "STDC_HEADERS", .kind = .value },
    .{ .name = "SYS_SELECT_WITH_SYS_TIME", .kind = .value },
    .{ .name = "HAVE_PROTOTYPES", .kind = .value },
    .{ .name = "HAVE_DYNAMIC_LOADING", .kind = .value },
    // Feature-test macros. Darwin's headers hide platform features once
    // _XOPEN_SOURCE or _POSIX_C_SOURCE is set, so configure leaves them out there.
    .{ .name = "_XOPEN_SOURCE", .kind = .value, .value = "700", .os = .linux },
    .{ .name = "_XOPEN_SOURCE_EXTENDED", .kind = .value, .os = .linux },
    .{ .name = "_POSIX_C_SOURCE", .kind = .value, .value = "200809L", .os = .linux },
    .{ .name = "_DARWIN_C_SOURCE", .kind = .value },
    .{ .name = "_NETBSD_SOURCE", .kind = .value },
    .{ .name = "__BSD_VISIBLE", .kind = .value },
    .{ .name = "_BSD_SOURCE", .kind = .value, .value = "" },
    .{ .name = "_FILE_OFFSET_BITS", .kind = .value, .value = "64" },
    .{ .name = "_LARGEFILE_SOURCE", .kind = .value },
    .{ .name = "_LARGE_FILES", .kind = .value, .value = "" },
    .{ .name = "_INCLUDE__STDC_A1_SOURCE", .kind = .value, .value = "" },
    // Other systems' answers (AIX, Android, Solaris, WASI, Cygwin, NetBSD).
    .{ .name = "AC_APPLE_UNIVERSAL_BUILD", .kind = .value, .value = "" },
    .{ .name = "AIX_BUILDDATE", .kind = .value, .value = "" },
    .{ .name = "AIX_GENUINE_CPLUSPLUS", .kind = .value, .value = "" },
    .{ .name = "ALT_SOABI", .kind = .value, .value = "" },
    .{ .name = "ANDROID_API_LEVEL", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_PIPE_BUF", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_POSIX_SEMAPHORES", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_PTHREAD_SIGMASK", .kind = .value, .value = "" },
    .{ .name = "HAVE_NON_UNICODE_WCHAR_T_REPRESENTATION", .kind = .value, .value = "" },
    .{ .name = "HAVE_PTHREAD_DESTRUCTOR", .kind = .value, .value = "" },
    .{ .name = "HAVE_PTHREAD_STUBS", .kind = .value, .value = "" },
    .{ .name = "_WASI_EMULATED_GETPID", .kind = .value, .value = "" },
    .{ .name = "_WASI_EMULATED_PROCESS_CLOCKS", .kind = .value, .value = "" },
    .{ .name = "_WASI_EMULATED_SIGNAL", .kind = .value, .value = "" },
    .{ .name = "HAVE_DEV_PTC", .kind = .value, .value = "" },
    .{ .name = "TIMEMODULE_LIB", .kind = .value, .value = "" },
    // Modules the build leaves out: readline, curses, dbm/gdbm.
    .{ .name = "HAVE_NCURSES", .kind = .value, .value = "" },
    .{ .name = "HAVE_NCURSESW", .kind = .value, .value = "" },
    .{ .name = "HAVE_PANEL", .kind = .value, .value = "" },
    .{ .name = "HAVE_PANELW", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_FILTER", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_HAS_KEY", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_IMMEDOK", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_IS_PAD", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_IS_TERM_RESIZED", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_RESIZETERM", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_RESIZE_TERM", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_SYNCOK", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_TYPEAHEAD", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_USE_ENV", .kind = .value, .value = "" },
    .{ .name = "HAVE_CURSES_WCHGAT", .kind = .value, .value = "" },
    .{ .name = "MVWDELCH_IS_EXPRESSION", .kind = .value, .value = "" },
    .{ .name = "WINDOW_HAS_FLAGS", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_APPEND_HISTORY", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_CATCH_SIGNAL", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_COMPLETION_APPEND_CHARACTER", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_COMPLETION_DISPLAY_MATCHES_HOOK", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_COMPLETION_MATCHES", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_COMPLETION_SUPPRESS_APPEND", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_PRE_INPUT_HOOK", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_RESIZE_TERMINAL", .kind = .value, .value = "" },
    .{ .name = "HAVE_RL_COMPDISP_FUNC_T", .kind = .value, .value = "" },
    .{ .name = "HAVE_GDBM_DASH_NDBM_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_GDBM_NDBM_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_LIBDB", .kind = .value, .value = "" },
    .{ .name = "HAVE_TERM_H", .kind = .value, .value = "" },
    // Run tests: configure executes these on the release runner. The
    // answers are the same on every supported target, so they are recorded.
    // Unaligned loads work on x86-64 and AArch64.
    .{ .name = "HAVE_ALIGNED_REQUIRED", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_MBSTOWCS", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_NICE", .kind = .value, .value = "" },
    .{ .name = "HAVE_BROKEN_POLL", .kind = .value, .value = "" },
    .{ .name = "HAVE_GLIBC_MEMMOVE_BUG", .kind = .value, .value = "" },
    .{ .name = "HAVE_IPA_PURE_CONST_BUG", .kind = .value, .value = "" },
    .{ .name = "HAVE_WORKING_TZSET", .kind = .value },
    .{ .name = "PTHREAD_SYSTEM_SCHED_SUPPORTED", .kind = .value },
    .{ .name = "POSIX_SEMAPHORES_NOT_ENABLED", .kind = .value, .value = "" },
    .{ .name = "SIGNED_RIGHT_SHIFT_ZERO_FILLS", .kind = .value, .value = "" },
    .{ .name = "X87_DOUBLE_ROUNDING", .kind = .value, .value = "" },
    .{ .name = "HAVE_DEV_PTMX", .kind = .value },
    // macOS implements sem_getvalue as a stub that fails with ENOSYS.
    .{ .name = "HAVE_BROKEN_SEM_GETVALUE", .kind = .value, .os = .macos },
    // Computed gotos compile, so clang runs them.
    .{ .name = "HAVE_COMPUTED_GOTOS", .kind = .link, .includes =
    \\int main(int argc, char **argv)
    \\{
    \\    static void *targets[1] = { &&LABEL1 };
    \\    goto LABEL2;
    \\LABEL1:
    \\    return 0;
    \\LABEL2:
    \\    goto *targets[0];
    \\    return 1;
    \\}
    \\
    },
    // configure runs a complex call through libffi; the vendored libffi's
    // own record of complex support stands in for it.
    .{ .name = "_Py_FFI_SUPPORT_C_COMPLEX", .kind = .link, .libs = "-lffi", .includes =
    \\#include <complex.h>
    \\#include <ffi.h>
    \\#ifndef FFI_TARGET_HAS_COMPLEX_TYPE
    \\#error no complex types
    \\#endif
    \\int main(void) { ffi_type *t = &ffi_type_complex_double; return t->size == 0; }
    \\
    },
    // The byte order of doubles (AX_C_FLOAT_WORDS_BIGENDIAN).
    .{ .name = "DOUBLE_IS_LITTLE_ENDIAN_IEEE754", .kind = .compile, .includes =
    \\#if !(__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__ && __SIZEOF_DOUBLE__ == 8)
    \\#error not little-endian IEEE 754 doubles
    \\#endif
    \\
    },
    .{ .name = "DOUBLE_IS_BIG_ENDIAN_IEEE754", .kind = .compile, .includes =
    \\#if !(__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__ && __SIZEOF_DOUBLE__ == 8)
    \\#error not big-endian IEEE 754 doubles
    \\#endif
    \\
    },
    .{ .name = "DOUBLE_IS_ARM_MIXED_ENDIAN_IEEE754", .kind = .value, .value = "" },
    .{ .name = "WORDS_BIGENDIAN", .kind = .compile, .includes =
    \\#if __BYTE_ORDER__ != __ORDER_BIG_ENDIAN__
    \\#error little-endian
    \\#endif
    \\
    },
    // Compile and link tests configure writes inline.
    .{ .name = "HAVE_BUILTIN_ATOMIC", .kind = .link, .includes =
    \\int val;
    \\int main(void) {
    \\  __atomic_store_n(&val, 1, __ATOMIC_SEQ_CST);
    \\  (void)__atomic_load_n(&val, __ATOMIC_SEQ_CST);
    \\  return 0;
    \\}
    \\
    },
    .{ .name = "HAVE_STD_ATOMIC", .kind = .link, .includes =
    \\#include <stdatomic.h>
    \\atomic_int int_var;
    \\atomic_uintptr_t uintptr_var;
    \\int main(void) {
    \\  atomic_store_explicit(&int_var, 5, memory_order_relaxed);
    \\  atomic_store_explicit(&uintptr_var, 0, memory_order_relaxed);
    \\  int loaded_value = atomic_load_explicit(&int_var, memory_order_seq_cst);
    \\  (void)loaded_value;
    \\  return 0;
    \\}
    \\
    },
    .{ .name = "HAVE_GCC_ASM_FOR_X64", .kind = .link, .text = "__asm__ __volatile__ (\"movq %rcx, %rax\");" },
    .{ .name = "HAVE_GCC_ASM_FOR_X87", .kind = .link, .text =
    \\  unsigned short cw;
    \\  __asm__ __volatile__ ("fnstcw %0" : "=m" (cw));
    \\  __asm__ __volatile__ ("fldcw %0" : : "m" (cw));
    },
    .{ .name = "HAVE_GCC_ASM_FOR_MC68881", .kind = .link, .text =
    \\  unsigned int fpcr;
    \\  __asm__ __volatile__ ("fmove.l %%fpcr,%0" : "=dm" (fpcr));
    \\  __asm__ __volatile__ ("fmove.l %0,%%fpcr" : : "dm" (fpcr));
    },
    .{ .name = "HAVE_GCC_UINT128_T", .kind = .type, .text = "__uint128_t" },
    .{ .name = "HAVE_LONG_DOUBLE", .kind = .type, .text = "long double" },
    .{ .name = "HAVE_LARGEFILE_SUPPORT", .kind = .compile, .includes =
    \\#include <sys/types.h>
    \\_Static_assert(sizeof(off_t) > sizeof(long) && sizeof(long long) >= sizeof(off_t), "off_t fits a long");
    \\
    },
    .{ .name = "PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT", .kind = .compile, .includes =
    \\#include <pthread.h>
    \\_Static_assert(sizeof(pthread_key_t) == sizeof(int), "pthread_key_t is not int-sized");
    \\int main(void) { pthread_key_t k = 0; return (int)(k * 1); }
    \\
    },
    .{ .name = "HAVE_USABLE_WCHAR_T", .kind = .compile, .includes =
    \\#include <wchar.h>
    \\_Static_assert(sizeof(wchar_t) >= 2 && !(((wchar_t)-1) < ((wchar_t)0)), "wchar_t is signed or narrow");
    \\
    },
    .{ .name = "HAVE_WCHAR_H", .kind = .header, .text = "wchar.h" },
    .{ .name = "HAVE_MAKEDEV", .kind = .link, .includes =
    \\#if defined(MAJOR_IN_MKDEV)
    \\#include <sys/mkdev.h>
    \\#elif defined(MAJOR_IN_SYSMACROS)
    \\#include <sys/sysmacros.h>
    \\#else
    \\#include <sys/types.h>
    \\#endif
    \\
    , .text = "makedev(0, 0)" },
    .{ .name = "HAVE_DEVICE_MACROS", .kind = .link, .includes =
    \\#if defined(MAJOR_IN_MKDEV)
    \\#include <sys/mkdev.h>
    \\#elif defined(MAJOR_IN_SYSMACROS)
    \\#include <sys/types.h>
    \\#include <sys/sysmacros.h>
    \\#else
    \\#include <sys/types.h>
    \\#endif
    \\
    , .text = "makedev(major(0),minor(0))" },
    .{ .name = "MAJOR_IN_MKDEV", .kind = .header, .text = "sys/mkdev.h" },
    .{ .name = "MAJOR_IN_SYSMACROS", .kind = .header, .text = "sys/sysmacros.h" },
    .{ .name = "HAVE_HTOLE64", .kind = .link, .includes =
    \\#ifdef HAVE_ENDIAN_H
    \\#include <endian.h>
    \\#elif defined(HAVE_SYS_ENDIAN_H)
    \\#include <sys/endian.h>
    \\#endif
    \\
    , .text = "le64toh(1)" },
    .{ .name = "HAVE_DIRENT_D_TYPE", .kind = .link, .includes =
    \\#include <dirent.h>
    \\int main(void) {
    \\  struct dirent entry;
    \\  return entry.d_type == DT_UNKNOWN;
    \\}
    \\
    },
    .{ .name = "HAVE_GETRANDOM_SYSCALL", .kind = .link, .includes =
    \\#include <stddef.h>
    \\#include <unistd.h>
    \\#include <sys/syscall.h>
    \\#include <linux/random.h>
    \\int main(void) {
    \\    char buffer[1];
    \\    const size_t buflen = sizeof(buffer);
    \\    const int flags = GRND_NONBLOCK;
    \\    (void)syscall(SYS_getrandom, buffer, buflen, flags);
    \\    return 0;
    \\}
    \\
    },
    .{ .name = "HAVE_GETRANDOM", .kind = .link, .includes =
    \\#include <stddef.h>
    \\#include <sys/random.h>
    \\int main(void) {
    \\    char buffer[1];
    \\    const size_t buflen = sizeof(buffer);
    \\    const int flags = 0;
    \\    (void)getrandom(buffer, buflen, flags);
    \\    return 0;
    \\}
    \\
    },
    .{ .name = "HAVE_GETC_UNLOCKED", .kind = .link, .includes = "#include <stdio.h>\n", .text =
    \\  FILE *f = fopen("/dev/null", "r");
    \\  flockfile(f);
    \\  getc_unlocked(f);
    \\  funlockfile(f);
    },
    .{ .name = "HAVE_GETADDRINFO", .kind = .link, .includes =
    \\#include <sys/types.h>
    \\#include <sys/socket.h>
    \\#include <netdb.h>
    \\#include <stdio.h>
    \\
    , .text = "getaddrinfo(NULL, NULL, NULL, NULL);" },
    .{ .name = "HAVE_GETHOSTBYNAME_R", .kind = .func, .text = "gethostbyname_r" },
    .{ .name = "HAVE_GETHOSTBYNAME_R_6_ARG", .kind = .compile, .includes = "#include <netdb.h>\n", .text =
    \\    char *name;
    \\    struct hostent *he, *res;
    \\    char buffer[2048];
    \\    int buflen = 2048;
    \\    int h_errnop;
    \\    (void) gethostbyname_r(name, he, buffer, buflen, &res, &h_errnop)
    },
    .{ .name = "HAVE_GETHOSTBYNAME_R_5_ARG", .kind = .compile, .includes = "#include <netdb.h>\n", .text =
    \\    char *name;
    \\    struct hostent *he;
    \\    char buffer[2048];
    \\    int buflen = 2048;
    \\    int h_errnop;
    \\    (void) gethostbyname_r(name, he, buffer, buflen, &h_errnop)
    },
    .{ .name = "HAVE_GETHOSTBYNAME_R_3_ARG", .kind = .compile, .includes = "#include <netdb.h>\n", .text =
    \\    char *name;
    \\    struct hostent *he;
    \\    struct hostent_data data;
    \\    (void) gethostbyname_r(name, he, &data);
    },
    .{ .name = "HAVE_ADDRINFO", .kind = .compile, .includes = "#include <netdb.h>\n", .text = "struct addrinfo a" },
    .{ .name = "HAVE_SOCKADDR_STORAGE", .kind = .compile, .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n", .text = "struct sockaddr_storage s" },
    .{ .name = "HAVE_SOCKADDR_ALG", .kind = .compile, .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <linux/if_alg.h>\n", .text = "struct sockaddr_alg s" },
    .{ .name = "HAVE_SOCKADDR_SA_LEN", .kind = .compile, .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n", .text = "struct sockaddr x;\nx.sa_len = 0;" },
    .{ .name = "ENABLE_IPV6", .kind = .compile, .includes = "#include <sys/types.h>\n#include <netinet/in.h>\n", .text = "struct sockaddr_in6 x;\nx.sin6_scope_id;" },
    .{ .name = "HAVE_ALTZONE", .kind = .compile, .includes = "#include <time.h>\n", .text = "return altzone;" },
    .{ .name = "HAVE_STAT_TV_NSEC", .kind = .compile, .includes = "#include <sys/stat.h>\n", .text = "struct stat st;\nst.st_mtim.tv_nsec = 1;" },
    .{ .name = "HAVE_STAT_TV_NSEC2", .kind = .compile, .includes = "#include <sys/stat.h>\n", .text = "struct stat st;\nst.st_mtimespec.tv_nsec = 1;" },
    .{ .name = "HAVE_LINUX_CAN_RAW_FD_FRAMES", .kind = .compile, .includes = "#include <linux/can/raw.h>\n", .text = "int can_raw_fd_frames = CAN_RAW_FD_FRAMES;" },
    .{ .name = "HAVE_LINUX_CAN_RAW_JOIN_FILTERS", .kind = .compile, .includes = "#include <linux/can/raw.h>\n", .text = "int can_raw_join_filters = CAN_RAW_JOIN_FILTERS;" },
    .{ .name = "HAVE_BROKEN_UNSETENV", .kind = .compile, .includes = "#include <stdlib.h>\n", .text = "int res = unsetenv(\"DUMMY\");", .value = "", .otherwise = "1" },
    .{ .name = "GETPGRP_HAVE_ARG", .kind = .compile, .includes = "#include <unistd.h>\n", .text = "getpgrp(0);" },
    .{ .name = "SETPGRP_HAVE_ARG", .kind = .compile, .includes = "#include <unistd.h>\n", .text = "setpgrp(0,0);" },
    .{ .name = "HAVE_DIRFD", .kind = .decl, .text = "dirfd", .includes = "#include <sys/types.h>\n#include <dirent.h>\n" },
    .{ .name = "HAVE_MAXLOGNAME", .kind = .decl, .text = "MAXLOGNAME", .includes = "#include <sys/param.h>\n" },
    .{ .name = "HAVE_UT_NAMESIZE", .kind = .decl, .text = "UT_NAMESIZE", .includes = "#include <utmp.h>\n" },
    .{ .name = "HAVE_DECL_UT_NAMESIZE", .kind = .decl, .text = "UT_NAMESIZE", .includes = "#include <utmp.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_CHFLAGS", .kind = .func, .text = "chflags" },
    .{ .name = "HAVE_LCHFLAGS", .kind = .func, .text = "lchflags" },
    .{ .name = "HAVE_DUP2", .kind = .func, .text = "dup2" },
    // Linux cannot change a symbolic link's mode, so configure does not look.
    .{ .name = "HAVE_LCHMOD", .kind = .func, .text = "lchmod", .os = .macos },
    .{ .name = "HAVE_LCHMOD", .kind = .value, .value = "" },
    // The vendored compression libraries come in as *_CFLAGS/*_LIBS, which
    // configure takes without checking their headers.
    .{ .name = "HAVE_BZLIB_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_LZMA_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_ZDICT_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_ZLIB_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_ZSTD_H", .kind = .value, .value = "" },
    // glibc 2.17 keeps the pty helpers in libutil; configure adds -lutil.
    .{ .name = "HAVE_OPENPTY", .kind = .func, .text = "openpty", .libs = "-lutil", .os = .linux },
    .{ .name = "HAVE_FORKPTY", .kind = .func, .text = "forkpty", .libs = "-lutil", .os = .linux },
    .{ .name = "HAVE_LOGIN_TTY", .kind = .func, .text = "login_tty", .libs = "-lutil", .os = .linux },
    .{ .name = "HAVE_LOGIN_TTY", .kind = .func, .text = "login_tty" },
    // The vendored libraries (LIBSQLITE3_LIBS and ZLIB_LIBS).
    .{ .name = "HAVE_LIBSQLITE3", .kind = .lib, .text = "-lsqlite3", .symbol = "sqlite3_bind_double", .libs = "-lm -lpthread" },
    .{ .name = "PY_SQLITE_HAVE_SERIALIZE", .kind = .lib, .text = "-lsqlite3", .symbol = "sqlite3_serialize", .libs = "-lm -lpthread" },
    .{ .name = "HAVE_ZLIB_COPY", .kind = .lib, .text = "-lz", .symbol = "inflateCopy" },
    .{ .name = "WITH_LIBINTL", .kind = .lib, .text = "-lintl", .symbol = "textdomain" },
    // AC_HEADER_DIRENT stops at the first header that declares DIR.
    .{ .name = "HAVE_DIRENT_H", .kind = .header, .text = "dirent.h" },
    .{ .name = "HAVE_NDIR_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_SYS_DIR_H", .kind = .value, .value = "" },
    .{ .name = "HAVE_SYS_NDIR_H", .kind = .value, .value = "" },
    // AC_INCLUDES_DEFAULT's own header checks.
    .{ .name = "HAVE_INTTYPES_H", .kind = .header, .text = "inttypes.h", .includes = "" },
    .{ .name = "HAVE_STDINT_H", .kind = .header, .text = "stdint.h", .includes = "" },
    .{ .name = "HAVE_STDIO_H", .kind = .header, .text = "stdio.h", .includes = "" },
    .{ .name = "HAVE_STDLIB_H", .kind = .header, .text = "stdlib.h", .includes = "" },
    .{ .name = "HAVE_STRINGS_H", .kind = .header, .text = "strings.h", .includes = "" },
    .{ .name = "HAVE_STRING_H", .kind = .header, .text = "string.h", .includes = "" },
    .{ .name = "HAVE_UNISTD_H", .kind = .header, .text = "unistd.h", .includes = "" },
    .{ .name = "HAVE_MINIX_CONFIG_H", .kind = .header, .text = "minix/config.h", .includes = "" },
    // AC_STRUCT_TM and AC_STRUCT_TIMEZONE: with tm_zone present configure
    // does not look for tzname.
    .{ .name = "TM_IN_SYS_TIME", .kind = .value, .value = "" },
    .{ .name = "HAVE_STRUCT_TM_TM_ZONE", .kind = .member, .text = "struct tm.tm_zone", .includes = "#include <sys/types.h>\n#include <time.h>\n" },
    .{ .name = "HAVE_TM_ZONE", .kind = .member, .text = "struct tm.tm_zone", .includes = "#include <sys/types.h>\n#include <time.h>\n" },
    .{ .name = "HAVE_DECL_TZNAME", .kind = .value, .value = "" },
    .{ .name = "HAVE_TZNAME", .kind = .value, .value = "" },
    // Replacement definitions for missing types and keywords.
    .{ .name = "clock_t", .kind = .type, .text = "clock_t", .includes = "#include <time.h>\n", .value = "", .otherwise = "long" },
    .{ .name = "gid_t", .kind = .type, .text = "gid_t", .includes = "#include <sys/types.h>\n", .value = "", .otherwise = "int" },
    .{ .name = "uid_t", .kind = .type, .text = "uid_t", .includes = "#include <sys/types.h>\n", .value = "", .otherwise = "int" },
    .{ .name = "mode_t", .kind = .type, .text = "mode_t", .value = "", .otherwise = "int" },
    .{ .name = "off_t", .kind = .type, .text = "off_t", .value = "", .otherwise = "long int" },
    .{ .name = "pid_t", .kind = .type, .text = "pid_t", .value = "", .otherwise = "int" },
    .{ .name = "size_t", .kind = .type, .text = "size_t", .value = "", .otherwise = "unsigned int" },
    .{ .name = "socklen_t", .kind = .type, .text = "socklen_t", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n", .value = "", .otherwise = "int" },
    .{ .name = "const", .kind = .value, .value = "" },
    .{ .name = "signed", .kind = .value, .value = "" },
    // configure's own package identity is empty for CPython.
    .{ .name = "PACKAGE_BUGREPORT", .kind = .value, .value = "" },
    .{ .name = "PACKAGE_NAME", .kind = .value, .value = "" },
    .{ .name = "PACKAGE_STRING", .kind = .value, .value = "" },
    .{ .name = "PACKAGE_TARNAME", .kind = .value, .value = "" },
    .{ .name = "PACKAGE_URL", .kind = .value, .value = "" },
    .{ .name = "PACKAGE_VERSION", .kind = .value, .value = "" },
    // uuid_generate_time_safe is libuuid's; neither system ships it in libc.
    .{ .name = "HAVE_UUID_GENERATE_TIME_SAFE", .kind = .value, .value = "" },
    .{ .name = "HAVE_UUID_GENERATE_TIME_SAFE_STABLE_MAC", .kind = .value, .value = "" },
    .{ .name = "ALIGNOF_LONG", .kind = .alignof, .text = "long" },
    .{ .name = "ALIGNOF_MAX_ALIGN_T", .kind = .alignof, .text = "max_align_t" },
    .{ .name = "ALIGNOF_SIZE_T", .kind = .alignof, .text = "size_t" },
    .{ .name = "HAVE_ACCEPT", .kind = .address, .text = "accept", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_ACCEPT4", .kind = .func, .text = "accept4" },
    .{ .name = "HAVE_ACOSH", .kind = .func, .text = "acosh" },
    .{ .name = "HAVE_ALARM", .kind = .func, .text = "alarm" },
    .{ .name = "HAVE_ALLOCA_H", .kind = .header, .text = "alloca.h" },
    .{ .name = "HAVE_ASINH", .kind = .func, .text = "asinh" },
    .{ .name = "HAVE_ASM_TYPES_H", .kind = .header, .text = "asm/types.h" },
    .{ .name = "HAVE_ATANH", .kind = .func, .text = "atanh" },
    .{ .name = "HAVE_BACKTRACE", .kind = .func, .text = "backtrace" },
    .{ .name = "HAVE_BIND", .kind = .address, .text = "bind", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_BIND_TEXTDOMAIN_CODESET", .kind = .func, .text = "bind_textdomain_codeset" },
    .{ .name = "HAVE_BLUETOOTH_BLUETOOTH_H", .kind = .header, .text = "bluetooth/bluetooth.h" },
    .{ .name = "HAVE_BLUETOOTH_H", .kind = .header, .text = "bluetooth.h" },
    .{ .name = "HAVE_BZLIB_H", .kind = .header, .text = "bzlib.h" },
    .{ .name = "HAVE_CHMOD", .kind = .func, .text = "chmod" },
    .{ .name = "HAVE_CHOWN", .kind = .func, .text = "chown" },
    .{ .name = "HAVE_CHROOT", .kind = .address, .text = "chroot", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_CLOCK", .kind = .func, .text = "clock" },
    .{ .name = "HAVE_CLOCK_GETRES", .kind = .func, .text = "clock_getres" },
    .{ .name = "HAVE_CLOCK_GETTIME", .kind = .func, .text = "clock_gettime" },
    .{ .name = "HAVE_CLOCK_NANOSLEEP", .kind = .func, .text = "clock_nanosleep" },
    .{ .name = "HAVE_CLOCK_SETTIME", .kind = .func, .text = "clock_settime" },
    .{ .name = "HAVE_CLOCK_T", .kind = .type, .text = "clock_t", .includes = "#include <time.h>\n" },
    .{ .name = "HAVE_CLOSEFROM", .kind = .func, .text = "closefrom" },
    .{ .name = "HAVE_CLOSE_RANGE", .kind = .func, .text = "close_range" },
    .{ .name = "HAVE_CONFSTR", .kind = .func, .text = "confstr" },
    .{ .name = "HAVE_CONIO_H", .kind = .header, .text = "conio.h" },
    .{ .name = "HAVE_CONNECT", .kind = .address, .text = "connect", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_COPY_FILE_RANGE", .kind = .func, .text = "copy_file_range" },
    .{ .name = "HAVE_CTERMID", .kind = .func, .text = "ctermid" },
    .{ .name = "HAVE_CTERMID_R", .kind = .address, .text = "ctermid_r", .includes = "#include <stdio.h>\n" },
    .{ .name = "HAVE_CURSES_H", .kind = .header, .text = "curses.h" },
    .{ .name = "HAVE_DB_H", .kind = .header, .text = "db.h" },
    .{ .name = "HAVE_DECL_RTLD_DEEPBIND", .kind = .decl, .text = "RTLD_DEEPBIND", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_GLOBAL", .kind = .decl, .text = "RTLD_GLOBAL", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_LAZY", .kind = .decl, .text = "RTLD_LAZY", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_LOCAL", .kind = .decl, .text = "RTLD_LOCAL", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_MEMBER", .kind = .decl, .text = "RTLD_MEMBER", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_NODELETE", .kind = .decl, .text = "RTLD_NODELETE", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_NOLOAD", .kind = .decl, .text = "RTLD_NOLOAD", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_RTLD_NOW", .kind = .decl, .text = "RTLD_NOW", .includes = "#include <dlfcn.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DECL_UT_NAMESIZE", .kind = .decl, .text = "UT_NAMESIZE", .includes = "#include <utmp.h>\n", .otherwise = "0" },
    .{ .name = "HAVE_DIRECT_H", .kind = .header, .text = "direct.h" },
    .{ .name = "HAVE_DLADDR", .kind = .func, .text = "dladdr" },
    .{ .name = "HAVE_DLADDR1", .kind = .func, .text = "dladdr1" },
    .{ .name = "HAVE_DLFCN_H", .kind = .header, .text = "dlfcn.h" },
    .{ .name = "HAVE_DLOPEN", .kind = .func, .text = "dlopen" },
    .{ .name = "HAVE_DUP", .kind = .func, .text = "dup" },
    .{ .name = "HAVE_DUP3", .kind = .func, .text = "dup3" },
    .{ .name = "HAVE_DYLD_SHARED_CACHE_CONTAINS_PATH", .kind = .address, .text = "_dyld_shared_cache_contains_path", .includes = "#include <mach-o/dyld.h>\n" },
    .{ .name = "HAVE_EDITLINE_READLINE_H", .kind = .header, .text = "editline/readline.h" },
    .{ .name = "HAVE_ENDIAN_H", .kind = .header, .text = "endian.h" },
    .{ .name = "HAVE_EPOLL", .kind = .address, .text = "epoll_create", .includes = "#include <sys/epoll.h>\n" },
    .{ .name = "HAVE_EPOLL_CREATE1", .kind = .address, .text = "epoll_create1", .includes = "#include <sys/epoll.h>\n" },
    .{ .name = "HAVE_ERF", .kind = .func, .text = "erf" },
    .{ .name = "HAVE_ERFC", .kind = .func, .text = "erfc" },
    .{ .name = "HAVE_ERRNO_H", .kind = .header, .text = "errno.h" },
    .{ .name = "HAVE_EVENTFD", .kind = .address, .text = "eventfd", .includes = "#ifdef HAVE_SYS_EVENTFD_H\n#include <sys/eventfd.h>\n#endif\n" },
    .{ .name = "HAVE_EXECINFO_H", .kind = .header, .text = "execinfo.h" },
    .{ .name = "HAVE_EXECV", .kind = .func, .text = "execv" },
    .{ .name = "HAVE_EXPLICIT_BZERO", .kind = .func, .text = "explicit_bzero" },
    .{ .name = "HAVE_EXPLICIT_MEMSET", .kind = .func, .text = "explicit_memset" },
    .{ .name = "HAVE_EXPM1", .kind = .func, .text = "expm1" },
    .{ .name = "HAVE_FACCESSAT", .kind = .func, .text = "faccessat" },
    .{ .name = "HAVE_FCHDIR", .kind = .address, .text = "fchdir", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_FCHMOD", .kind = .func, .text = "fchmod" },
    .{ .name = "HAVE_FCHMODAT", .kind = .func, .text = "fchmodat" },
    .{ .name = "HAVE_FCHOWN", .kind = .func, .text = "fchown" },
    .{ .name = "HAVE_FCHOWNAT", .kind = .func, .text = "fchownat" },
    .{ .name = "HAVE_FCNTL_H", .kind = .header, .text = "fcntl.h" },
    .{ .name = "HAVE_FDATASYNC", .kind = .address, .text = "fdatasync", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_FDOPENDIR", .kind = .func, .text = "fdopendir" },
    .{ .name = "HAVE_FDWALK", .kind = .func, .text = "fdwalk" },
    .{ .name = "HAVE_FEXECVE", .kind = .func, .text = "fexecve" },
    .{ .name = "HAVE_FFI_CLOSURE_ALLOC", .kind = .address, .text = "ffi_closure_alloc", .includes = "#include <ffi.h>\n" },
    .{ .name = "HAVE_FFI_PREP_CIF_VAR", .kind = .address, .text = "ffi_prep_cif_var", .includes = "#include <ffi.h>\n" },
    .{ .name = "HAVE_FFI_PREP_CLOSURE_LOC", .kind = .address, .text = "ffi_prep_closure_loc", .includes = "#include <ffi.h>\n" },
    .{ .name = "HAVE_FLOCK", .kind = .func, .text = "flock" },
    .{ .name = "HAVE_FORK", .kind = .func, .text = "fork" },
    .{ .name = "HAVE_FORK1", .kind = .func, .text = "fork1" },
    .{ .name = "HAVE_FORKPTY", .kind = .func, .text = "forkpty" },
    .{ .name = "HAVE_FPATHCONF", .kind = .func, .text = "fpathconf" },
    .{ .name = "HAVE_FSEEK64", .kind = .func, .text = "fseek64" },
    .{ .name = "HAVE_FSEEKO", .kind = .func, .text = "fseeko" },
    .{ .name = "HAVE_FSTATAT", .kind = .func, .text = "fstatat" },
    .{ .name = "HAVE_FSTATVFS", .kind = .func, .text = "fstatvfs" },
    .{ .name = "HAVE_FSYNC", .kind = .address, .text = "fsync", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_FTELL64", .kind = .func, .text = "ftell64" },
    .{ .name = "HAVE_FTELLO", .kind = .func, .text = "ftello" },
    .{ .name = "HAVE_FTIME", .kind = .func, .text = "ftime" },
    .{ .name = "HAVE_FTRUNCATE", .kind = .func, .text = "ftruncate" },
    .{ .name = "HAVE_FUTIMENS", .kind = .func, .text = "futimens" },
    .{ .name = "HAVE_FUTIMES", .kind = .func, .text = "futimes" },
    .{ .name = "HAVE_FUTIMESAT", .kind = .func, .text = "futimesat" },
    .{ .name = "HAVE_GAI_STRERROR", .kind = .func, .text = "gai_strerror" },
    .{ .name = "HAVE_GDBM_H", .kind = .header, .text = "gdbm.h" },
    .{ .name = "HAVE_GETEGID", .kind = .func, .text = "getegid" },
    .{ .name = "HAVE_GETENTROPY", .kind = .func, .text = "getentropy" },
    .{ .name = "HAVE_GETEUID", .kind = .func, .text = "geteuid" },
    .{ .name = "HAVE_GETGID", .kind = .func, .text = "getgid" },
    .{ .name = "HAVE_GETGRENT", .kind = .func, .text = "getgrent" },
    .{ .name = "HAVE_GETGRGID", .kind = .func, .text = "getgrgid" },
    .{ .name = "HAVE_GETGRGID_R", .kind = .func, .text = "getgrgid_r" },
    .{ .name = "HAVE_GETGRNAM_R", .kind = .func, .text = "getgrnam_r" },
    .{ .name = "HAVE_GETGROUPLIST", .kind = .func, .text = "getgrouplist" },
    .{ .name = "HAVE_GETGROUPS", .kind = .func, .text = "getgroups" },
    .{ .name = "HAVE_GETHOSTBYADDR", .kind = .address, .text = "gethostbyaddr", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_GETHOSTBYNAME", .kind = .address, .text = "gethostbyname", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_GETHOSTNAME", .kind = .func, .text = "gethostname" },
    .{ .name = "HAVE_GETITIMER", .kind = .func, .text = "getitimer" },
    .{ .name = "HAVE_GETLOADAVG", .kind = .func, .text = "getloadavg" },
    .{ .name = "HAVE_GETLOGIN", .kind = .func, .text = "getlogin" },
    .{ .name = "HAVE_GETLOGIN_R", .kind = .func, .text = "getlogin_r" },
    .{ .name = "HAVE_GETNAMEINFO", .kind = .func, .text = "getnameinfo" },
    .{ .name = "HAVE_GETPAGESIZE", .kind = .address, .text = "getpagesize", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_GETPEERNAME", .kind = .func, .text = "getpeername" },
    .{ .name = "HAVE_GETPGID", .kind = .func, .text = "getpgid" },
    .{ .name = "HAVE_GETPGRP", .kind = .func, .text = "getpgrp" },
    .{ .name = "HAVE_GETPID", .kind = .func, .text = "getpid" },
    .{ .name = "HAVE_GETPPID", .kind = .func, .text = "getppid" },
    .{ .name = "HAVE_GETPRIORITY", .kind = .func, .text = "getpriority" },
    .{ .name = "HAVE_GETPROTOBYNAME", .kind = .address, .text = "getprotobyname", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_GETPWENT", .kind = .func, .text = "getpwent" },
    .{ .name = "HAVE_GETPWNAM_R", .kind = .func, .text = "getpwnam_r" },
    .{ .name = "HAVE_GETPWUID", .kind = .func, .text = "getpwuid" },
    .{ .name = "HAVE_GETPWUID_R", .kind = .func, .text = "getpwuid_r" },
    .{ .name = "HAVE_GETRESGID", .kind = .func, .text = "getresgid" },
    .{ .name = "HAVE_GETRESUID", .kind = .func, .text = "getresuid" },
    .{ .name = "HAVE_GETRUSAGE", .kind = .func, .text = "getrusage" },
    .{ .name = "HAVE_GETSERVBYNAME", .kind = .address, .text = "getservbyname", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_GETSERVBYPORT", .kind = .address, .text = "getservbyport", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_GETSID", .kind = .func, .text = "getsid" },
    .{ .name = "HAVE_GETSOCKNAME", .kind = .address, .text = "getsockname", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_GETSPENT", .kind = .func, .text = "getspent" },
    .{ .name = "HAVE_GETSPNAM", .kind = .func, .text = "getspnam" },
    .{ .name = "HAVE_GETUID", .kind = .func, .text = "getuid" },
    .{ .name = "HAVE_GETWD", .kind = .func, .text = "getwd" },
    .{ .name = "HAVE_GRANTPT", .kind = .func, .text = "grantpt" },
    .{ .name = "HAVE_GRP_H", .kind = .header, .text = "grp.h" },
    .{ .name = "HAVE_HSTRERROR", .kind = .address, .text = "hstrerror", .includes = "#include <netdb.h>\n" },
    .{ .name = "HAVE_IF_NAMEINDEX", .kind = .func, .text = "if_nameindex" },
    .{ .name = "HAVE_INET_ATON", .kind = .address, .text = "inet_aton", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_INET_NTOA", .kind = .address, .text = "inet_ntoa", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_INET_PTON", .kind = .address, .text = "inet_pton", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_INITGROUPS", .kind = .func, .text = "initgroups" },
    .{ .name = "HAVE_IO_H", .kind = .header, .text = "io.h" },
    .{ .name = "HAVE_KILL", .kind = .func, .text = "kill" },
    .{ .name = "HAVE_KILLPG", .kind = .func, .text = "killpg" },
    .{ .name = "HAVE_KQUEUE", .kind = .address, .text = "kqueue", .includes = "#include <sys/types.h>\n#include <sys/event.h>\n" },
    .{ .name = "HAVE_LANGINFO_H", .kind = .header, .text = "langinfo.h" },
    .{ .name = "HAVE_LCHMOD", .kind = .func, .text = "lchmod" },
    .{ .name = "HAVE_LCHOWN", .kind = .func, .text = "lchown" },
    .{ .name = "HAVE_LIBDL", .kind = .lib, .text = "-ldl", .symbol = "dlopen" },
    .{ .name = "HAVE_LIBDLD", .kind = .lib, .text = "-ldld", .symbol = "shl_load" },
    .{ .name = "HAVE_LIBIEEE", .kind = .lib, .text = "-lieee", .symbol = "__fpu_control" },
    .{ .name = "HAVE_LIBINTL_H", .kind = .header, .text = "libintl.h" },
    .{ .name = "HAVE_LIBSENDFILE", .kind = .lib, .text = "-lsendfile", .symbol = "sendfile" },
    .{ .name = "HAVE_LIBUTIL_H", .kind = .header, .text = "libutil.h" },
    .{ .name = "HAVE_LINK", .kind = .address, .text = "link", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_LINKAT", .kind = .func, .text = "linkat" },
    .{ .name = "HAVE_LINK_H", .kind = .header, .text = "link.h" },
    .{ .name = "HAVE_LINUX_AUXVEC_H", .kind = .header, .text = "linux/auxvec.h" },
    .{ .name = "HAVE_LINUX_CAN_BCM_H", .kind = .header, .text = "linux/can/bcm.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_CAN_H", .kind = .header, .text = "linux/can.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_CAN_J1939_H", .kind = .header, .text = "linux/can/j1939.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_CAN_RAW_H", .kind = .header, .text = "linux/can/raw.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_FS_H", .kind = .header, .text = "linux/fs.h" },
    .{ .name = "HAVE_LINUX_LIMITS_H", .kind = .header, .text = "linux/limits.h" },
    .{ .name = "HAVE_LINUX_MEMFD_H", .kind = .header, .text = "linux/memfd.h" },
    .{ .name = "HAVE_LINUX_NETFILTER_IPV4_H", .kind = .header, .text = "linux/netfilter_ipv4.h" },
    .{ .name = "HAVE_LINUX_NETLINK_H", .kind = .header, .text = "linux/netlink.h", .includes = "#ifdef HAVE_ASM_TYPES_H\n#include <asm/types.h>\n#endif\n#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_QRTR_H", .kind = .header, .text = "linux/qrtr.h", .includes = "#ifdef HAVE_ASM_TYPES_H\n#include <asm/types.h>\n#endif\n#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_RANDOM_H", .kind = .header, .text = "linux/random.h" },
    .{ .name = "HAVE_LINUX_SCHED_H", .kind = .header, .text = "linux/sched.h" },
    .{ .name = "HAVE_LINUX_SOUNDCARD_H", .kind = .header, .text = "linux/soundcard.h" },
    .{ .name = "HAVE_LINUX_TIPC_H", .kind = .header, .text = "linux/tipc.h" },
    .{ .name = "HAVE_LINUX_VM_SOCKETS_H", .kind = .header, .text = "linux/vm_sockets.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_LINUX_WAIT_H", .kind = .header, .text = "linux/wait.h" },
    .{ .name = "HAVE_LISTEN", .kind = .address, .text = "listen", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_LOCKF", .kind = .func, .text = "lockf" },
    .{ .name = "HAVE_LOG1P", .kind = .func, .text = "log1p" },
    .{ .name = "HAVE_LOG2", .kind = .func, .text = "log2" },
    .{ .name = "HAVE_LSTAT", .kind = .func, .text = "lstat" },
    .{ .name = "HAVE_LUTIMES", .kind = .func, .text = "lutimes" },
    .{ .name = "HAVE_LZMA_H", .kind = .header, .text = "lzma.h" },
    .{ .name = "HAVE_MADVISE", .kind = .func, .text = "madvise" },
    .{ .name = "HAVE_MBRTOWC", .kind = .func, .text = "mbrtowc" },
    .{ .name = "HAVE_MEMFD_CREATE", .kind = .address, .text = "memfd_create", .includes = "#ifdef HAVE_SYS_MMAN_H\n#include <sys/mman.h>\n#endif\n#ifdef HAVE_SYS_MEMFD_H\n#include <sys/memfd.h>\n#endif\n" },
    .{ .name = "HAVE_MEMRCHR", .kind = .func, .text = "memrchr" },
    .{ .name = "HAVE_MKDIRAT", .kind = .func, .text = "mkdirat" },
    .{ .name = "HAVE_MKFIFO", .kind = .func, .text = "mkfifo" },
    .{ .name = "HAVE_MKFIFOAT", .kind = .func, .text = "mkfifoat" },
    .{ .name = "HAVE_MKNOD", .kind = .func, .text = "mknod" },
    .{ .name = "HAVE_MKNODAT", .kind = .func, .text = "mknodat" },
    .{ .name = "HAVE_MKTIME", .kind = .func, .text = "mktime" },
    .{ .name = "HAVE_MMAP", .kind = .func, .text = "mmap" },
    .{ .name = "HAVE_MREMAP", .kind = .func, .text = "mremap" },
    .{ .name = "HAVE_NANOSLEEP", .kind = .func, .text = "nanosleep" },
    .{ .name = "HAVE_NCURSESW_CURSES_H", .kind = .header, .text = "ncursesw/curses.h" },
    .{ .name = "HAVE_NCURSESW_NCURSES_H", .kind = .header, .text = "ncursesw/ncurses.h" },
    .{ .name = "HAVE_NCURSESW_PANEL_H", .kind = .header, .text = "ncursesw/panel.h" },
    .{ .name = "HAVE_NCURSES_CURSES_H", .kind = .header, .text = "ncurses/curses.h" },
    .{ .name = "HAVE_NCURSES_H", .kind = .header, .text = "ncurses.h" },
    .{ .name = "HAVE_NCURSES_NCURSES_H", .kind = .header, .text = "ncurses/ncurses.h" },
    .{ .name = "HAVE_NCURSES_PANEL_H", .kind = .header, .text = "ncurses/panel.h" },
    .{ .name = "HAVE_NDBM_H", .kind = .header, .text = "ndbm.h" },
    .{ .name = "HAVE_NETCAN_CAN_H", .kind = .header, .text = "netcan/can.h", .includes = "#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_NETDB_H", .kind = .header, .text = "netdb.h" },
    .{ .name = "HAVE_NETINET_IN_H", .kind = .header, .text = "netinet/in.h" },
    .{ .name = "HAVE_NETLINK_NETLINK_H", .kind = .header, .text = "netlink/netlink.h", .includes = "#ifdef HAVE_ASM_TYPES_H\n#include <asm/types.h>\n#endif\n#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_NETPACKET_PACKET_H", .kind = .header, .text = "netpacket/packet.h" },
    .{ .name = "HAVE_NET_ETHERNET_H", .kind = .header, .text = "net/ethernet.h" },
    .{ .name = "HAVE_NET_IF_H", .kind = .header, .text = "net/if.h", .includes = "#include <stdio.h>\n#include <stdlib.h>\n#include <stddef.h>\n#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_NICE", .kind = .func, .text = "nice" },
    .{ .name = "HAVE_OPENAT", .kind = .func, .text = "openat" },
    .{ .name = "HAVE_OPENDIR", .kind = .func, .text = "opendir" },
    .{ .name = "HAVE_OPENPTY", .kind = .func, .text = "openpty" },
    .{ .name = "HAVE_PANEL_H", .kind = .header, .text = "panel.h" },
    .{ .name = "HAVE_PATHCONF", .kind = .func, .text = "pathconf" },
    .{ .name = "HAVE_PAUSE", .kind = .func, .text = "pause" },
    .{ .name = "HAVE_PIPE", .kind = .func, .text = "pipe" },
    .{ .name = "HAVE_PIPE2", .kind = .func, .text = "pipe2" },
    .{ .name = "HAVE_PLOCK", .kind = .func, .text = "plock" },
    .{ .name = "HAVE_POLL", .kind = .func, .text = "poll" },
    .{ .name = "HAVE_POLL_H", .kind = .header, .text = "poll.h" },
    .{ .name = "HAVE_POSIX_FADVISE", .kind = .func, .text = "posix_fadvise" },
    .{ .name = "HAVE_POSIX_FALLOCATE", .kind = .func, .text = "posix_fallocate" },
    .{ .name = "HAVE_POSIX_OPENPT", .kind = .func, .text = "posix_openpt" },
    .{ .name = "HAVE_POSIX_SPAWN", .kind = .func, .text = "posix_spawn" },
    .{ .name = "HAVE_POSIX_SPAWNP", .kind = .func, .text = "posix_spawnp" },
    .{ .name = "HAVE_POSIX_SPAWN_FILE_ACTIONS_ADDCLOSEFROM_NP", .kind = .func, .text = "posix_spawn_file_actions_addclosefrom_np" },
    .{ .name = "HAVE_PREAD", .kind = .func, .text = "pread" },
    .{ .name = "HAVE_PREADV", .kind = .func, .text = "preadv" },
    .{ .name = "HAVE_PREADV2", .kind = .func, .text = "preadv2" },
    .{ .name = "HAVE_PRLIMIT", .kind = .address, .text = "prlimit", .includes = "#include <sys/time.h>\n#include <sys/resource.h>\n" },
    .{ .name = "HAVE_PROCESS_H", .kind = .header, .text = "process.h" },
    .{ .name = "HAVE_PROCESS_VM_READV", .kind = .func, .text = "process_vm_readv" },
    .{ .name = "HAVE_PTHREAD_CONDATTR_SETCLOCK", .kind = .func, .text = "pthread_condattr_setclock" },
    .{ .name = "HAVE_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP", .kind = .func, .text = "pthread_cond_timedwait_relative_np" },
    .{ .name = "HAVE_PTHREAD_GETATTR_NP", .kind = .func, .text = "pthread_getattr_np" },
    .{ .name = "HAVE_PTHREAD_GETCPUCLOCKID", .kind = .func, .text = "pthread_getcpuclockid" },
    .{ .name = "HAVE_PTHREAD_GETNAME_NP", .kind = .func, .text = "pthread_getname_np" },
    .{ .name = "HAVE_PTHREAD_GET_NAME_NP", .kind = .func, .text = "pthread_get_name_np" },
    .{ .name = "HAVE_PTHREAD_H", .kind = .header, .text = "pthread.h" },
    .{ .name = "HAVE_PTHREAD_INIT", .kind = .func, .text = "pthread_init" },
    .{ .name = "HAVE_PTHREAD_KILL", .kind = .func, .text = "pthread_kill" },
    .{ .name = "HAVE_PTHREAD_SETNAME_NP", .kind = .func, .text = "pthread_setname_np" },
    .{ .name = "HAVE_PTHREAD_SET_NAME_NP", .kind = .func, .text = "pthread_set_name_np" },
    .{ .name = "HAVE_PTHREAD_SIGMASK", .kind = .func, .text = "pthread_sigmask" },
    .{ .name = "HAVE_PTSNAME", .kind = .func, .text = "ptsname" },
    .{ .name = "HAVE_PTSNAME_R", .kind = .func, .text = "ptsname_r" },
    .{ .name = "HAVE_PTY_H", .kind = .header, .text = "pty.h" },
    .{ .name = "HAVE_PWRITE", .kind = .func, .text = "pwrite" },
    .{ .name = "HAVE_PWRITEV", .kind = .func, .text = "pwritev" },
    .{ .name = "HAVE_PWRITEV2", .kind = .func, .text = "pwritev2" },
    .{ .name = "HAVE_READLINE_READLINE_H", .kind = .header, .text = "readline/readline.h" },
    .{ .name = "HAVE_READLINK", .kind = .func, .text = "readlink" },
    .{ .name = "HAVE_READLINKAT", .kind = .func, .text = "readlinkat" },
    .{ .name = "HAVE_READV", .kind = .func, .text = "readv" },
    .{ .name = "HAVE_REALPATH", .kind = .func, .text = "realpath" },
    .{ .name = "HAVE_RECVFROM", .kind = .address, .text = "recvfrom", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_RENAMEAT", .kind = .func, .text = "renameat" },
    .{ .name = "HAVE_RL_COMPDISP_FUNC_T", .kind = .type, .text = "rl_compdisp_func_t", .includes = "readline_includes\n" },
    .{ .name = "HAVE_RTPSPAWN", .kind = .func, .text = "rtpSpawn" },
    .{ .name = "HAVE_SCHED_GET_PRIORITY_MAX", .kind = .func, .text = "sched_get_priority_max" },
    .{ .name = "HAVE_SCHED_H", .kind = .header, .text = "sched.h" },
    .{ .name = "HAVE_SCHED_RR_GET_INTERVAL", .kind = .func, .text = "sched_rr_get_interval" },
    .{ .name = "HAVE_SCHED_SETAFFINITY", .kind = .func, .text = "sched_setaffinity" },
    .{ .name = "HAVE_SCHED_SETPARAM", .kind = .func, .text = "sched_setparam" },
    .{ .name = "HAVE_SCHED_SETSCHEDULER", .kind = .func, .text = "sched_setscheduler" },
    .{ .name = "HAVE_SEM_CLOCKWAIT", .kind = .func, .text = "sem_clockwait" },
    .{ .name = "HAVE_SEM_GETVALUE", .kind = .func, .text = "sem_getvalue" },
    .{ .name = "HAVE_SEM_OPEN", .kind = .func, .text = "sem_open" },
    .{ .name = "HAVE_SEM_TIMEDWAIT", .kind = .func, .text = "sem_timedwait" },
    .{ .name = "HAVE_SEM_UNLINK", .kind = .func, .text = "sem_unlink" },
    .{ .name = "HAVE_SENDFILE", .kind = .func, .text = "sendfile" },
    .{ .name = "HAVE_SENDTO", .kind = .address, .text = "sendto", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_SETEGID", .kind = .func, .text = "setegid" },
    .{ .name = "HAVE_SETEUID", .kind = .func, .text = "seteuid" },
    .{ .name = "HAVE_SETGID", .kind = .func, .text = "setgid" },
    .{ .name = "HAVE_SETGROUPS", .kind = .address, .text = "setgroups", .includes = "#include <unistd.h>\n#ifdef HAVE_GRP_H\n#include <grp.h>\n#endif\n" },
    .{ .name = "HAVE_SETHOSTNAME", .kind = .func, .text = "sethostname" },
    .{ .name = "HAVE_SETITIMER", .kind = .func, .text = "setitimer" },
    .{ .name = "HAVE_SETJMP_H", .kind = .header, .text = "setjmp.h" },
    .{ .name = "HAVE_SETLOCALE", .kind = .func, .text = "setlocale" },
    .{ .name = "HAVE_SETNS", .kind = .func, .text = "setns" },
    .{ .name = "HAVE_SETPGID", .kind = .func, .text = "setpgid" },
    .{ .name = "HAVE_SETPGRP", .kind = .func, .text = "setpgrp" },
    .{ .name = "HAVE_SETPRIORITY", .kind = .func, .text = "setpriority" },
    .{ .name = "HAVE_SETREGID", .kind = .func, .text = "setregid" },
    .{ .name = "HAVE_SETRESGID", .kind = .func, .text = "setresgid" },
    .{ .name = "HAVE_SETRESUID", .kind = .func, .text = "setresuid" },
    .{ .name = "HAVE_SETREUID", .kind = .func, .text = "setreuid" },
    .{ .name = "HAVE_SETSID", .kind = .func, .text = "setsid" },
    .{ .name = "HAVE_SETSOCKOPT", .kind = .address, .text = "setsockopt", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_SETUID", .kind = .func, .text = "setuid" },
    .{ .name = "HAVE_SETVBUF", .kind = .func, .text = "setvbuf" },
    .{ .name = "HAVE_SHADOW_H", .kind = .header, .text = "shadow.h" },
    .{ .name = "HAVE_SHM_OPEN", .kind = .func, .text = "shm_open" },
    .{ .name = "HAVE_SHM_UNLINK", .kind = .func, .text = "shm_unlink" },
    .{ .name = "HAVE_SHUTDOWN", .kind = .func, .text = "shutdown" },
    .{ .name = "HAVE_SIGACTION", .kind = .func, .text = "sigaction" },
    .{ .name = "HAVE_SIGALTSTACK", .kind = .func, .text = "sigaltstack" },
    .{ .name = "HAVE_SIGFILLSET", .kind = .func, .text = "sigfillset" },
    .{ .name = "HAVE_SIGINFO_T_SI_BAND", .kind = .member, .text = "siginfo_t.si_band", .includes = "#include <signal.h>\n" },
    .{ .name = "HAVE_SIGINTERRUPT", .kind = .func, .text = "siginterrupt" },
    .{ .name = "HAVE_SIGNAL_H", .kind = .header, .text = "signal.h" },
    .{ .name = "HAVE_SIGPENDING", .kind = .func, .text = "sigpending" },
    .{ .name = "HAVE_SIGRELSE", .kind = .func, .text = "sigrelse" },
    .{ .name = "HAVE_SIGTIMEDWAIT", .kind = .func, .text = "sigtimedwait" },
    .{ .name = "HAVE_SIGWAIT", .kind = .func, .text = "sigwait" },
    .{ .name = "HAVE_SIGWAITINFO", .kind = .func, .text = "sigwaitinfo" },
    .{ .name = "HAVE_SNPRINTF", .kind = .func, .text = "snprintf" },
    .{ .name = "HAVE_SOCKET", .kind = .address, .text = "socket", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n" },
    .{ .name = "HAVE_SOCKETPAIR", .kind = .address, .text = "socketpair", .includes = "#include <sys/types.h>\n#include <sys/socket.h>\n" },
    .{ .name = "HAVE_SOCKLEN_T", .kind = .type, .text = "socklen_t", .includes = "#ifdef HAVE_SYS_TYPES_H\n#include <sys/types.h>\n#endif\n#ifdef HAVE_SYS_SOCKET_H\n#include <sys/socket.h>\n#endif\n" },
    .{ .name = "HAVE_SPAWN_H", .kind = .header, .text = "spawn.h" },
    .{ .name = "HAVE_SPLICE", .kind = .func, .text = "splice" },
    .{ .name = "HAVE_SSIZE_T", .kind = .type, .text = "ssize_t" },
    .{ .name = "HAVE_STATVFS", .kind = .func, .text = "statvfs" },
    .{ .name = "HAVE_STRFTIME", .kind = .func, .text = "strftime" },
    .{ .name = "HAVE_STRLCPY", .kind = .func, .text = "strlcpy" },
    .{ .name = "HAVE_STROPTS_H", .kind = .header, .text = "stropts.h" },
    .{ .name = "HAVE_STRSIGNAL", .kind = .func, .text = "strsignal" },
    .{ .name = "HAVE_STRUCT_PASSWD_PW_GECOS", .kind = .member, .text = "struct passwd.pw_gecos", .includes = "#include <sys/types.h>\n#include <pwd.h>\n" },
    .{ .name = "HAVE_STRUCT_PASSWD_PW_PASSWD", .kind = .member, .text = "struct passwd.pw_passwd", .includes = "#include <sys/types.h>\n#include <pwd.h>\n" },
    .{ .name = "HAVE_STRUCT_STAT_ST_BIRTHTIME", .kind = .member, .text = "struct stat.st_birthtime" },
    .{ .name = "HAVE_STRUCT_STAT_ST_BLKSIZE", .kind = .member, .text = "struct stat.st_blksize" },
    .{ .name = "HAVE_STRUCT_STAT_ST_BLOCKS", .kind = .member, .text = "struct stat.st_blocks" },
    .{ .name = "HAVE_STRUCT_STAT_ST_FLAGS", .kind = .member, .text = "struct stat.st_flags" },
    .{ .name = "HAVE_STRUCT_STAT_ST_GEN", .kind = .member, .text = "struct stat.st_gen" },
    .{ .name = "HAVE_STRUCT_STAT_ST_RDEV", .kind = .member, .text = "struct stat.st_rdev" },
    .{ .name = "HAVE_SYMLINK", .kind = .address, .text = "symlink", .includes = "#include <unistd.h>\n" },
    .{ .name = "HAVE_SYMLINKAT", .kind = .func, .text = "symlinkat" },
    .{ .name = "HAVE_SYNC", .kind = .func, .text = "sync" },
    .{ .name = "HAVE_SYSCONF", .kind = .func, .text = "sysconf" },
    .{ .name = "HAVE_SYSEXITS_H", .kind = .header, .text = "sysexits.h" },
    .{ .name = "HAVE_SYSLOG_H", .kind = .header, .text = "syslog.h" },
    .{ .name = "HAVE_SYSTEM", .kind = .func, .text = "system" },
    .{ .name = "HAVE_SYS_AUDIOIO_H", .kind = .header, .text = "sys/audioio.h" },
    .{ .name = "HAVE_SYS_AUXV_H", .kind = .header, .text = "sys/auxv.h" },
    .{ .name = "HAVE_SYS_BSDTTY_H", .kind = .header, .text = "sys/bsdtty.h" },
    .{ .name = "HAVE_SYS_DEVPOLL_H", .kind = .header, .text = "sys/devpoll.h" },
    .{ .name = "HAVE_SYS_ENDIAN_H", .kind = .header, .text = "sys/endian.h" },
    .{ .name = "HAVE_SYS_EPOLL_H", .kind = .header, .text = "sys/epoll.h" },
    .{ .name = "HAVE_SYS_EVENTFD_H", .kind = .header, .text = "sys/eventfd.h" },
    .{ .name = "HAVE_SYS_EVENT_H", .kind = .header, .text = "sys/event.h" },
    .{ .name = "HAVE_SYS_FILE_H", .kind = .header, .text = "sys/file.h" },
    .{ .name = "HAVE_SYS_IOCTL_H", .kind = .header, .text = "sys/ioctl.h" },
    .{ .name = "HAVE_SYS_KERN_CONTROL_H", .kind = .header, .text = "sys/kern_control.h" },
    .{ .name = "HAVE_SYS_LOADAVG_H", .kind = .header, .text = "sys/loadavg.h" },
    .{ .name = "HAVE_SYS_LOCK_H", .kind = .header, .text = "sys/lock.h" },
    .{ .name = "HAVE_SYS_MEMFD_H", .kind = .header, .text = "sys/memfd.h" },
    .{ .name = "HAVE_SYS_MKDEV_H", .kind = .header, .text = "sys/mkdev.h" },
    .{ .name = "HAVE_SYS_MMAN_H", .kind = .header, .text = "sys/mman.h" },
    .{ .name = "HAVE_SYS_MODEM_H", .kind = .header, .text = "sys/modem.h" },
    .{ .name = "HAVE_SYS_PARAM_H", .kind = .header, .text = "sys/param.h" },
    .{ .name = "HAVE_SYS_PIDFD_H", .kind = .header, .text = "sys/pidfd.h" },
    .{ .name = "HAVE_SYS_POLL_H", .kind = .header, .text = "sys/poll.h" },
    .{ .name = "HAVE_SYS_RANDOM_H", .kind = .header, .text = "sys/random.h" },
    .{ .name = "HAVE_SYS_RESOURCE_H", .kind = .header, .text = "sys/resource.h" },
    .{ .name = "HAVE_SYS_SELECT_H", .kind = .header, .text = "sys/select.h" },
    .{ .name = "HAVE_SYS_SENDFILE_H", .kind = .header, .text = "sys/sendfile.h" },
    .{ .name = "HAVE_SYS_SOCKET_H", .kind = .header, .text = "sys/socket.h" },
    .{ .name = "HAVE_SYS_SOUNDCARD_H", .kind = .header, .text = "sys/soundcard.h" },
    .{ .name = "HAVE_SYS_STATVFS_H", .kind = .header, .text = "sys/statvfs.h" },
    .{ .name = "HAVE_SYS_STAT_H", .kind = .header, .text = "sys/stat.h" },
    .{ .name = "HAVE_SYS_SYSCALL_H", .kind = .header, .text = "sys/syscall.h" },
    .{ .name = "HAVE_SYS_SYSMACROS_H", .kind = .header, .text = "sys/sysmacros.h" },
    .{ .name = "HAVE_SYS_SYS_DOMAIN_H", .kind = .header, .text = "sys/sys_domain.h" },
    .{ .name = "HAVE_SYS_TERMIO_H", .kind = .header, .text = "sys/termio.h" },
    .{ .name = "HAVE_SYS_TIMERFD_H", .kind = .header, .text = "sys/timerfd.h" },
    .{ .name = "HAVE_SYS_TIMES_H", .kind = .header, .text = "sys/times.h" },
    .{ .name = "HAVE_SYS_TIME_H", .kind = .header, .text = "sys/time.h" },
    .{ .name = "HAVE_SYS_TYPES_H", .kind = .header, .text = "sys/types.h" },
    .{ .name = "HAVE_SYS_UIO_H", .kind = .header, .text = "sys/uio.h" },
    .{ .name = "HAVE_SYS_UN_H", .kind = .header, .text = "sys/un.h" },
    .{ .name = "HAVE_SYS_UTSNAME_H", .kind = .header, .text = "sys/utsname.h" },
    .{ .name = "HAVE_SYS_WAIT_H", .kind = .header, .text = "sys/wait.h" },
    .{ .name = "HAVE_SYS_XATTR_H", .kind = .header, .text = "sys/xattr.h" },
    .{ .name = "HAVE_TCGETPGRP", .kind = .func, .text = "tcgetpgrp" },
    .{ .name = "HAVE_TCSETPGRP", .kind = .func, .text = "tcsetpgrp" },
    .{ .name = "HAVE_TEMPNAM", .kind = .func, .text = "tempnam" },
    .{ .name = "HAVE_TERMIOS_H", .kind = .header, .text = "termios.h" },
    .{ .name = "HAVE_TERM_H", .kind = .header, .text = "term.h", .includes = "_CURSES_INCLUDES\n" },
    .{ .name = "HAVE_TIMEGM", .kind = .func, .text = "timegm" },
    .{ .name = "HAVE_TIMERFD_CREATE", .kind = .address, .text = "timerfd_create", .includes = "#ifdef HAVE_SYS_TIMERFD_H\n#include <sys/timerfd.h>\n#endif\n" },
    .{ .name = "HAVE_TIMES", .kind = .func, .text = "times" },
    .{ .name = "HAVE_TMPFILE", .kind = .func, .text = "tmpfile" },
    .{ .name = "HAVE_TMPNAM", .kind = .func, .text = "tmpnam" },
    .{ .name = "HAVE_TMPNAM_R", .kind = .func, .text = "tmpnam_r" },
    .{ .name = "HAVE_TRUNCATE", .kind = .func, .text = "truncate" },
    .{ .name = "HAVE_TTYNAME_R", .kind = .func, .text = "ttyname_r" },
    .{ .name = "HAVE_UMASK", .kind = .func, .text = "umask" },
    .{ .name = "HAVE_UNAME", .kind = .func, .text = "uname" },
    .{ .name = "HAVE_UNLINKAT", .kind = .func, .text = "unlinkat" },
    .{ .name = "HAVE_UNLOCKPT", .kind = .func, .text = "unlockpt" },
    .{ .name = "HAVE_UNSHARE", .kind = .func, .text = "unshare" },
    .{ .name = "HAVE_UTIL_H", .kind = .header, .text = "util.h" },
    .{ .name = "HAVE_UTIMENSAT", .kind = .func, .text = "utimensat" },
    .{ .name = "HAVE_UTIMES", .kind = .func, .text = "utimes" },
    .{ .name = "HAVE_UTIME_H", .kind = .header, .text = "utime.h" },
    .{ .name = "HAVE_UTMP_H", .kind = .header, .text = "utmp.h" },
    .{ .name = "HAVE_UUID_CREATE", .kind = .func, .text = "uuid_create" },
    .{ .name = "HAVE_UUID_ENC_BE", .kind = .func, .text = "uuid_enc_be" },
    .{ .name = "HAVE_UUID_H", .kind = .header, .text = "uuid.h" },
    .{ .name = "HAVE_UUID_UUID_H", .kind = .header, .text = "uuid/uuid.h" },
    .{ .name = "HAVE_VFORK", .kind = .func, .text = "vfork" },
    .{ .name = "HAVE_WAIT", .kind = .func, .text = "wait" },
    .{ .name = "HAVE_WAIT3", .kind = .func, .text = "wait3" },
    .{ .name = "HAVE_WAIT4", .kind = .func, .text = "wait4" },
    .{ .name = "HAVE_WAITID", .kind = .func, .text = "waitid" },
    .{ .name = "HAVE_WAITPID", .kind = .func, .text = "waitpid" },
    .{ .name = "HAVE_WCSCOLL", .kind = .func, .text = "wcscoll" },
    .{ .name = "HAVE_WCSFTIME", .kind = .func, .text = "wcsftime" },
    .{ .name = "HAVE_WCSXFRM", .kind = .func, .text = "wcsxfrm" },
    .{ .name = "HAVE_WMEMCMP", .kind = .func, .text = "wmemcmp" },
    .{ .name = "HAVE_WRITEV", .kind = .func, .text = "writev" },
    .{ .name = "HAVE_ZDICT_H", .kind = .header, .text = "zdict.h" },
    .{ .name = "HAVE_ZLIB_H", .kind = .header, .text = "zlib.h" },
    .{ .name = "HAVE_ZSTD_H", .kind = .header, .text = "zstd.h" },
    .{ .name = "HAVE__GETPTY", .kind = .func, .text = "_getpty" },
    .{ .name = "HAVE___UINT128_T", .kind = .type, .text = "__uint128_t" },
    .{ .name = "SIZEOF_DOUBLE", .kind = .sizeof, .text = "double" },
    .{ .name = "SIZEOF_FLOAT", .kind = .sizeof, .text = "float" },
    .{ .name = "SIZEOF_FPOS_T", .kind = .sizeof, .text = "fpos_t" },
    .{ .name = "SIZEOF_INT", .kind = .sizeof, .text = "int" },
    .{ .name = "SIZEOF_LONG", .kind = .sizeof, .text = "long" },
    .{ .name = "SIZEOF_LONG_DOUBLE", .kind = .sizeof, .text = "long double" },
    .{ .name = "SIZEOF_LONG_LONG", .kind = .sizeof, .text = "long long" },
    .{ .name = "SIZEOF_OFF_T", .kind = .sizeof, .text = "off_t", .includes = "#ifdef HAVE_SYS_TYPES_H\n#include <sys/types.h>\n#endif\n" },
    .{ .name = "SIZEOF_PID_T", .kind = .sizeof, .text = "pid_t" },
    .{ .name = "SIZEOF_PTHREAD_KEY_T", .kind = .sizeof, .text = "pthread_key_t", .includes = "#include <pthread.h>\n" },
    .{ .name = "SIZEOF_PTHREAD_T", .kind = .sizeof, .text = "pthread_t", .includes = "#ifdef HAVE_PTHREAD_H\n#include <pthread.h>\n#endif\n" },
    .{ .name = "SIZEOF_SHORT", .kind = .sizeof, .text = "short" },
    .{ .name = "SIZEOF_SIZE_T", .kind = .sizeof, .text = "size_t" },
    .{ .name = "SIZEOF_TIME_T", .kind = .sizeof, .text = "time_t", .includes = "#ifdef HAVE_SYS_TYPES_H\n#include <sys/types.h>\n#endif\n#ifdef HAVE_TIME_H\n#include <time.h>\n#endif\n" },
    .{ .name = "SIZEOF_UINTPTR_T", .kind = .sizeof, .text = "uintptr_t" },
    .{ .name = "SIZEOF_VOID_P", .kind = .sizeof, .text = "void *" },
    .{ .name = "SIZEOF_WCHAR_T", .kind = .sizeof, .text = "wchar_t", .includes = "#include <wchar.h>\n" },
    .{ .name = "SIZEOF__BOOL", .kind = .sizeof, .text = "_Bool" },
};
