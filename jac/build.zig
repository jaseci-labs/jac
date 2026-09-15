//! Build a self-contained Jac binary from a verified prior Jac release.
//!
//! Stage 0 builds a bootstrap kernel and compiler image. The current compiler
//! builds the shipped kernel and completes stage 1. Packaging consumes stage 1
//! and its native runtime; stage 2 independently rebuilds the kernel and image.
//!
//! Python and native dependencies are built from pinned sources using Zig.
//! Each full distribution builds on its matching release runner.
//!
//!   zig build fetch-jac            # acquire and verify the pinned compiler
//!   zig build compiler-image       # stage 1 -> zig-out/compiler-site
//!   zig build compiler-stage2      # self rebuild -> zig-out/stage2-site
//!   zig build verify-compiler-image
//!   zig build build-python         # source-built Python runtime
//!   zig build                      # complete binary -> zig-out/bin/jac
//!   zig build test                 # offline bootstrap tests
//!
const std = @import("std");
// Pinned toolchain inputs (Python, LLVM slices), read from bootstrap/pins.json --
// the single source of truth shared with the Jac payload tool.
const pins = @import("bootstrap/pins.zig");
const build_options = @import("bootstrap/build_options.zig");
const llvm_shim = @import("bootstrap/llvm_shim.zig");

/// Run tools from an explicit compiled image in an isolated interpreter.
/// The build never adds the checkout to Python's import path.
const JACBOOT_SRC =
    "import os, sys\n" ++
    "sys.stdout = sys.stderr\n" ++
    "sys.dont_write_bytecode = True\n" ++
    "root, mode, argv = sys.argv[1], sys.argv[2], sys.argv[3:]\n" ++
    "sys.path.insert(0, root)\n" ++
    "if mode == 'stubcat': os.environ['JAC_STUBCAT_BUILDING'] = '1'\n" ++
    "import _jac_finder\n" ++
    "_jac_finder.install()\n" ++
    "if mode == 'stubcat':\n" ++
    "    from jaclang.compiler.types.stubcat.build import main\n" ++
    "    sys.exit(int(main(argv) or 0))\n" ++
    "if mode == 'payload':\n" ++
    "    from jaclang.dist.payload.cli import main\n" ++
    "    sys.exit(int(main(argv) or 0))\n" ++
    "sys.argv = ['jac'] + argv\n" ++
    "from jaclang.cli.cli_boot import start_cli\n" ++
    "start_cli()\n";

/// Image and interpreter dependencies accompany every tool invocation.
const JacTool = struct {
    b: *std.Build,
    python: []const u8,
    image: std.Build.LazyPath,
    build_python: *std.Build.Step,
    fetch_typeshed: *std.Build.Step,

    fn run(self: JacTool, mode: []const u8, args: []const []const u8) *std.Build.Step.Run {
        const cmd = self.b.addSystemCommand(&.{ self.python, "-I", "-S", "-c", JACBOOT_SRC });
        isolateCompilerRun(cmd);
        cmd.addDirectoryArg(self.image);
        cmd.addArg(mode);
        const python_dir = std.fs.path.dirname(std.fs.path.dirname(std.fs.path.dirname(self.python).?).?).?;
        cmd.setEnvironmentVariable("SSL_CERT_FILE", self.b.fmt("{s}/build/cacert.pem", .{python_dir}));
        cmd.setEnvironmentVariable("JAC_NATIVE_FLOOR_DIR", self.b.fmt("{s}/build/lib", .{python_dir}));
        cmd.addArgs(args);
        cmd.step.dependOn(self.build_python);
        cmd.step.dependOn(self.fetch_typeshed);
        return cmd;
    }
};

fn isolateCompilerRun(run: *std.Build.Step.Run) void {
    // Run hashes its whole environment. Inheriting CI run IDs, shell state, or
    // unrelated application settings defeats artifact reuse and source isolation.
    const inherited = &run.step.owner.graph.environ_map;
    run.clearEnvironment();
    for ([_][]const u8{
        "PATH",        "HOME",        "XDG_CACHE_HOME", "XDG_DATA_HOME",
        "HTTP_PROXY",  "HTTPS_PROXY", "NO_PROXY",       "http_proxy",
        "https_proxy", "no_proxy",    "TMPDIR",
    }) |name| {
        if (inherited.get(name)) |value| run.setEnvironmentVariable(name, value);
    }
    run.setEnvironmentVariable("JAC_NO_DEV_SOURCE", "1");
}

fn configureCompilerKernel(b: *std.Build, run: *std.Build.Step.Run, target: std.Build.ResolvedTarget) std.Build.LazyPath {
    if (target.result.cpu.arch != b.graph.host.result.cpu.arch or target.result.os.tag != b.graph.host.result.os.tag) {
        run.step.dependOn(&b.addFail("Compiler images must be built on a matching OS and architecture; use the corresponding release runner").step);
    }
    run.addFileArg(b.path("bootstrap/compiler.jac"));
    run.addArgs(&.{ "kernel", b.pathFromRoot("jaclang") });
    const name = if (target.result.os.tag == .macos) "libjac_compiler.dylib" else "libjac_compiler.so";
    const kernel = run.addOutputFileArg(name);
    run.addArg(b.fmt("{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        if (target.result.os.tag == .macos) "apple-darwin" else "unknown-linux-gnu",
    }));
    addTreeInputs(b, run, "jaclang");
    run.addFileInput(b.path("bootstrap/pins.json"));
    run.addFileInput(b.path("../jac.toml"));
    return kernel;
}

fn configureCompilerImage(b: *std.Build, run: *std.Build.Step.Run, kernel: std.Build.LazyPath, shim: std.Build.LazyPath, jobs: u32) std.Build.LazyPath {
    run.addFileArg(b.path("bootstrap/compiler.jac"));
    run.addArgs(&.{ "image", b.pathFromRoot("jaclang") });
    const image = run.addOutputDirectoryArg("compiler-site");
    run.addFileArg(kernel);
    run.addFileArg(shim);
    run.addArg(b.fmt("{d}", .{jobs}));
    run.addArg(b.pathFromRoot(".compiler-build"));
    run.addArgs(&.{ "compiler/jc_unit.jac", "compiler/jc_materialize.jac" });
    addTreeInputs(b, run, "jaclang");
    run.addFileInput(b.path("_jac_finder.py"));
    run.addFileInput(b.path("bootstrap/python/sources.json"));
    run.addFileInput(b.path("bootstrap/pins.json"));
    run.addFileInput(b.path("../jac.toml"));
    return image;
}

fn completeCompilerImage(b: *std.Build, tool: JacTool, core: std.Build.LazyPath, catalog: std.Build.LazyPath) std.Build.LazyPath {
    const complete = tool.run("jac", &.{ "run", "--backend", "python" });
    complete.setEnvironmentVariable("JAC_STUBCAT_BUILDING", "1");
    complete.addFileArg(b.path("bootstrap/compiler.jac"));
    complete.addArg("complete");
    complete.addDirectoryArg(core);
    complete.addFileArg(catalog);
    return complete.addOutputDirectoryArg("compiler-site");
}

pub fn build(b: *std.Build) void {
    // Build for a BASELINE CPU of the host arch, not the build machine's native
    // CPU. The `jac` binary is distributed -- and in CI it is built once then
    // run on other runners via the setup-jac output cache. If an explicit
    // `-Dtarget=` is passed we honor it as-is; otherwise we pin the host
    // arch/os to a baseline CPU. (The Jac-compiled stub is already emitted for
    // the generic CPU of its triple; this pin governs the C/C++ shim.)
    const target = build_options.target(b);
    const optimize = build_options.optimize(b);
    const python_variant = "jacpython";

    // --- LLVMPY_* shim: compile jac/native/*.cpp + statically link host LLVM ---
    // Replaces the bundled libllvmlite.so (llvmlite wheel). Gated on -Dllvm-dir
    // (an extracted LLVM 22.1.x prebuilt) or the fetch-llvm cache; without
    // either the step is unavailable. See jac/native/README.md, #6925.
    const jacllvm = llvm_shim.add(b, target, optimize);

    // --- unit tests (the Zig bootstrap seed) -------------------------------
    addTests(b, target, optimize);

    // --- Stage 0: the two inputs that must exist before any Jac compiles -----
    // The source-built CPython the Jac tooling runs ON, and the typeshed stdlib stubs it
    // type-checks AGAINST. Type inference is on the critical path of every
    // compilation, so both are hard prerequisites of compiling even the build
    // tooling itself -- which is why both are fetched by Zig seeds and not by
    // the Jac payload tool (#8785). Both validate their input fingerprints before reusing an installed tree.
    const host_osarch = pins.osArchString(b.graph.host.result) orelse {
        // Unsupported build host: only the shim/test steps are available.
        return;
    };
    const fetch_jac_step = b.step("fetch-jac", "Acquire and verify the pinned stage-0 Jac compiler");
    if (pins.jacRelease(b, host_osarch)) |release| {
        const module = b.createModule(.{
            .root_source_file = b.path("bootstrap/fetch_jac.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
            .link_libc = true,
        });
        const executable = b.addExecutable(.{ .name = "fetch_jac", .root_module = module });
        const acquire = b.addRunArtifact(executable);
        acquire.addArgs(&.{ release.url, release.sha256, b.pathFromRoot(b.fmt(".toolchains/jac/{s}/{s}/jac", .{ release.version, host_osarch })) });
        if (b.option(bool, "offline", "Require the pinned bootstrap compiler to be cached") orelse false) acquire.addArg("--offline");
        acquire.has_side_effects = true;
        fetch_jac_step.dependOn(&acquire.step);
    } else {
        const unavailable = b.addFail(b.fmt("No pinned Jac bootstrap compiler for {s}", .{host_osarch}));
        fetch_jac_step.dependOn(&unavailable.step);
    }
    const stage0_path = if (pins.jacRelease(b, host_osarch)) |release|
        b.pathFromRoot(b.fmt(".toolchains/jac/{s}/{s}/jac", .{ release.version, host_osarch }))
    else
        b.pathFromRoot(".toolchains/unavailable/jac");
    const seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/build_python.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const seed = b.addExecutable(.{ .name = "build_python", .root_module = seed_mod });
    const pins_path = b.pathFromRoot(pins.PINS_PATH);
    const host_python_dir = b.pathFromRoot(b.fmt(".python-build/{s}/{s}.host", .{ python_variant, host_osarch }));
    const fetch_host = b.addRunArtifact(seed);
    fetch_host.addArgs(&.{ host_osarch, host_python_dir, b.pathFromRoot("."), b.graph.zig_exe });
    fetch_host.addArg("--host");
    fetch_host.has_side_effects = true;
    b.step("build-host-python", "Build the isolated C Python used for compiler build tools").dependOn(&fetch_host.step);
    const root = b.pathFromRoot(".");

    // The typeshed seed reads its pin (PIN + TARBALL_SHA256) out of the vendor
    // dir it fills, the same two files the payload tool's own fetch-typeshed
    // reads, so the two fetchers can never disagree.
    const ts_seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_typeshed.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const ts_seed = b.addExecutable(.{ .name = "fetch_typeshed", .root_module = ts_seed_mod });
    const fetch_ts = b.addRunArtifact(ts_seed);
    fetch_ts.addArg(b.pathFromRoot("jaclang/vendor/typeshed"));
    // has_side_effects: the output lands in the source tree, not the cache, so
    // the step must run even when its (unchanging) argv would otherwise cache
    // it away -- a clean checkout has to materialize the stubs.
    fetch_ts.has_side_effects = true;
    fetch_ts.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
    fetch_ts.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));

    // Native compiler artifacts belong to the build graph. The pinned compiler
    // owns its runtime and LLVM; payload assembly only consumes the library.
    const kernel_build = b.addSystemCommand(&.{ stage0_path, "run", "--backend", "python" });
    isolateCompilerRun(kernel_build);
    kernel_build.step.dependOn(fetch_jac_step);
    kernel_build.step.dependOn(&fetch_ts.step);
    const compiler_kernel = configureCompilerKernel(b, kernel_build, target);
    b.step("bootstrap-kernel", "Build the temporary kernel used to start the current compiler")
        .dependOn(&kernel_build.step);

    // Stage 1 is an ordinary compiled image produced by the pinned release.
    // Its output is immutable and separate from both producer and target sources.
    const compiler_jobs = b.option(u32, "compiler-jobs", "Parallel compiler-image workers (default 2 for compiler memory use)") orelse 2;
    const image_step = b.step("compiler-image", "Build the current compiler image with the pinned stage-0 compiler");
    const compiler_core: std.Build.LazyPath = if (jacllvm) |shim| image: {
        const image_build = b.addSystemCommand(&.{ stage0_path, "run", "--backend", "python" });
        isolateCompilerRun(image_build);
        image_build.step.dependOn(fetch_jac_step);
        image_build.step.dependOn(&fetch_ts.step);
        const compiler_image = configureCompilerImage(b, image_build, compiler_kernel, shim.bin, compiler_jobs);
        break :image compiler_image;
    } else image: {
        image_step.dependOn(&b.addFail("compiler-image requires the pinned LLVM shim; run zig build fetch-llvm").step);
        break :image b.path(".unavailable-compiler-image");
    };

    const bootstrap_tool = JacTool{
        .b = b,
        .python = b.fmt("{s}/python/install/bin/python{s}", .{ host_python_dir, pins.pyMinor(b) }),
        .image = compiler_core,
        .build_python = &fetch_host.step,
        .fetch_typeshed = &fetch_ts.step,
    };

    const build_catalog = bootstrap_tool.run("stubcat", &.{});
    const stub_catalog = build_catalog.addOutputFileArg("stubcat.bin");
    b.step("stub-catalog", "Build the typeshed catalog with the current compiler image")
        .dependOn(&build_catalog.step);
    const bootstrap_image = completeCompilerImage(b, bootstrap_tool, compiler_core, stub_catalog);
    var native_tool = bootstrap_tool;
    native_tool.image = bootstrap_image;
    // The predecessor cannot map native source paths. Its kernel only starts
    // this image; the current compiler emits the reproducible shipped kernel.
    const native_kernel_build = native_tool.run("jac", &.{ "run", "--backend", "python" });
    const native_kernel = configureCompilerKernel(b, native_kernel_build, target);
    b.step("compiler-kernel", "Build the shipped kernel with the current native compiler")
        .dependOn(&native_kernel_build.step);
    const finalize_kernel = native_tool.run("jac", &.{ "run", "--backend", "python" });
    finalize_kernel.addFileArg(b.path("bootstrap/compiler.jac"));
    finalize_kernel.addArg("complete-kernel");
    finalize_kernel.addDirectoryArg(bootstrap_image);
    finalize_kernel.addFileArg(native_kernel);
    const compiler_image = finalize_kernel.addOutputDirectoryArg("compiler-site");
    const install_image = b.addInstallDirectory(.{
        .source_dir = compiler_image,
        .install_dir = .prefix,
        .install_subdir = "compiler-site",
    });
    image_step.dependOn(&install_image.step);
    var tool = bootstrap_tool;
    tool.image = compiler_image;

    if (jacllvm) |shim| {
        const rebuild_kernel = tool.run("jac", &.{ "run", "--backend", "python" });
        const stage2_kernel = configureCompilerKernel(b, rebuild_kernel, target);
        const rebuild_image = tool.run("jac", &.{ "run", "--backend", "python" });
        const stage2_core = configureCompilerImage(b, rebuild_image, stage2_kernel, shim.bin, compiler_jobs);
        var stage2_tool = tool;
        stage2_tool.image = stage2_core;
        const rebuild_catalog = stage2_tool.run("stubcat", &.{});
        const stage2_catalog = rebuild_catalog.addOutputFileArg("stubcat.bin");
        const stage2_image = completeCompilerImage(b, stage2_tool, stage2_core, stage2_catalog);
        const install_stage2 = b.addInstallDirectory(.{
            .source_dir = stage2_image,
            .install_dir = .prefix,
            .install_subdir = "stage2-site",
        });
        b.step("compiler-stage2", "Rebuild the compiler kernel and image using stage 1")
            .dependOn(&install_stage2.step);
        stage2_tool.image = stage2_image;
        const verify_stage2 = stage2_tool.run("jac", &.{"test"});
        verify_stage2.addFileArg(b.path("tests/compiler/test_compiler_image.jac"));
        b.step("verify-compiler-stage2", "Verify execution and integrity of the self-rebuilt compiler")
            .dependOn(&verify_stage2.step);
    }

    const verify_image = tool.run("jac", &.{"test"});
    verify_image.addFileArg(b.path("tests/compiler/test_compiler_image.jac"));
    b.step("verify-compiler-image", "Verify the staged compiler in an isolated interpreter")
        .dependOn(&verify_image.step);

    // Standalone step: materialize the gitignored typeshed stdlib stubs at the
    // pinned commit, without building a binary. Used by CI (test-binary) and
    // local dev to enable from-source `jac check` / the test suite. Pure Zig, so
    // it works on a checkout where nothing can compile yet -- which is exactly
    // the state the error messages that point here describe.
    b.step("fetch-typeshed", "Fetch the pinned typeshed stdlib stubs into the checkout")
        .dependOn(&fetch_ts.step);

    // Standalone: fetch the pinned LLVM subset the jacllvm shim needs into
    // .llvm-build/ (one-time, ~84 MB range-fetched from the llvm-slice zip). After
    // this, a plain `zig build` picks it up via llvmCacheDir and ships the
    // wheel-free binary. Pure-Zig bootstrap (no source-built CPython needed).
    {
        const llvm_seed_mod = b.createModule(.{
            .root_source_file = b.path("bootstrap/fetch_llvm.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
            .link_libc = true,
        });
        const llvm_seed = b.addExecutable(.{ .name = "fetch_llvm", .root_module = llvm_seed_mod });
        const fetch_llvm_run = b.addRunArtifact(llvm_seed);
        fetch_llvm_run.addArgs(&.{ host_osarch, b.pathFromRoot(llvm_shim.cache_base), pins_path });
        fetch_llvm_run.has_side_effects = true;
        b.step("fetch-llvm", "Range-fetch the pinned LLVM subset for the wheel-free jacllvm shim")
            .dependOn(&fetch_llvm_run.step);
    }

    // Standalone: place the pinned, contained bun runtime into the source tree at
    // jaclang/client/_bun/ for the HOST. Editable/source checkouts,
    // the test suite, and -Ddev linked binaries resolve it there via get_bun()'s
    // __file__-relative lookup. (Normal/release builds instead bundle a
    // target-matched bun into the payload; see the payload block below.)
    {
        const fetch_bun = tool.run("payload", &.{ "fetch-bun", host_osarch, b.pathFromRoot("jaclang/client/_bun") });
        fetch_bun.has_side_effects = true;
        b.step("fetch-bun", "Place the pinned bun into the source tree (editable/dev + tests)")
            .dependOn(&fetch_bun.step);
    }

    // Standalone: harvest a static-musl runtime (libc.a + libzigc.a + compiler-rt
    // + crt) from the bundled Zig toolchain into .pbs-build/<osarch>/musl/lib, so
    // `jac build --native` can fully static-link Linux executables against musl with
    // NO external toolchain at compile time. Idempotent; Linux only.
    if (std.mem.startsWith(u8, host_osarch, "linux-")) {
        const vendor_musl = tool.run("payload", &.{ "build-musl", host_osarch, b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{host_osarch})), b.graph.zig_exe });
        vendor_musl.has_side_effects = true;
        b.step("vendor-musl", "Harvest a static-musl runtime from Zig into .pbs-build/<osarch>/musl/lib")
            .dependOn(&vendor_musl.step);
    }

    // Arch-parameterized variants: `zig cc -target <arch>-linux-musl` cross-
    // compiles musl from any host, so a cross `jac build --native` and the aarch64 CI
    // lane can static-link without target hardware (#7626 C1).
    inline for ([_][]const u8{ "linux-x86_64", "linux-aarch64" }) |cross_osarch| {
        const vendor_musl_cross = tool.run("payload", &.{ "build-musl", cross_osarch, b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{cross_osarch})), b.graph.zig_exe });
        vendor_musl_cross.has_side_effects = true;
        b.step(b.fmt("vendor-musl-{s}", .{cross_osarch}), b.fmt("Harvest a static-musl runtime for {s} (cross-capable) into .pbs-build/{s}/musl/lib", .{ cross_osarch, cross_osarch }))
            .dependOn(&vendor_musl_cross.step);
    }

    // Standalone: compile the in-repo wasm_rt libc (vendored musl/wasi-libc
    // subset + jac allocator/io/abi adapters) to wasm32 LLVM bitcode under
    // .pbs-build/wasm32/libc, so na->wasm builds link libc INTO the module
    // (#7048). Target-independent, so it runs everywhere.
    {
        const vendor_wasm_libc = tool.run("payload", &.{
            "build-wasm-libc",
            b.pathFromRoot("jaclang/compiler/backends/native/wasm_rt"),
            b.pathFromRoot(".pbs-build/wasm32/libc"),
            b.graph.zig_exe,
        });
        vendor_wasm_libc.has_side_effects = true;
        b.step("vendor-wasm-libc", "Compile the wasm_rt libc to bitcode into .pbs-build/wasm32/libc")
            .dependOn(&vendor_wasm_libc.step);
    }

    const osarch = pins.osArchString(target.result) orelse {
        // Unsupported target for a full binary; the standalone steps still work.
        return;
    };

    // The TARGET's source-built Python tree: the payload input, and the C floor archives
    // (libzstd.a, libcrypto.a, ...) the stub static-links. Same tree as the
    // host's whenever host == target, which is every CI lane.
    const python_dir = b.pathFromRoot(b.fmt(".python-build/{s}/{s}", .{ python_variant, osarch }));
    const python_tree = b.fmt("{s}/python", .{python_dir});
    const build_python_native = tool.run("jac", &.{ "run", "--backend", "python" });
    build_python_native.addFileArg(b.path("bootstrap/compiler.jac"));
    build_python_native.addArgs(&.{ "python-native", b.pathFromRoot("jaclang") });
    const python_native = build_python_native.addOutputFileArg("jacpython.o");
    build_python_native.addArg(b.fmt("{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        if (target.result.os.tag == .macos) "apple-darwin" else "unknown-linux-gnu",
    }));
    addTreeInputs(b, build_python_native, "jaclang");
    build_python_native.addFileInput(b.path("../jac.toml"));
    b.step("python-native", "Compile the native Python compiler with the stage-1 image").dependOn(&build_python_native.step);
    const build_runtime = b.addRunArtifact(seed);
    build_runtime.addArgs(&.{ osarch, python_dir, root, b.graph.zig_exe, "--native-object" });
    build_runtime.addFileArg(python_native);
    build_runtime.has_side_effects = true;
    const fetch_target = &build_runtime.step;
    b.step("build-python", "Build the source-pinned runtime with native JacPython").dependOn(fetch_target);

    // --- launcher stub: the staged compiler compiles launcher/ natively --
    // A native build treats any native-seam demotion in the stub's closure as
    // a hard error: a function demoted to Python-only cannot run before CPython
    // exists. (The whole-program type-check gate is not used here: it cannot
    // see the bundled per-OS native floors the launcher imports.) Needs the
    // staged LLVMPY_* shim and the target's C floor archives.
    const build_stub = tool.run("jac", &.{ "build", "--native" });
    // Pin the selected runtime's libraries and certificates when both variants are cached.
    build_stub.setEnvironmentVariable("JAC_NATIVE_FLOOR_DIR", b.fmt("{s}/build/lib", .{python_tree}));
    build_stub.setEnvironmentVariable("JAC_NATIVE_CA_BUNDLE", b.fmt("{s}/build/cacert.pem", .{python_tree}));
    build_stub.addFileArg(b.path("launcher/launcher.jac"));
    build_stub.addArg("-o");
    const stub = build_stub.addOutputFileArg("jac-stub");
    build_stub.setCwd(b.path("launcher"));
    build_stub.setEnvironmentVariable("JAC_NATIVE_FLOOR_DIR", b.fmt("{s}/build/lib", .{python_tree}));
    build_stub.step.dependOn(fetch_target);
    addTreeInputs(b, build_stub, "jaclang");
    build_stub.addFileInput(b.path("launcher/launcher.jac"));
    b.step("stub", "Build just the launcher stub (no payload)")
        .dependOn(&b.addInstallBinFile(stub, "jac").step);

    // --- runtime payload: -Dpayload override, else mkpayload ---------------
    // The prebuilt stub catalog is also placed in a page-aligned binary region;
    // a prebuilt -Dpayload carries the same catalog as a file inside it.
    var stubcat_region: ?std.Build.LazyPath = null;
    const payload: std.Build.LazyPath = if (b.option([]const u8, "payload", "Path to a prebuilt runtime payload .tar.zst")) |p|
        .{ .cwd_relative = p }
    else payload: {
        // Assemble the payload. Cacheable (output-file arg), so Zig CAPTURES
        // its stdio and prints it only on failure -- the "==>" logs stay hidden.
        // `-Dpayload-progress` flips stdio to .inherit so the build streams live;
        // the tradeoff is .inherit marks the step as having side-effects, so it
        // ALWAYS repacks (no caching) while the flag is on.
        const mk = tool.run("payload", &.{ "mkpayload", python_tree, root });
        if (b.option(bool, "payload-progress", "Stream the payload build (mkpayload) live; disables its caching") orelse false) {
            mk.stdio = .inherit;
        }
        mk.step.dependOn(fetch_target);
        const out = mk.addOutputFileArg("payload.tar.zst");
        mk.addPrefixedDirectoryArg("--compiler-image=", compiler_image);
        mk.addPrefixedFileArg("--stub-catalog=", stub_catalog);
        stubcat_region = stub_catalog;
        // Persistent compressed-frame cache for the payload's deps layer: the
        // level-19 zstd frame over the rarely-changing deps tree is reused when
        // its content is unchanged. Verified by decompress + compare on reuse,
        // so it can never change the payload either.
        mk.addArg(b.fmt("--layer-cache={s}", .{b.pathFromRoot(b.fmt(".payload-layers/{s}", .{python_variant}))}));

        const bun_dir = b.pathFromRoot(b.fmt(".bun-build/{s}", .{osarch}));
        const fetch_bun = tool.run("payload", &.{ "fetch-bun", osarch, bun_dir });
        fetch_bun.has_side_effects = true;
        mk.step.dependOn(&fetch_bun.step);
        mk.addArg(b.fmt("--bun={s}/bun", .{bun_dir}));

        // Linux: harvest a static-musl runtime for the target and bundle it so
        // the shipped binary can fully static-link Linux executables against
        // musl at native build time -- no glibc/loader dep.
        if (std.mem.startsWith(u8, osarch, "linux-")) {
            const musl_lib = b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{osarch}));
            const vendor_musl = tool.run("payload", &.{ "build-musl", osarch, musl_lib, b.graph.zig_exe });
            vendor_musl.has_side_effects = true;
            mk.step.dependOn(&vendor_musl.step);
            mk.addArg(b.fmt("--musl={s}", .{musl_lib}));
        }

        // Build and bundle the wasm32 libc bitcode for native application builds.
        {
            const wasm_libc = b.pathFromRoot(".pbs-build/wasm32/libc");
            const vendor_wasm = tool.run("payload", &.{
                "build-wasm-libc",
                b.pathFromRoot("jaclang/compiler/backends/native/wasm_rt"),
                wasm_libc,
                b.graph.zig_exe,
            });
            // has_side_effects: the output lives outside the cache, so the step
            // must run even when inputs are unchanged (a deleted .pbs-build has
            // to repopulate). The tool itself skips up-to-date per-file work.
            vendor_wasm.has_side_effects = true;
            addTreeInputs(b, vendor_wasm, "jaclang/compiler/backends/native/wasm_rt");
            mk.step.dependOn(&vendor_wasm.step);
            mk.addArg(b.fmt("--wasm-libc={s}", .{wasm_libc}));
        }

        // The compiler image is already a tracked artifact. Track packaging
        // metadata and the independently bundled example template here.
        addTreeInputs(b, mk, "examples/jaclang_org");
        mk.addFileInput(b.path("_jac_finder.py"));
        mk.addFileInput(b.path("sitecustomize.py"));
        // The project manifest (version stamped into dist-info) lives at the
        // repo root, one level above this build root.
        mk.addFileInput(.{ .cwd_relative = b.pathFromRoot("../jac.toml") });
        // The pins (Python/bun/LLVM) and the tool itself; a bump must repack.
        mk.addFileInput(b.path(pins.PINS_PATH));
        mk.addFileInput(b.path("bootstrap/python/sources.json"));
        mk.addFileInput(b.path("bootstrap/python/cpython-sources.txt"));
        // Repack when any runtime source or recipe changes, even in dev mode.
        mk.addFileInput(.{ .cwd_relative = b.fmt("{s}/build-key", .{python_dir}) });
        break :payload out;
    };

    // --- final binary: stub + payload + trailer ----------------------------
    const pack = tool.run("payload", &.{"pack"});
    pack.addFileArg(stub);
    pack.addFileArg(payload);
    const jac = pack.addOutputFileArg("jac");
    if (stubcat_region) |region| {
        pack.addFileArg(region);
    }
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
        std.debug.panic("tree inputs: cannot open {s}: {s}", .{ sub_path, @errorName(err) });
    defer dir.close(io);
    var walker = dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();
    var paths = std.array_list.Managed([]const u8).init(b.allocator);
    while (walker.next(io) catch @panic("tree inputs: walk failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.indexOf(u8, entry.path, "__pycache__") != null) continue;
        if (std.mem.indexOf(u8, entry.path, "node_modules") != null) continue;
        var components = std.mem.splitScalar(u8, entry.path, std.fs.path.sep);
        var generated = false;
        while (components.next()) |component| {
            if (std.mem.eql(u8, component, ".jac") or std.mem.eql(u8, component, ".git") or std.mem.eql(u8, component, "_precompiled")) {
                generated = true;
                break;
            }
        }
        if (generated) continue;
        if (std.mem.startsWith(u8, entry.path, "compiler/libjac_compiler.")) continue;
        if (std.mem.indexOf(u8, entry.path, "libjacllvm.") != null) continue;
        if (std.mem.endsWith(u8, entry.path, ".pyc")) continue;
        paths.append(b.fmt("{s}/{s}", .{ sub_path, entry.path })) catch @panic("OOM");
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);
    for (paths.items) |path| run.addFileInput(b.path(path));
}

fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const test_step = b.step("test", "Run the bootstrap unit tests (no network or Python needed)");
    const jac_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_jac.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const jac_tests = b.addTest(.{ .name = "fetch-jac-tests", .root_module = jac_mod });
    test_step.dependOn(&b.addRunArtifact(jac_tests).step);
    const seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/build_python.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const seed_tests = b.addTest(.{ .name = "build-python-tests", .root_module = seed_mod });
    test_step.dependOn(&b.addRunArtifact(seed_tests).step);
    const llvm_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_llvm.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ts_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_typeshed.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const llvm_tests = b.addTest(.{ .name = "fetch-llvm-tests", .root_module = llvm_mod });
    test_step.dependOn(&b.addRunArtifact(llvm_tests).step);
    const ts_tests = b.addTest(.{ .name = "fetch-typeshed-tests", .root_module = ts_mod });
    test_step.dependOn(&b.addRunArtifact(ts_tests).step);
}
