//! Single source of truth for the pinned LLVM release slices.
//!
//! Consumed by BOTH launcher/payload.zig (`fetch-llvm` picks the slice for the
//! build host) and build.zig (llvmCacheDir derives the default -Dllvm-dir;
//! linuxShim picks the link path from the slice's C++ runtime). Keeping the
//! table here means a slice bump -- dirname, triple, hash, size -- is one edit
//! that build and fetch can never disagree on.

const std = @import("std");

/// LLVM release whose static archives the LLVMPY_* shim (jac/native) links
/// against. Must match the version the shim source (llvmlite 0.48.0rc1) targets.
pub const LLVM_VER = "22.1.8";

/// One pinned slice. `dirname` is the release's top-level dir (also the
/// -Dllvm-dir basename under .llvm-build). `triple`/`manifest_sha256`/`zip_size`
/// drive the range fetch (payload.zig fetchLlvmSlice). Add a row to support
/// another platform.
pub const LlvmRelease = struct {
    dirname: []const u8,
    triple: []const u8,
    manifest_sha256: []const u8,
    zip_size: u64,
};

/// The pinned slice for an (os, arch), or null for platforms we don't pin.
/// payload.zig calls this with `builtin` (the launcher's own compile target);
/// build.zig calls it with the resolved -Dtarget (the distribution target) --
/// the two agree in CI, where the runner arch matches the asset arch.
pub fn llvmRelease(os: std.Target.Os.Tag, arch: std.Target.Cpu.Arch) ?LlvmRelease {
    return switch (os) {
        .linux => switch (arch) {
            // libc++ slice (built -DLLVM_ENABLE_LIBCXX=ON with zig c++ @ 2.17):
            // the LLVMPY_* shim links it with `zig c++` for a clean glibc 2.17
            // floor (#7082). The stock `x86_64-linux` slice is libstdc++ and
            // forces a host-g++ link at the runner's glibc (~2.38).
            .x86_64 => .{
                .dirname = "LLVM-22.1.8-Linux-X64-libcxx",
                .triple = "x86_64-linux-libcxx",
                .manifest_sha256 = "6c227bfc95829729a93b8af44eeae182489df5a2bb16fd5bb5fe9b36d8877d54",
                .zip_size = 667452266,
            },
            // libc++ slice, same zig c++ @ 2.17 build as x86_64 (built natively
            // on ubuntu-24.04-arm, llvm-slice#4); isLibcxx routes the shim to
            // the zig c++/2.17 link path. Closes the #7082 aarch64 follow-up.
            .aarch64 => .{
                .dirname = "LLVM-22.1.8-Linux-ARM64-libcxx",
                .triple = "aarch64-linux-libcxx",
                .manifest_sha256 = "0315f2d83f4cab6cc5e0ef94b5d6999306109b27d0955549e7af46897ca28c34",
                .zip_size = 462054429,
            },
            else => null,
        },
        .macos => switch (arch) {
            .aarch64 => .{
                .dirname = "LLVM-22.1.8-macOS-ARM64",
                .triple = "aarch64-apple-darwin",
                .manifest_sha256 = "541721f3501de4bd4f19b0319d857b7d51651856b26fa8f600ad317edb8ea441",
                .zip_size = 743879473,
            },
            else => null,
        },
        else => null,
    };
}

/// True when the slice is a libc++ build (`*-libcxx`): its archives are
/// std::__1::* and glibc-floored by the zig pin they were built with, so the
/// shim must link them with `zig c++ -target <floor>` (build.zig linuxShim's
/// zig path) rather than the host g++/libstdc++.
pub fn isLibcxx(rel: LlvmRelease) bool {
    return std.mem.endsWith(u8, rel.triple, "-libcxx");
}
