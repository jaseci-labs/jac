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
            .x86_64 => "LLVM-20.1.8-Linux-X64",
            .aarch64 => "LLVM-20.1.8-Linux-ARM64",
            else => return null,
        },
        .macos => switch (target.result.cpu.arch) {
            .aarch64 => "LLVM-20.1.8-macOS-ARM64",
            else => return null,
        },
        else => return null,
    };
    return b.fmt("{s}/{s}", .{ LLVM_CACHE_BASE, dirname });
}

// The built LLVMPY_* shim: `lib` is bundled into the payload (--shim); `place`
// writes it into the source tree for the editable dev loop.
const Shim = struct { lib: *std.Build.Step.Compile, place: *std.Build.Step };

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
    // (an extracted LLVM 20.1.x prebuilt); without it the step is unavailable so
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

    // Standalone: download + extract the pinned LLVM for the jacllvm shim into
    // .llvm-build/ (one-time, ~1.5-2 GB per host). After this, a plain `zig build`
    // picks it up via llvmCacheDir and ships the wheel-free binary.
    {
        const fetch_llvm = b.addRunArtifact(tool);
        fetch_llvm.addArgs(&.{ "fetch-llvm", b.pathFromRoot(".llvm-build") });
        fetch_llvm.has_side_effects = true;
        b.step("fetch-llvm", "Download + extract the pinned LLVM for the wheel-free jacllvm shim")
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
            mk.addPrefixedFileArg("--shim=", shim.lib.getEmittedBin());
            // A plain `zig build` also drops the shim into the source tree so the
            // editable dev loop works without any manual step.
            b.getInstallStep().dependOn(shim.place);
        }
        if (b.option(bool, "skip-precompile", "mkpayload: skip the JIR precompile (faster link validation)") orelse false) {
            mk.addArg("--skip-precompile");
        }
        // Track the payload's real inputs so it repacks when any source changes.
        // NOTE: addDirectoryArg hashes only the directory PATH (Zig 0.16
        // Run.zig), not its contents -- a bare dir arg silently never
        // invalidates. addFileInput content-hashes each file, so enumerate the
        // tree (this is what mkpayload bundles via the jaclang copy).
        addTreeInputs(b, mk, "jaclang");
        mk.addFileInput(b.path("_jac_finder.py"));
        mk.addFileInput(b.path("sitecustomize.py"));
        mk.addFileInput(b.path("jac.toml"));
        mk.addFileInput(b.path("launcher/payload.zig"));
        // PIN + TARBALL_SHA256 drive the fetched typeshed version; they live
        // under jaclang/ (so addTreeInputs covers them) but list them explicitly
        // as the cache-bust keys.
        mk.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
        mk.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));
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
/// PATH is an extracted LLVM 20.1.x release (`lib/libLLVM*.a` + `include/`); a
/// future `fetch-llvm` step downloads it at a pinned version (mirrors fetch-pbs).
/// The Jac binding loads the result via ctypes (JAC_LLVM_SHIM / payload path).
fn addLlvmShim(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Shim {
    // -Dllvm-dir wins; otherwise use the fetch-llvm cache (.llvm-build). If
    // neither has LLVM, return null and the build fails at mkpayload with a
    // "run `zig build fetch-llvm`" message (so fetch-llvm itself still configures
    // before LLVM exists). The shim is required -- there is no wheel fallback.
    const llvm_dir = b.option([]const u8, "llvm-dir",
        "Extracted LLVM 20.1.x dir (default: the fetch-llvm cache .llvm-build/...)") orelse
        (llvmCacheDir(b, target) orelse return null);
    const io = b.graph.io;
    const libdir = b.fmt("{s}/lib", .{llvm_dir});
    var dir = b.build_root.handle.openDir(io, libdir, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    // The shim wraps LLVM's C++ API; CMake builds it C++17, no-RTTI/exceptions.
    mod.addCSourceFiles(.{
        .root = b.path("native"),
        .files = &.{
            "assembly.cpp",       "bitcode.cpp",        "config.cpp",
            "core.cpp",           "custom_passes.cpp",  "dylib.cpp",
            "executionengine.cpp", "initfini.cpp",      "linker.cpp",
            "memorymanager.cpp",  "module.cpp",         "newpassmanagers.cpp",
            "object_file.cpp",    "orcjit.cpp",         "targets.cpp",
            "type.cpp",           "value.cpp",
        },
        .flags = &.{ "-std=c++17", "-fno-rtti", "-fno-exceptions", "-DNDEBUG" },
    });
    mod.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{llvm_dir}) });

    const lib = b.addLibrary(.{ .name = "jacllvm", .linkage = .dynamic, .root_module = mod });

    // macOS: Zig's self-hosted Mach-O linker rejects some object members in
    // LLVM's release archives ("unknown cpu architecture: 0"). LLD's Mach-O
    // backend (bundled with Zig) links LLVM's own archives cleanly, so force it
    // there. Linux keeps its default linker -- the path that already builds and
    // is exercised in CI.
    if (target.result.os.tag == .macos) lib.use_lld = true;

    // Link every LLVM static archive; the linker drops what the shim never
    // references (host-only pruning of the archive set is a size follow-up).
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    // LLVM's system deps. zstd must resolve to the shared lib: the system static
    // libzstd.a is non-PIC and cannot link into a shared object. linkSystemLibrary
    // (preferred dynamic) lets the linker find it portably via its search path,
    // instead of a hardcoded Debian/Ubuntu multiarch .so path.
    mod.linkSystemLibrary("z", .{});
    mod.linkSystemLibrary("xml2", .{});
    mod.linkSystemLibrary("zstd", .{ .preferred_link_mode = .dynamic });

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
    place.addCopyFileToSource(lib.getEmittedBin(), b.fmt("jaclang/compiler/passes/native/llvm/{s}", .{shim_file}));

    const jacllvm_step = b.step("jacllvm", "Build the LLVMPY_* shim (jac/native), static-link LLVM, place it in-tree");
    jacllvm_step.dependOn(&b.addInstallArtifact(lib, .{}).step);
    jacllvm_step.dependOn(&place.step);
    return .{ .lib = lib, .place = &place.step };
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
