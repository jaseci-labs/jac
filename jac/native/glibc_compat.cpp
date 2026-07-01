/* glibc floor compatibility shims for the static-linked LLVMPY_* shim (#7082).
 *
 * The x86_64 shim links a libc++ LLVM slice with `zig c++` pinned to
 * x86_64-linux-gnu.2.17 (matching CPython's manylinux2014 floor). A few glibc
 * symbols that newer LLVM/ORC objects reference only exist in later glibc, so at
 * the 2.17 floor they resolve to nothing. Provide safe fallbacks here so the
 * shipped libjacllvm.so stays at 2.17 instead of inheriting a higher floor.
 *
 * Weak, so a build at a higher glibc floor (where the real symbols exist) uses
 * glibc's definitions instead. Compiled only into the x86_64 zig link path
 * (jac/build.zig linuxShim); macOS/Windows/aarch64 never see this file. It is a
 * .cpp (not .c) because the shim link is a single `zig c++ -std=c++17` command;
 * `extern "C"` keeps the symbol names unmangled.
 *
 * __rseq_offset / __rseq_size / __rseq_flags: the restartable-sequences ABI
 * descriptors glibc >= 2.35 exports (referenced by ORC/JITLink CPU code). Zero
 * means "rseq not registered", so callers fall back to the getcpu syscall --
 * correct and harmless for a compiler shim.
 */
#include <cstddef>

extern "C" {
__attribute__((weak)) std::ptrdiff_t __rseq_offset = 0;
__attribute__((weak)) unsigned int __rseq_size = 0u;
__attribute__((weak)) unsigned int __rseq_flags = 0u;
}
