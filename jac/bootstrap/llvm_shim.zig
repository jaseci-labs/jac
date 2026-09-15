//! Build the LLVM C ABI shim independently of the compiler image graph.
const std = @import("std");
const pins = @import("pins.zig");

// Where `zig build fetch-llvm` extracts the pinned LLVM -- one dir per platform.
// Used as the default -Dllvm-dir for the jacllvm shim. Returns null for
// platforms we don't pin a release for, so configuration remains available
// (the build then fails at mkpayload with a "run `zig build fetch-llvm`"
// message).
pub const cache_base = ".llvm-build";
fn llvmCacheDir(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    const rel = pins.llvmRelease(b, pins.osArchString(target.result)) orelse return null;
    return b.fmt("{s}/{s}", .{ cache_base, rel.dirname });
}

// The shim is an explicit artifact, installed under zig-out/lib.
pub const Shim = struct { bin: std.Build.LazyPath };

pub fn add(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Shim {
    const shim_file = switch (target.result.os.tag) {
        .windows => "jacllvm.dll",
        .macos => "libjacllvm.dylib",
        else => "libjacllvm.so",
    };

    // -Dshim-bin: bundle a PREBUILT shim (path relative to jac/ or absolute),
    // skipping the LLVM fetch and the static link entirely -- the shim is the
    // single most expensive compile artifact (it links ~0.5 GB of LLVM archives)
    // and depends on native/**, this module, the shared build policy, and the
    // pinned toolchain. CI (setup-jac) keys the shim cache on those inputs
    // so compiler-only changes can reuse it; the -Dpayload option is the same
    // idea one level up. Invalidation is the CALLER's responsibility -- a plain
    // `zig build` (no option) always links from source.
    if (b.option([]const u8, "shim-bin", "Prebuilt LLVMPY_* shim to bundle (skips the LLVM fetch + link)")) |p| {
        const bin: std.Build.LazyPath = .{ .cwd_relative = p };
        const jacllvm_step = b.step("jacllvm", "Build and install the LLVMPY_* shim");
        jacllvm_step.dependOn(&b.addInstallLibFile(bin, shim_file).step);
        return .{ .bin = bin };
    }

    // -Dllvm-dir wins; otherwise use the fetch-llvm cache (.llvm-build). If
    // neither has LLVM, return null and the build fails at mkpayload with a
    // "run `zig build fetch-llvm`" message (so fetch-llvm itself still configures
    // before LLVM exists). The shim is required -- there is no wheel fallback.
    const llvm_dir = b.option([]const u8, "llvm-dir", "Extracted LLVM 22.1.x dir (default: the fetch-llvm cache .llvm-build/...)") orelse
        (llvmCacheDir(b, target) orelse return null);
    const io = b.graph.io;
    const libdir = b.fmt("{s}/lib", .{llvm_dir});
    var dir = b.build_root.handle.openDir(io, libdir, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    // The shim wraps LLVM's C++ API; CMake builds it C++17, no-RTTI/exceptions.
    // (jac/native/CMakeLists.txt: add_library(llvmlite SHARED ...)).
    const shim_srcs = [_][]const u8{
        "assembly.cpp",        "bitcode.cpp",       "config.cpp",
        "core.cpp",            "custom_passes.cpp", "dylib.cpp",
        "executionengine.cpp", "initfini.cpp",      "linker.cpp",
        "memorymanager.cpp",   "module.cpp",        "newpassmanagers.cpp",
        "object_file.cpp",     "orcjit.cpp",        "targets.cpp",
        "type.cpp",            "value.cpp",
    };
    // -Wno-deprecated-declarations: the vendored llvmlite shim still calls a few
    // APIs LLVM 22 marks deprecated (e.g. LLVMGetGlobalContext); the warning to
    // stderr otherwise trips the system-compiler Run step's clean-stderr caching.
    const shim_flags = [_][]const u8{ "-std=c++17", "-fno-rtti", "-fno-exceptions", "-DNDEBUG", "-Wno-deprecated-declarations" };

    // Both platforms link the shim with the SYSTEM C++ compiler, matching the C++
    // standard library the official LLVM release was built against -- this is what
    // llvmlite does. macOS: Apple clang/libc++ (the macOS release is libc++; also
    // lowers ThinLTO bitcode via libLTO). Linux: g++/libstdc++ -- the LLVM 22 Linux
    // release switched from libc++ (LLVM 20) to libstdc++, so a Zig `link_libcpp`
    // (libc++) shim leaves LLVM's `std::__1::*` API calls unresolved against the
    // release's `std::__cxx11::*` archives (#6925 follow-up).
    const bin: std.Build.LazyPath = if (target.result.os.tag == .macos)
        macosShim(b, target, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags)
    else
        linuxShim(b, target, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags);

    const jacllvm_step = b.step("jacllvm", "Build and install the LLVMPY_* shim");
    jacllvm_step.dependOn(&b.addInstallLibFile(bin, shim_file).step);
    return .{ .bin = bin };
}

/// Linux link path for the LLVMPY_* shim. Which path a target takes is decided by
/// the C++ runtime of its pinned slice (pins.isLibcxx), not the arch, so
/// flipping a target to the libc++/zig path is a table edit in llvm_release.zig.
///
/// A `*-libcxx` slice (jaseci-labs/llvm-slice, a stock LLVM built
/// `-DLLVM_ENABLE_LIBCXX=ON`) links with `zig c++`: zig uses libc++, so its
/// `std::__1::*` ABI matches the slice's archives, and `-target <triple>` pins
/// BOTH the C++ runtime and the glibc floor (e.g. 2.17 via -Dtarget) for the
/// shim's own TUs -- the slice's archives are already floored at the same 2.17 by
/// the identical zig pin used to build them. zig links libc++/compiler-rt
/// statically (no -static-libstdc++ needed), and the libc++ slice is configured
/// with zlib/zstd/libxml2 OFF, so the shim references only the libc trio. This is
/// what drops libjacllvm.so from requiring GLIBC_2.38 to a clean 2.17 floor
/// (#7082). Both Linux targets (x86_64, aarch64) use libc++ slices today.
///
/// A stock (libstdc++) slice takes the system g++/libstdc++ path: it must be
/// compiled + linked with g++ to match the archives' `std::__cxx11::*` ABI (a
/// libc++ build leaves LLVM's API calls unresolved), `-static-libstdc++
/// -static-libgcc` bundles the C++ runtime, and the stock archives still
/// reference zlib/zstd/libxml2. No pinned Linux target uses this path anymore;
/// it is kept for linking official LLVM releases (e.g. a new platform before its
/// libc++ slice exists). Returns the emitted .so as a LazyPath.
fn linuxShim(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dir: *std.Io.Dir,
    llvm_dir: []const u8,
    libdir: []const u8,
    shim_srcs: []const []const u8,
    shim_flags: []const []const u8,
) std.Build.LazyPath {
    const io = b.graph.io;
    // libc++ slice -> `zig c++` (libc++ ABI + glibc floor from -Dtarget); stock
    // slice -> system g++/libstdc++. An explicit -Dllvm-dir still follows the
    // pinned slice's runtime for its target (there is no other signal for the
    // custom dir's ABI, and matching the pin is the only supported layout).
    const rel = pins.llvmRelease(b, pins.osArchString(target.result));
    const use_zig = if (rel) |r| pins.isLibcxx(r) else false;
    const cc = if (use_zig)
        b.addSystemCommand(&.{ b.graph.zig_exe, "c++" })
    else
        b.addSystemCommand(&.{"c++"});
    if (use_zig) {
        // One flag pins both the C++ runtime (zig's libc++, matching the libc++
        // slice's std::__1::*) and the glibc floor (e.g. x86_64-linux-gnu.2.17),
        // exactly the same `-target` the slice itself was built with.
        const triple = target.query.zigTriple(b.allocator) catch @panic("jacllvm: zigTriple failed");
        cc.addArgs(&.{ "-target", triple });
        // The -target triple does NOT carry the CPU: zig cc treats a host-equal
        // triple (e.g. plain x86_64-linux-gnu when no -Dtarget is passed, as in
        // the test-binary CI) as native and emits the BUILD machine's ISA
        // extensions (AVX-512 on newer runners) into the shim -- which then
        // SIGILLs when the cached binary runs on an older CPU. Pin baseline,
        // mirroring the launcher's baseline-CPU rationale at the top of build();
        // an explicit -Dcpu still wins.
        switch (target.query.cpu_model) {
            .explicit => |m| cc.addArg(b.fmt("-mcpu={s}", .{m.name})),
            else => cc.addArg("-mcpu=baseline"),
        }
    }
    cc.addArgs(&.{ "-shared", "-fPIC" });
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    // Hide everything; the LLVMPY_* API is annotated default-visibility (native/
    // core.h API_EXPORT) so it stays exported. --exclude-libs,ALL keeps the static
    // LLVM + C++ runtime symbols out of the dynamic table (no clash with a host LLVM).
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags); // -std=c++17 -fno-rtti -fno-exceptions -DNDEBUG
    // zig links its libc++/compiler-rt statically already; the system path needs the
    // GNU runtime bundled explicitly so the shipped shim has no host libstdc++.so dep.
    if (!use_zig) cc.addArgs(&.{ "-static-libstdc++", "-static-libgcc" });
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    // Shim sources passed directly (not as a .a) so their LLVMPY_* symbols survive.
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    // zig/2.17 path only: fold in the glibc-floor compat TU (weak rseq
    // descriptors) so the libc++ LLVM archives' newer-glibc refs resolve without
    // raising the floor above 2.17 (#7082). Harmless if unreferenced (weak, hidden).
    if (use_zig) cc.addFileArg(b.path("native/glibc_compat.cpp"));
    // Link every LLVM static archive inside a group (their refs are circular); the
    // linker drops what the shim never references.
    cc.addArg("-Wl,--start-group");
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    cc.addArg("-Wl,--end-group");
    // LLVM's system deps. The libc++ slice is built with zlib/zstd/libxml2 OFF, so the
    // zig path needs only the libc trio; the stock slice still references them.
    if (use_zig)
        cc.addArgs(&.{ "-lpthread", "-ldl", "-lm" })
    else
        cc.addArgs(&.{ "-lz", "-lxml2", "-lzstd", "-lpthread", "-ldl", "-lm" });
    // Keep the static LLVM/C++ symbols out of the dynamic table. zig's linker-arg
    // allowlist rejects -Wl,--exclude-libs, so the zig path uses a version script
    // that exports only the LLVMPY_* C ABI (matching the macOS -exported_symbol
    // path); the system-c++ path keeps --exclude-libs,ALL.
    if (use_zig)
        cc.addPrefixedFileArg("-Wl,--version-script,", b.path("native/jacllvm.exports"))
    else
        cc.addArg("-Wl,--exclude-libs,ALL");
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.so");
}

/// macOS link path for the LLVMPY_* shim. Zig 0.16 cannot link LLVM's official
/// macOS-ARM64 release archives: its self-hosted Mach-O linker rejects edge-case
/// object members ("unknown cpu architecture: 0") and it has no LLD Mach-O
/// backend ("using LLD to link macho files is unsupported"). So link with Apple
/// `clang++` / `ld64` -- the toolchain those archives were built with, exactly as
/// llvmlite does (jac/native/CMakeLists.txt). Compile + link in one `c++` system
/// command: the shim .cpp are passed directly (so ld64 keeps their LLVMPY_*
/// symbols rather than pruning them as it would from an archive), then
/// `-exported_symbol,_LLVMPY_*` restricts the dylib's export list to the shim API
/// (matching the CMake APPLE branch). Returns the emitted dylib as a LazyPath.
fn macosShim(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dir: *std.Io.Dir,
    llvm_dir: []const u8,
    libdir: []const u8,
    shim_srcs: []const []const u8,
    shim_flags: []const []const u8,
) std.Build.LazyPath {
    const io = b.graph.io;
    // Upstream slice (repackaged official release) vs from-source llvm-slice
    // build: decides the ThinLTO/libLTO plumbing and the external -l deps
    // below. A custom -Dllvm-dir on an unpinned platform gets the upstream
    // treatment (official releases are the only other supported layout).
    const rel = pins.llvmRelease(b, pins.osArchString(target.result));
    const upstream = if (rel) |r| r.upstream else true;
    const cc = b.addSystemCommand(&.{"c++"});
    cc.addArg("-dynamiclib");
    // Target the resolved arch explicitly rather than the host c++'s default, so a
    // Rosetta/emulated shell can't produce an x86_64 dylib against arm64 archives.
    cc.addArgs(&.{ "-arch", switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("jacllvm: unsupported macOS arch for the c++ shim link"),
    } });
    // Pin the shim's minos to the resolved target's floor, exactly like the
    // zig-built launcher: with -Dtarget=x86_64-macos.12.0 the whole shipped
    // binary floors at 12.0 instead of the build runner's macOS. Host-native
    // builds resolve to the host version, matching clang's own default.
    const macos_min = target.result.os.version_range.semver.min;
    cc.addArg(b.fmt("-mmacosx-version-min={d}.{d}", .{ macos_min.major, macos_min.minor }));
    // Respect -Doptimize the way the Linux (Zig addLibrary) path does.
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    // Match the CMake visibility preset: hide everything, the LLVMPY_* API is
    // annotated default-visibility (native/core.h API_EXPORT) so it stays exported.
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags);
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    // Shim sources passed directly (not as a .a) so ld64 keeps every LLVMPY_*.
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    // Link every LLVM static archive; ld64 drops what the shim never references.
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    // Upstream slices only: the official release archives are ThinLTO bitcode,
    // so ld64 must lower them to native code at link time via libLTO. Apple's
    // bundled libLTO tracks Xcode and is too old on the CI runners ("Invalid
    // summary version 12, should be in [1-10]" -> segfault), so point ld64 at
    // the release's OWN libLTO.dylib (kept by payload.zig fetchLlvmSlice) -- it
    // matches the bitcode it produced. This is link-time only; the output dylib
    // gains no libLTO runtime dep.
    //
    // The path MUST be absolute: ld64 silently falls back to its default libLTO
    // when -lto_library can't be resolved, and a relative path is not reliably
    // resolved from ld's cwd. Set LIBLTO_PATH too -- the env override ld honors
    // most reliably across ld64 / ld-prime.
    //
    // A from-source slice (macos-x86_64) is plain native Mach-O built with
    // zlib/zstd/libxml2 OFF: no libLTO to point at, and no external -l deps
    // either -- which keeps the shipped dylib free of Homebrew load commands.
    if (upstream) {
        const lto_dylib = b.fmt("{s}/lib/libLTO.dylib", .{llvm_dir});
        const lto_abs = if (std.fs.path.isAbsolute(lto_dylib)) lto_dylib else b.pathFromRoot(lto_dylib);
        cc.setEnvironmentVariable("LIBLTO_PATH", lto_abs);
        cc.addPrefixedFileArg("-Wl,-lto_library,", .{ .cwd_relative = lto_abs });
        // LLVM's system deps. zstd comes from Homebrew (not on the default search
        // path); z/xml2 are in the macOS SDK, and clang++ links libc++ itself.
        cc.addArgs(&.{ "-lz", "-lxml2" });
        // Homebrew's prefix is /opt/homebrew on Apple Silicon, /usr/local on Intel;
        // HOMEBREW_PREFIX overrides both for a custom install.
        const brew = b.graph.environ_map.get("HOMEBREW_PREFIX") orelse
            (if (target.result.cpu.arch == .aarch64) "/opt/homebrew" else "/usr/local");
        cc.addArgs(&.{ b.fmt("-I{s}/opt/zstd/include", .{brew}), b.fmt("-L{s}/opt/zstd/lib", .{brew}), "-lzstd" });
    }
    cc.addArgs(&.{ "-Wl,-exported_symbol,_LLVMPY_*", "-Wl,-install_name,@rpath/libjacllvm.dylib" });
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.dylib");
}
