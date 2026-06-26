//! Build the self-contained `jac` binary.
//!
//! The launcher (launcher/launcher.zig) links only libc -- it dlopens the
//! bundled CPython at runtime, so NO Python/pbs is needed to build the *stub*.
//! `zig build` then runs the pure-Zig payload tool (launcher/payload.zig) to
//! fetch a python-build-standalone tree, assemble the runtime payload, and
//! appends it to the stub with a trailer (launcher/pack.zig) -- one command.
//!
//!   zig build test                 # launcher unit tests (no libpython/pbs)
//!   zig build stub                 # just the launcher stub (no payload)
//!   zig build                      # the full jac binary -> zig-out/bin/jac
//!   zig build -Ddev                # FAST dev binary: don't bundle the compiler,
//!                                  #   link it live from the build root instead
//!   zig build -Djaclang-dir=PATH   # like -Ddev but link an explicit compiler dir
//!   zig build -Dpayload=PATH       # pack a prebuilt payload (skip fetch+mkpayload)
//!   zig build -Dpayload-progress   # stream the payload build live (no caching)
//!   zig build -Dtarget=aarch64-macos
//!
//! Build-time host tools: just `zig` and a network connection. The old bash /
//! curl / git / zstd / tar dependencies are gone -- payload.zig does HTTP,
//! integrity, (de)compression and tar in std. It shells out only to the
//! freshly-fetched pbs python (pip + JIR precompile), which provides its own
//! pip, and -- best-effort, optional -- to `strip` to shrink the unstripped
//! pbs libpython (~245 MiB -> ~20 MiB); without `strip` the build still works,
//! the binary is just larger. The shipped binary needs none of these.

const std = @import("std");

// Where `zig build fetch-llvm` extracts the pinned LLVM -- one dir per host
// platform (see payload.zig llvmRelease; keep the dirnames in sync). Used as the
// default -Dllvm-dir for the jacllvm shim. Returns null for hosts we don't pin a
// release for, so addLlvmShim degrades gracefully (the build then fails at
// mkpayload with a "run `zig build fetch-llvm`" message).
const LLVM_CACHE_BASE = ".llvm-build";
fn llvmCacheDir(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    const dirname = switch (target.result.os.tag) {
        .linux => switch (target.result.cpu.arch) {
            .x86_64 => "LLVM-22.1.8-Linux-X64",
            .aarch64 => "LLVM-22.1.8-Linux-ARM64",
            else => return null,
        },
        .macos => switch (target.result.cpu.arch) {
            .aarch64 => "LLVM-22.1.8-macOS-ARM64",
            else => return null,
        },
        else => return null,
    };
    return b.fmt("{s}/{s}", .{ LLVM_CACHE_BASE, dirname });
}

// The built LLVMPY_* shim: `bin` is bundled into the payload (--shim); `place`
// writes it into the source tree for the editable dev loop. `bin` is a LazyPath
// (not a *Compile) so the Linux `addLibrary` path and the macOS system-`c++`
// link path can both feed it through the same mkpayload/place plumbing.
const Shim = struct { bin: std.Build.LazyPath, place: *std.Build.Step };

pub fn build(b: *std.Build) void {
    // Build the launcher for a BASELINE CPU of the host arch, not the build
    // machine's native CPU. The `jac` binary is distributed -- and in CI it is
    // built once then run on other runners via the setup-jac output cache. A
    // native-CPU build emits instructions (e.g. AVX-512) a different CPU may not
    // have, crashing the launcher with SIGILL ("Illegal instruction at address
    // ..."); that in turn hangs `jac test`, whose xdist workers re-exec this
    // binary and die mid-run. The launcher is a thin shim, so baseline costs
    // nothing. If an explicit `-Dtarget=` is passed we honor it as-is; otherwise
    // we pin the host arch/os to a baseline CPU.
    const target = if (b.user_input_options.contains("target"))
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{ .cpu_model = .baseline });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    // --- LLVMPY_* shim: compile jac/native/*.cpp + statically link host LLVM ---
    // Replaces the bundled libllvmlite.so (llvmlite wheel). Gated on -Dllvm-dir
    // (an extracted LLVM 22.1.x prebuilt); without it the step is unavailable so
    // the normal binary build is unaffected. See jac/native/README.md, #6925.
    // When set, the shim replaces the llvmlite wheel in the payload below.
    const jacllvm = addLlvmShim(b, target, optimize);

    // --- launcher stub (links libc only; Python is dlopened at runtime) ----
    const launcher_mod = b.createModule(.{
        .root_source_file = b.path("launcher/launcher.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const stub = b.addExecutable(.{ .name = "jac", .root_module = launcher_mod });
    b.step("stub", "Build just the launcher stub (no payload)")
        .dependOn(&b.addInstallArtifact(stub, .{}).step);

    // --- unit tests (pure Zig, no libpython) -------------------------------
    addTests(b, target, optimize);

    // The one pure-Zig build tool (launcher/payload.zig) that replaces the old
    // bash scripts; it links only std (http/zstd/flate/tar/crypto) and shells
    // out only to the fetched pbs python (pip + JIR precompile). Built for the
    // host since it runs at build time. Created here (not inside the payload
    // block) so the arch-independent `fetch-typeshed` step can reuse it.
    const tool_mod = b.createModule(.{
        .root_source_file = b.path("launcher/payload.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const tool = b.addExecutable(.{ .name = "payload", .root_module = tool_mod });
    const root = b.pathFromRoot(".");

    // Standalone step: materialize the gitignored typeshed stdlib stubs at the
    // pinned commit, without building a binary. Used by CI (test-binary) and
    // local dev to enable from-source `jac check` / the test suite.
    {
        const fetch_ts_only = b.addRunArtifact(tool);
        fetch_ts_only.addArgs(&.{ "fetch-typeshed", root });
        fetch_ts_only.has_side_effects = true;
        b.step("fetch-typeshed", "Fetch the pinned typeshed stdlib stubs into the checkout")
            .dependOn(&fetch_ts_only.step);
    }

    // Standalone: fetch the pinned LLVM subset the jacllvm shim needs into
    // .llvm-build/ (one-time, ~84 MB range-fetched from the llvm-slice zip; set
    // JAC_LLVM_FULL_TARBALL=1 for the full upstream .tar.xz). After this, a plain
    // `zig build` picks it up via llvmCacheDir and ships the wheel-free binary.
    {
        const fetch_llvm = b.addRunArtifact(tool);
        fetch_llvm.addArgs(&.{ "fetch-llvm", b.pathFromRoot(".llvm-build") });
        fetch_llvm.has_side_effects = true;
        b.step("fetch-llvm", "Range-fetch the pinned LLVM subset for the wheel-free jacllvm shim")
            .dependOn(&fetch_llvm.step);
    }

    const osarch = osArchString(target.result) orelse {
        // Unsupported target for a full binary; stub + test steps still work.
        return;
    };

    // --- runtime payload: -Dpayload override, else fetch pbs + mkpayload ----
    const payload: std.Build.LazyPath = if (b.option([]const u8, "payload", "Path to a prebuilt runtime payload .tar.gz")) |p|
        .{ .cwd_relative = p }
    else payload: {
        const pbs_dir = b.pathFromRoot(b.fmt(".pbs-build/{s}", .{osarch}));
        const pbs_python = b.fmt("{s}/python", .{pbs_dir});

        // 1. Download + verify + extract python-build-standalone. Idempotent.
        const fetch = b.addRunArtifact(tool);
        fetch.addArgs(&.{ "fetch-pbs", osarch, pbs_dir });
        fetch.has_side_effects = true;

        // 2. Materialize the gitignored typeshed stdlib stubs at the pinned
        // commit. Idempotent; has_side_effects so a clean checkout always
        // materializes them (it is otherwise cached away as a no-arg command).
        const fetch_ts = b.addRunArtifact(tool);
        fetch_ts.addArgs(&.{ "fetch-typeshed", root });
        fetch_ts.has_side_effects = true;

        // 3. Assemble the payload. Cacheable (output-file arg), so Zig CAPTURES
        // its stdio and prints it only on failure -- the "==>" logs stay hidden.
        // `-Dpayload-progress` flips stdio to .inherit so the build streams live;
        // the tradeoff is .inherit marks the step as having side-effects, so it
        // ALWAYS repacks (no caching) while the flag is on.
        const mk = b.addRunArtifact(tool);
        mk.addArgs(&.{ "mkpayload", pbs_python, root });
        if (b.option(bool, "payload-progress", "Stream the payload build (mkpayload) live; disables its caching") orelse false) {
            mk.stdio = .inherit;
        }
        mk.step.dependOn(&fetch.step);
        mk.step.dependOn(&fetch_ts.step);
        const out = mk.addOutputFileArg("payload.tar.gz");
        // Optional trailing flags (parsed after the positional pbs/root/out):
        // --shim ships the Zig-built LLVMPY_* shim instead of pip-installing the
        // llvmlite wheel; --skip-precompile drops the JIR precompile (fast
        // wheel-free link validation; first run compiles modules on demand).
        if (jacllvm) |shim| {
            mk.addPrefixedFileArg("--shim=", shim.bin);
            // A plain `zig build` also drops the shim into the source tree so the
            // editable dev loop works without any manual step.
            b.getInstallStep().dependOn(shim.place);
        }
        if (b.option(bool, "skip-precompile", "mkpayload: skip the JIR precompile (faster link validation)") orelse false) {
            mk.addArg("--skip-precompile");
        }
        // Editable dev binary: ship a payload WITHOUT the bundled compiler and
        // reroute `import jaclang` to a live source dir at startup (see
        // _jac_finder.py apply_dev_source_override). This skips the ~100 MB tree
        // copy AND the JIR precompile, so the build is much faster -- for
        // fresh_env / contributors who run the editable dev loop anyway. The
        // resulting binary is NOT distributable: it hard-depends on `link_dir`.
        //   -Ddev            link the build root (jaclang/ in THIS tree; the case
        //                    fresh_env wants -- typeshed is already fetched here).
        //   -Djaclang-dir=P  link an explicit dir containing jaclang/ (abs, or
        //                    resolved against the build root if relative).
        const opt_jaclang_dir = b.option([]const u8, "jaclang-dir", "Editable dev binary: link the compiler from this dir (containing jaclang/) instead of bundling it");
        const opt_dev = b.option(bool, "dev", "Editable dev binary: link the compiler from the build root instead of bundling it (implies skip-precompile)") orelse false;
        const link_dir: ?[]const u8 = if (opt_jaclang_dir) |d|
            (if (std.fs.path.isAbsolute(d)) d else b.pathFromRoot(d))
        else if (opt_dev) b.pathFromRoot(".") else null;
        if (link_dir) |d| {
            mk.addArg(b.fmt("--link-source={s}", .{d}));
            // The linked binary serves the compiler from `d`, so the LLVMPY_*
            // shim must be PLACED in that tree: the compile schedule imports the
            // native passes, which ctypes-load the shim at import time -- there is
            // no bundled copy to fall back on, so a shimless linked binary crashes
            // even on `jac run`. Require the shim exactly like a normal build (its
            // `place` step, wired above via `shim.place`, writes it in-tree).
            if (jacllvm == null) std.debug.panic(
                "-Ddev/-Djaclang-dir needs the LLVM shim placed under {s}/jaclang/compiler/passes/native/llvm/. " ++
                    "Run `zig build fetch-llvm` once first (then -Ddev places it automatically).",
                .{d},
            );
        }

        // Track the payload's real inputs so it repacks when any source changes.
        // NOTE: addDirectoryArg hashes only the directory PATH (Zig 0.16
        // Run.zig), not its contents -- a bare dir arg silently never
        // invalidates. addFileInput content-hashes each file, so enumerate the
        // tree (this is what mkpayload bundles via the jaclang copy). In
        // linked-source mode none of jaclang/typeshed is bundled, so tracking it
        // would only force needless repacks on every compiler edit -- skip it;
        // the --link-source arg itself is the cache key for that mode.
        if (link_dir == null) {
            addTreeInputs(b, mk, "jaclang");
            // PIN + TARBALL_SHA256 drive the fetched typeshed version; they live
            // under jaclang/ (so addTreeInputs covers them) but list them
            // explicitly as the cache-bust keys.
            mk.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
            mk.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));
        }
        mk.addFileInput(b.path("_jac_finder.py"));
        mk.addFileInput(b.path("sitecustomize.py"));
        mk.addFileInput(b.path("jac.toml"));
        mk.addFileInput(b.path("launcher/payload.zig"));
        break :payload out;
    };

    // --- final binary: stub + payload + trailer ----------------------------
    const pack_mod = b.createModule(.{
        .root_source_file = b.path("launcher/pack.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const pack = b.addExecutable(.{ .name = "pack", .root_module = pack_mod });
    const run_pack = b.addRunArtifact(pack);
    run_pack.addFileArg(stub.getEmittedBin());
    run_pack.addFileArg(payload);
    const jac = run_pack.addOutputFileArg("jac");
    b.getInstallStep().dependOn(&b.addInstallBinFile(jac, "jac").step);
}

/// Register every bundled source file under `sub_path` as a content-hashed input
/// of `run`, so the step re-runs when any of them changes. `addDirectoryArg` only
/// hashes the directory path string, so it cannot stand in for this. Skips
/// `__pycache__`/`*.pyc` (stripped by mkpayload) and `node_modules` (regenerated
/// from the lockfile, which is itself tracked), keeping the input set to real
/// source + vendored data.
fn addTreeInputs(b: *std.Build, run: *std.Build.Step.Run, sub_path: []const u8) void {
    const io = b.graph.io;
    var dir = b.build_root.handle.openDir(io, sub_path, .{ .iterate = true }) catch |err|
        std.debug.panic("mkpayload inputs: cannot open {s}: {s}", .{ sub_path, @errorName(err) });
    defer dir.close(io);
    var walker = dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();
    while (walker.next(io) catch @panic("mkpayload inputs: walk failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.indexOf(u8, entry.path, "__pycache__") != null) continue;
        if (std.mem.indexOf(u8, entry.path, "node_modules") != null) continue;
        if (std.mem.endsWith(u8, entry.path, ".pyc")) continue;
        run.addFileInput(b.path(b.fmt("{s}/{s}", .{ sub_path, entry.path })));
    }
}

/// `zig build jacllvm -Dllvm-dir=PATH` -> compile the llvmlite LLVMPY_* C++ shim
/// (jac/native/*.cpp) and statically link the LLVM in PATH into libjacllvm.so,
/// the in-tree replacement for the 167 MB libllvmlite.so from the llvmlite wheel.
/// PATH is an extracted LLVM 22.1.x release (`lib/libLLVM*.a` + `include/`); a
/// future `fetch-llvm` step downloads it at a pinned version (mirrors fetch-pbs).
/// The Jac binding loads the result via ctypes (JAC_LLVM_SHIM / payload path).
fn addLlvmShim(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Shim {
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
        linuxShim(b, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags);

    // Also write the built shim back into the source tree (gitignored) so the
    // editable dev loop -- which runs jaclang from source, not from the binary's
    // payload -- finds it via ffi.jac's __file__-relative lookup. Mirrors how
    // fetch-typeshed materializes gitignored stubs into the tree. mkpayload's
    // jaclang copy skips this file (it ships the shim via --shim instead).
    const shim_file = switch (target.result.os.tag) {
        .windows => "jacllvm.dll",
        .macos => "libjacllvm.dylib",
        else => "libjacllvm.so",
    };
    const place = b.addUpdateSourceFiles();
    place.addCopyFileToSource(bin, b.fmt("jaclang/compiler/passes/native/llvm/{s}", .{shim_file}));

    const jacllvm_step = b.step("jacllvm", "Build the LLVMPY_* shim (jac/native), static-link LLVM, place it in-tree");
    jacllvm_step.dependOn(&b.addInstallLibFile(bin, shim_file).step);
    jacllvm_step.dependOn(&place.step);
    return .{ .bin = bin, .place = &place.step };
}

/// Linux link path for the LLVMPY_* shim. The official LLVM 22 Linux release is
/// built against GNU libstdc++ (LLVM 20 used libc++), so the shim must be compiled
/// + linked with the system g++/libstdc++ to match the archives' `std::__cxx11::*`
/// ABI -- a Zig `link_libcpp` (libc++) build leaves LLVM's API calls unresolved.
/// `-static-libstdc++ -static-libgcc` bundles the C++ runtime so the shipped shim
/// stays self-contained (no host libstdc++.so dependency, same as the old libc++
/// build). The Linux release archives are native ELF objects (not ThinLTO bitcode
/// like macOS), so no libLTO dance is needed. Returns the emitted .so as a LazyPath.
fn linuxShim(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    dir: *std.Io.Dir,
    llvm_dir: []const u8,
    libdir: []const u8,
    shim_srcs: []const []const u8,
    shim_flags: []const []const u8,
) std.Build.LazyPath {
    const io = b.graph.io;
    const cc = b.addSystemCommand(&.{"c++"});
    cc.addArgs(&.{ "-shared", "-fPIC" });
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    // Hide everything; the LLVMPY_* API is annotated default-visibility (native/
    // core.h API_EXPORT) so it stays exported. --exclude-libs,ALL keeps the static
    // LLVM/libstdc++ symbols out of the dynamic table (no clash with a host LLVM).
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags); // -std=c++17 -fno-rtti -fno-exceptions -DNDEBUG
    cc.addArgs(&.{ "-static-libstdc++", "-static-libgcc" });
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    // Shim sources passed directly (not as a .a) so their LLVMPY_* symbols survive.
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
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
    // LLVM's system deps (dynamic): zlib, libxml2, zstd, plus the usual pthread/dl/m.
    cc.addArgs(&.{ "-lz", "-lxml2", "-lzstd", "-lpthread", "-ldl", "-lm" });
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
    const cc = b.addSystemCommand(&.{"c++"});
    cc.addArg("-dynamiclib");
    // Target the resolved arch explicitly rather than the host c++'s default, so a
    // Rosetta/emulated shell can't produce an x86_64 dylib against arm64 archives.
    cc.addArgs(&.{ "-arch", switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("jacllvm: unsupported macOS arch for the c++ shim link"),
    } });
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
    // The LLVM release archives are ThinLTO bitcode, so ld64 must lower them to
    // native code at link time via libLTO. Apple's bundled libLTO tracks Xcode and
    // is too old on the CI runners ("Invalid summary version 12, should be in
    // [1-10]" -> segfault), so point ld64 at the release's OWN libLTO.dylib (kept
    // by payload.zig extractLlvmSubset) -- it matches the bitcode it produced.
    // This is link-time only; the output dylib gains no libLTO runtime dep.
    //
    // The path MUST be absolute: ld64 silently falls back to its default libLTO
    // when -lto_library can't be resolved, and a relative path is not reliably
    // resolved from ld's cwd. Set LIBLTO_PATH too -- the env override ld honors
    // most reliably across ld64 / ld-prime.
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
    cc.addArgs(&.{ "-Wl,-exported_symbol,_LLVMPY_*", "-Wl,-install_name,@rpath/libjacllvm.dylib" });
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.dylib");
}

fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("launcher/runtime.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .name = "runtime-tests", .root_module = runtime_mod });
    b.step("test", "Run launcher runtime unit tests (no libpython needed)")
        .dependOn(&b.addRunArtifact(unit_tests).step);
}

/// Map a target to the pbs platform token the fetch-pbs subcommand understands,
/// or null for targets we don't ship a binary for yet.
fn osArchString(t: std.Target) ?[]const u8 {
    return switch (t.os.tag) {
        .macos => switch (t.cpu.arch) {
            .aarch64 => "macos-aarch64",
            .x86_64 => "macos-x86_64",
            else => null,
        },
        .linux => switch (t.cpu.arch) {
            .x86_64 => "linux-x86_64",
            .aarch64 => "linux-aarch64",
            else => null,
        },
        else => null,
    };
}
