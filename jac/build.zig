const std = @import("std");

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

const Shim = struct { bin: std.Build.LazyPath, place: *std.Build.Step };

pub fn build(b: *std.Build) void {
    const target = if (b.user_input_options.contains("target"))
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{ .cpu_model = .baseline });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const jacllvm = addLlvmShim(b, target, optimize);

    const launcher_mod = b.createModule(.{
        .root_source_file = b.path("launcher/launcher.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const stub = b.addExecutable(.{ .name = "jac", .root_module = launcher_mod });
    b.step("stub", "Build just the launcher stub (no payload)")
        .dependOn(&b.addInstallArtifact(stub, .{}).step);

    const pyembed_mod = b.createModule(.{
        .root_source_file = b.path("launcher/pyembed.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const pyembed = b.addLibrary(.{ .name = "jacpyembed", .root_module = pyembed_mod, .linkage = .dynamic });
    const pyembed_basename = switch (target.result.os.tag) {
        .windows => "jacpyembed.dll",
        .macos => "libjacpyembed.dylib",
        else => "libjacpyembed.so",
    };
    const pyembed_place = b.addUpdateSourceFiles();
    pyembed_place.addCopyFileToSource(
        pyembed.getEmittedBin(),
        b.fmt("jaclang/runtimelib/client/targets/desktop/native/{s}", .{pyembed_basename}),
    );
    const pyembed_step = b.step("pyembed", "Build the libjacpyembed shim (na desktop host -> fused runtime)");
    pyembed_step.dependOn(&b.addInstallArtifact(pyembed, .{}).step);
    pyembed_step.dependOn(&pyembed_place.step);

    addTests(b, target, optimize);

    const tool_mod = b.createModule(.{
        .root_source_file = b.path("launcher/payload.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const tool = b.addExecutable(.{ .name = "payload", .root_module = tool_mod });
    const root = b.pathFromRoot(".");

    {
        const fetch_ts_only = b.addRunArtifact(tool);
        fetch_ts_only.addArgs(&.{ "fetch-typeshed", root });
        fetch_ts_only.has_side_effects = true;
        b.step("fetch-typeshed", "Fetch the pinned typeshed stdlib stubs into the checkout")
            .dependOn(&fetch_ts_only.step);
    }

    {
        const fetch_llvm = b.addRunArtifact(tool);
        fetch_llvm.addArgs(&.{ "fetch-llvm", b.pathFromRoot(".llvm-build") });
        fetch_llvm.has_side_effects = true;
        b.step("fetch-llvm", "Range-fetch the pinned LLVM subset for the wheel-free jacllvm shim")
            .dependOn(&fetch_llvm.step);
    }

    if (osArchString(b.graph.host.result)) |host_osarch| {
        const fetch_bun = b.addRunArtifact(tool);
        fetch_bun.addArgs(&.{ "fetch-bun", host_osarch, b.pathFromRoot("jaclang/runtimelib/client/_bun") });
        fetch_bun.has_side_effects = true;
        b.step("fetch-bun", "Place the pinned bun into the source tree (editable/dev + tests)")
            .dependOn(&fetch_bun.step);
    }

    const osarch = osArchString(target.result) orelse {
        return;
    };

    const payload: std.Build.LazyPath = if (b.option([]const u8, "payload", "Path to a prebuilt runtime payload .tar.gz")) |p|
        .{ .cwd_relative = p }
    else payload: {
        const pbs_dir = b.pathFromRoot(b.fmt(".pbs-build/{s}", .{osarch}));
        const pbs_python = b.fmt("{s}/python", .{pbs_dir});

        const fetch = b.addRunArtifact(tool);
        fetch.addArgs(&.{ "fetch-pbs", osarch, pbs_dir });
        fetch.has_side_effects = true;

        const fetch_ts = b.addRunArtifact(tool);
        fetch_ts.addArgs(&.{ "fetch-typeshed", root });
        fetch_ts.has_side_effects = true;

        const mk = b.addRunArtifact(tool);
        mk.addArgs(&.{ "mkpayload", pbs_python, root });
        if (b.option(bool, "payload-progress", "Stream the payload build (mkpayload) live; disables its caching") orelse false) {
            mk.stdio = .inherit;
        }
        mk.step.dependOn(&fetch.step);
        mk.step.dependOn(&fetch_ts.step);
        const out = mk.addOutputFileArg("payload.tar.gz");
        if (jacllvm) |shim| {
            mk.addPrefixedFileArg("--shim=", shim.bin);
            b.getInstallStep().dependOn(shim.place);
        }
        mk.addPrefixedFileArg("--pyembed=", pyembed.getEmittedBin());
        b.getInstallStep().dependOn(&pyembed_place.step);
        if (b.option(bool, "skip-precompile", "mkpayload: skip the JIR precompile (faster link validation)") orelse false) {
            mk.addArg("--skip-precompile");
        }
        const opt_jaclang_dir = b.option([]const u8, "jaclang-dir", "Editable dev binary: link the compiler from this dir (containing jaclang/) instead of bundling it");
        const opt_dev = b.option(bool, "dev", "Editable dev binary: link the compiler from the build root instead of bundling it (implies skip-precompile)") orelse false;
        const link_dir: ?[]const u8 = if (opt_jaclang_dir) |d|
            (if (std.fs.path.isAbsolute(d)) d else b.pathFromRoot(d))
        else if (opt_dev) b.pathFromRoot(".") else null;
        if (link_dir) |d| {
            mk.addArg(b.fmt("--link-source={s}", .{d}));
            if (jacllvm == null) std.debug.panic(
                "-Ddev/-Djaclang-dir needs the LLVM shim placed under {s}/jaclang/compiler/passes/native/llvm/. " ++
                    "Run `zig build fetch-llvm` once first (then -Ddev places it automatically).",
                .{d},
            );
        }

        if (link_dir == null) {
            const bun_dir = b.pathFromRoot(b.fmt(".bun-build/{s}", .{osarch}));
            const bun_basename = if (target.result.os.tag == .windows) "bun.exe" else "bun";
            const fetch_bun = b.addRunArtifact(tool);
            fetch_bun.addArgs(&.{ "fetch-bun", osarch, bun_dir });
            fetch_bun.has_side_effects = true;
            mk.step.dependOn(&fetch_bun.step);
            mk.addArg(b.fmt("--bun={s}/{s}", .{ bun_dir, bun_basename }));
        }

        if (link_dir == null) {
            addTreeInputs(b, mk, "jaclang");
            mk.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
            mk.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));
        }
        mk.addFileInput(b.path("_jac_finder.py"));
        mk.addFileInput(b.path("sitecustomize.py"));
        mk.addFileInput(b.path("jac.toml"));
        mk.addFileInput(b.path("launcher/payload.zig"));
        break :payload out;
    };

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

fn addLlvmShim(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Shim {
    const llvm_dir = b.option([]const u8, "llvm-dir", "Extracted LLVM 22.1.x dir (default: the fetch-llvm cache .llvm-build/...)") orelse
        (llvmCacheDir(b, target) orelse return null);
    const io = b.graph.io;
    const libdir = b.fmt("{s}/lib", .{llvm_dir});
    var dir = b.build_root.handle.openDir(io, libdir, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    const shim_srcs = [_][]const u8{
        "assembly.cpp",        "bitcode.cpp",       "config.cpp",
        "core.cpp",            "custom_passes.cpp", "dylib.cpp",
        "executionengine.cpp", "initfini.cpp",      "linker.cpp",
        "memorymanager.cpp",   "module.cpp",        "newpassmanagers.cpp",
        "object_file.cpp",     "orcjit.cpp",        "targets.cpp",
        "type.cpp",            "value.cpp",
    };
    const shim_flags = [_][]const u8{ "-std=c++17", "-fno-rtti", "-fno-exceptions", "-DNDEBUG", "-Wno-deprecated-declarations" };

    const bin: std.Build.LazyPath = if (target.result.os.tag == .macos)
        macosShim(b, target, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags)
    else
        linuxShim(b, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags);

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
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags);
    cc.addArgs(&.{ "-static-libstdc++", "-static-libgcc" });
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    cc.addArg("-Wl,--start-group");
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    cc.addArg("-Wl,--end-group");
    cc.addArgs(&.{ "-lz", "-lxml2", "-lzstd", "-lpthread", "-ldl", "-lm" });
    cc.addArg("-Wl,--exclude-libs,ALL");
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.so");
}

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
    cc.addArgs(&.{ "-arch", switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("jacllvm: unsupported macOS arch for the c++ shim link"),
    } });
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags);
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    const lto_dylib = b.fmt("{s}/lib/libLTO.dylib", .{llvm_dir});
    const lto_abs = if (std.fs.path.isAbsolute(lto_dylib)) lto_dylib else b.pathFromRoot(lto_dylib);
    cc.setEnvironmentVariable("LIBLTO_PATH", lto_abs);
    cc.addPrefixedFileArg("-Wl,-lto_library,", .{ .cwd_relative = lto_abs });
    cc.addArgs(&.{ "-lz", "-lxml2" });
    const brew = b.graph.environ_map.get("HOMEBREW_PREFIX") orelse
        (if (target.result.cpu.arch == .aarch64) "/opt/homebrew" else "/usr/local");
    cc.addArgs(&.{ b.fmt("-I{s}/opt/zstd/include", .{brew}), b.fmt("-L{s}/opt/zstd/lib", .{brew}), "-lzstd" });
    cc.addArgs(&.{ "-Wl,-exported_symbol,_LLVMPY_*", "-Wl,-install_name,@rpath/libjacllvm.dylib" });
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.dylib");
}

fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const test_step = b.step("test", "Run launcher unit tests (no libpython/pbs needed)");

    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("launcher/runtime.zig"),
        .target = target,
        .optimize = optimize,
    });
    const runtime_tests = b.addTest(.{ .name = "runtime-tests", .root_module = runtime_mod });
    test_step.dependOn(&b.addRunArtifact(runtime_tests).step);

    const payload_mod = b.createModule(.{
        .root_source_file = b.path("launcher/payload_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const payload_tests = b.addTest(.{ .name = "payload-tests", .root_module = payload_mod });
    test_step.dependOn(&b.addRunArtifact(payload_tests).step);
}

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
