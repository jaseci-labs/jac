"""Linux dynamic linker (libdl) FFI bindings for Jac native.

On glibc >= 2.34 (Ubuntu 22.04+) the dl functions are in libc.so.6 directly.
A libdl.so.2 stub that re-exports them also exists for backward compatibility;
we import from that stub since it is always present even on modern glibc.

Bun reference: Bun dlopen is via std.DynLib (Zig stdlib), not exposed to NAPI.
"""

import from engine.src.runtime.mem {
    Ptr,
    io_alloc,
    io_free,
    read_ptr,
    str_from_foreign_cstr,
    str_brfind,
    str_bslice
}

import from "libdl.so.2" {
    def dlopen(path: str, flags: int) -> int;  def dlsym(
        handle: int, symbol: str
    ) -> int;  def dlclose(handle: int) -> int;  def dlerror -> str;  def dladdr(
        addr: int, info: int
    ) -> i32;
}

glob _ENGINE_LIBRARY_DIR: str = "";

"""Directory of the shared library the engine is linked into, where its
builtins bytecode pack ships beside it: the dynamic linker names the object
that contains one of the engine's own functions (Dl_info.dli_fname)."""
def:pub engine_library_dir -> str {
    if _ENGINE_LIBRARY_DIR == "" {
        anchor: int = engine_library_dir;
        info: Ptr = io_alloc(32);
        path: str = "";
        if dladdr(anchor, info) != 0 {
            path = str_from_foreign_cstr(read_ptr(info, 0));
        }
        io_free(info);
        _ENGINE_LIBRARY_DIR = str_bslice(path, 0, str_brfind(path, "/")) if str_brfind(path, "/") > 0 else ".";
    }
    return _ENGINE_LIBRARY_DIR;
}

# ── dlopen flag constants (from <dlfcn.h>) ───────────────────────────────────

"""Lazy binding: resolve symbols only as needed."""
glob:pub RTLD_LAZY: int = 1;

"""Immediate binding: resolve all symbols before dlopen returns."""
glob:pub RTLD_NOW: int = 2;

"""Keep loaded symbols local (not visible to other dlopens)."""
glob:pub RTLD_LOCAL: int = 0;

"""Make loaded symbols global (visible to subsequently dlopen'd libraries).
   Jac's `import from "lib.so"` uses this flag automatically."""
glob:pub RTLD_GLOBAL: int = 256;

"""Do not unload the library on dlclose (RTLD_NODELETE)."""
glob:pub RTLD_NODELETE: int = 4096;

"""Pseudo-handle: look up in the main executable."""
glob:pub RTLD_DEFAULT: int = 0;

"""Pseudo-handle: look up the next symbol in the search order."""
glob:pub RTLD_NEXT: int = -1;
