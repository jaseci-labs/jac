//! Build the self-contained `jac` binary.
//!
//! The launcher (launcher/launcher.zig) links only libc -- it dlopens the
//! bundled CPython at runtime, so NO Python/pbs is needed at build time. The
//! runtime payload (a private CPython + the jaclang site) is produced by
//! launcher/mkpayload.sh and appended to the launcher with a trailer by
//! launcher/pack.zig.
//!
//!   zig build test     # launcher unit tests (no libpython needed)
//!   zig build stub     # just the launcher executable (no payload)
//!   zig build          # the full jac binary -> zig-out/bin/jac   [needs -Dpayload=...]

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- launcher stub (links libc only; Python is dlopened at runtime) ----
    const launcher_mod = b.createModule(.{
        .root_source_file = b.path("launcher/launcher.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const stub = b.addExecutable(.{ .name = "jac", .root_module = launcher_mod });

    const stub_step = b.step("stub", "Build just the launcher stub (no payload)");
    stub_step.dependOn(&b.addInstallArtifact(stub, .{}).step);

    // --- final binary: stub + payload + trailer ----------------------------
    // The payload .tar.zst is built out-of-band (mkpayload.sh) and passed in.
    if (b.option([]const u8, "payload", "Path to the runtime payload .tar.zst")) |payload| {
        const pack_mod = b.createModule(.{
            .root_source_file = b.path("launcher/pack.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        });
        const pack = b.addExecutable(.{ .name = "pack", .root_module = pack_mod });
        const run_pack = b.addRunArtifact(pack);
        run_pack.addFileArg(stub.getEmittedBin()); // stub
        run_pack.addFileArg(.{ .cwd_relative = payload }); // payload .tar.zst (content-tracked)
        const out = run_pack.addOutputFileArg("jac"); // final binary
        const install = b.addInstallBinFile(out, "jac");
        b.getInstallStep().dependOn(&install.step);
    }

    // --- unit tests (pure Zig, no libpython) -------------------------------
    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("launcher/runtime.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .name = "runtime-tests", .root_module = runtime_mod });
    const test_step = b.step("test", "Run launcher runtime unit tests (no libpython needed)");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
