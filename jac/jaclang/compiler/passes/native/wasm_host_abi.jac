"""The versioned import contract between jac native wasm modules and the host.

Everything pure-compute (string.h, ctype, strtod/strtol, snprintf/formatting,
libm, the allocator) is linked INTO the module from the vendored wasm_rt
bitcode, so it never crosses the boundary. What remains is genuinely host
behavior, and it is enumerated here — nowhere else. The WasmLinker rewrites
these imports from the object's default "env" module to WASM_HOST_MODULE and
rejects any floor-referenced symbol that is neither here nor declared by the
app (a clib import block / interop manifest), so growth of the native floor's
libc surface is a build-time error instead of a browser LinkError (#7048).

Bump WASM_HOST_MODULE (jac_host1 -> jac_host2) on any breaking change to a
member's signature or semantics; adding a new import is also a version bump,
since existing hosts would not provide it.
"""

glob WASM_HOST_MODULE: str = "jac_host1";

glob WASM_HOST_ABI: set = {
         # console / streams: formatting happens in-module (vsnprintf); the floor's
         # printf/puts collapse to write(fd, ptr, len) via wasm_rt/jac_io.c.
         "write",
         "fflush",
         # process / environment
         "exit",
         "abort",
         "getenv",
         # buffered file I/O the floor may reference (FILE* stays an opaque host
         # handle; browser hosts typically fail fopen and the floor handles it).
         "fopen",
         "fclose",
         "fread",
         "fwrite",
         "fgets",
         "ftell",
         "fseek",
         "getdelim",
         # os surface (na os module)
         "getpid",
         "getcwd",
         "system",
         "chdir",
         "rmdir",
         "unlink",
         "mkdir",
         "rename",
         "realpath",
         "access",
         "stat",
         # time
         "clock_gettime",
         "nanosleep",

     };
