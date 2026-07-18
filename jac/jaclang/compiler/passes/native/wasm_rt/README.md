# wasm_rt: the in-module libc for na→wasm builds

Every `na` module compiled to wasm32 links this runtime in as LLVM bitcode
(`wasm_build.jac`), so pure-compute libc (string.h, ctype, `strtod`/`strtol`,
`snprintf` formatting, libm, and the allocator) is **inside the module**
instead of leaking into the browser as `env` imports (#7048). What still
crosses the wasm boundary is the small, versioned `jac_host1` contract defined
in `../wasm_host_abi.jac`, plus the app's own declared FFI.

## Layout

| Path | What | Origin |
| --- | --- | --- |
| `jac_alloc.c` | boundary-tag allocator (`malloc`/`free`/`calloc`/`realloc`/`malloc_usable_size`) over `__heap_base` + `memory.grow` | ours |
| `jac_io.c` | `printf`/`puts`/`putchar`: format in-module via `vsnprintf`, emit through the host's `write(fd, ptr, len)`; no C varargs ever cross the boundary | ours |
| `jac_builtins.c` | compiler-rt builtins the wasm backend emits libcalls for (`__multi3`) | ours |
| `jac_errno.c` | `errno` storage + `__errno_location`, wasi-libc model | ours |
| `jac_abi64.c` | `__jac64_*` widening adapters: the floor declares libc externs with 64-bit `size_t`/`long`, wasm32 libc uses i32, and a signature-mismatched direct call lowers to `unreachable`; `wasm_build.jac` renames the floor's declarations to these (`_ABI64_ADAPTED` must list the same names) | ours |
| `prelude.h` | musl-internal macros (`hidden`, `weak_alias`, …) normally provided by musl's own build | ours |
| `vendor/internal`, `vendor/arch/wasm32`, `vendor/private`, `vendor/stdlib/strtod.c`, `vendor/stdio/{vfprintf,vsnprintf}.c`, `vendor/errno/strerror.c` | wasm-adapted sources (fp128 long double handled via `printscan.h`) | wasi-libc, as bundled by zig 0.16.0 |
| `vendor/string`, `vendor/ctype`, `vendor/math`, `vendor/multibyte`, remaining `vendor/stdlib` + `vendor/stdio` + `vendor/locale` | pure-compute sources | musl 1.2.5 (sha256 `a9a118bb…c75e4`) |

Licenses: `vendor/LICENSE.musl` (MIT), `vendor/LICENSE.wasi-libc` (Apache-2.0
WITH LLVM-exception / Apache-2.0 / MIT).

## Local modifications to vendored files

Kept deliberately tiny; each carries a `jac wasm_rt transform` comment:

1. `vendor/include/*.h`: musl's internal overlay headers include their public
   counterparts by tree-relative path (`#include "../../include/string.h"`);
   rewritten to `#include_next <...>` so the public headers come from zig's
   wasm32-wasi sysroot.
2. `vendor/private/printscan.h`: the long-double diagnostic writes via
   `write(2, ...)` instead of `fputs(&__stderr_FILE, ...)` (would drag FILE
   machinery into every module), and `fabsl` is mapped to `fabs` alongside
   upstream's `frexpl`/`copysignl`/... mappings (unmapped it pulls fp128
   compiler-rt into every module).

## Building

`zig build vendor-wasm-libc` (or any full `zig build`) compiles every `.c`
here to one `.bc` under `.pbs-build/wasm32/libc/` via the payload tool's
`build-wasm-libc` (zig cc, `-target wasm32-wasi -O2 -g0 -fno-builtin`).
Shipped binaries carry the same set at `python/floor/wasm32/libc/`. The step
is idempotent by file count; after editing sources here, delete
`.pbs-build/wasm32/libc/` to force a rebuild. `_merged.bc` in the output dir
is a derived link-once cache created by `wasm_build.jac`; never check it in.

LLVM version note: zig's clang emits bitcode older than the jacllvm LLVM that
reads it; safe by LLVM's bitcode backward-compatibility guarantee.

## Adding a symbol

If the native floor starts calling a new libc function, the build fails with
either "wasm import 'X' is not part of the jac_host1 ABI" (unvendored symbol)
or the `_ABI64_ADAPTED` drift error (signature mismatch). Fix by either:

- vendoring the musl source here (pure compute) and, if the floor declares it
  with widened i64 types, adding a `__jac64_X` adapter to `jac_abi64.c` plus
  `_ABI64_ADAPTED` in `wasm_build.jac`; or
- adding it to `WASM_HOST_ABI` in `wasm_host_abi.jac` (genuinely host
  behavior), which is a host-contract version bump; see that file.
