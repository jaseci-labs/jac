/* Force-included (-include) ahead of every vendored musl/wasi-libc TU.
 *
 * musl's internal build defines these in src/include/features.h, which the
 * zig-bundled wasi-libc tree omits (zig injects them via its own build).
 * We compile the vendored sources with `zig cc -target wasm32-wasi`, whose
 * driver only provides the PUBLIC libc headers, so the internal macros land
 * here instead.
 */
#pragma once
#define hidden __attribute__((__visibility__("hidden")))
#define weak __attribute__((__weak__))
#define weak_alias(old, new) \
    extern __typeof(old) new __attribute__((__weak__, __alias__(#old)))
