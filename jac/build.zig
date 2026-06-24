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
