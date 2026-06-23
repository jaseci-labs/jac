//! Build the self-contained `jac` binary.
//!
//! The launcher (launcher/launcher.zig) links only libc -- it dlopens the
//! bundled CPython at runtime, so NO Python/pbs is needed to build the *stub*.
//! `zig build` then fetches a python-build-standalone tree, assembles the
//! runtime payload (launcher/mkpayload.sh), and appends it to the stub with a
//! trailer (launcher/pack.zig) -- all in one command.
//!
//!   zig build test                 # launcher unit tests (no libpython/pbs)
//!   zig build stub                 # just the launcher stub (no payload)
//!   zig build                      # the full jac binary -> zig-out/bin/jac
//!   zig build -Dpayload=PATH       # pack a prebuilt payload (skip fetch+mkpayload)
//!   zig build -Dtarget=aarch64-macos
//!
//! Build-time host tools required for the full binary: bash, curl, zstd, tar,
//! and a Python 3.12 with pip (the pbs interpreter provides its own; only used
//! to assemble the payload). The shipped binary needs none of these.

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

    const osarch = osArchString(target.result) orelse {
        // Unsupported target for a full binary; stub + test steps still work.
        return;
    };

    // --- runtime payload: -Dpayload override, else fetch pbs + mkpayload ----
    const payload: std.Build.LazyPath = if (b.option([]const u8, "payload", "Path to a prebuilt runtime payload .tar.zst")) |p|
        .{ .cwd_relative = p }
    else payload: {
        const pbs_dir = b.pathFromRoot(b.fmt(".pbs-build/{s}", .{osarch}));
        const pbs_python = b.fmt("{s}/python", .{pbs_dir});

        const fetch = b.addSystemCommand(&.{ "bash", "launcher/fetch-pbs.sh", osarch, pbs_dir });
        const mk = b.addSystemCommand(&.{ "bash", "launcher/mkpayload.sh", pbs_python, b.pathFromRoot(".") });
        mk.step.dependOn(&fetch.step);
        const out = mk.addOutputFileArg("payload.tar.zst");
        // Track the payload's real inputs so it rebuilds when any change; these
        // trailing args are ignored by mkpayload.sh (it reads $1/$2/$3).
        mk.addDirectoryArg(b.path("jaclang"));
        mk.addFileArg(b.path("jac.toml"));
        mk.addFileArg(b.path("launcher/mkpayload.sh"));
        mk.addFileArg(b.path("launcher/fetch-pbs.sh"));
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

/// Map a target to the pbs platform token fetch-pbs.sh understands, or null for
/// targets we don't ship a binary for yet.
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
