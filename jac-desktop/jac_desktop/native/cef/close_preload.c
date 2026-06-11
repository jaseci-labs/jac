/* LD_PRELOAD shim: CEF's libcef.so resolves libc close() via dlsym(RTLD_NEXT).
 * nacompile-produced executables may not export close, so zygote init crashes
 * with "close symbol missing". Preloading this library (or linking it into the
 * host) provides the symbol CEF expects. See chromiumembedded/cef#4066. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <unistd.h>

int close(int fd) {
    static int (*real_close)(int);
    if (!real_close) {
        real_close = (int (*)(int))dlsym(RTLD_NEXT, "close");
        if (!real_close) {
            void* libc = dlopen("libc.so.6", RTLD_NOW | RTLD_NOLOAD);
            if (libc) {
                real_close = (int (*)(int))dlsym(libc, "close");
                dlclose(libc);
            }
        }
    }
    return real_close ? real_close(fd) : -1;
}
