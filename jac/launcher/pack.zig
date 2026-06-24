//! Build-time tool: concatenate `[ stub ][ payload.tar.gz ][ trailer ]` into
//! the final `jac` binary. The trailer (magic | payload_len u64 LE | sha256 hex)
//! matches what `runtime.zig` parses at startup.
//!
//!   pack <stub> <payload.tar.gz> <out>

const std = @import("std");
const Io = std.Io;
const runtime = @import("runtime.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var args: [4][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |a| : (n += 1) {
        if (n < args.len) args[n] = a;
    }
    if (n < 4) {
        std.debug.print("usage: pack <stub> <payload.tar.gz> <out>\n", .{});
        return error.Usage;
    }

    const stub = try Io.Dir.cwd().readFileAlloc(io, args[1], gpa, .unlimited);
    const payload = try Io.Dir.cwd().readFileAlloc(io, args[2], gpa, .unlimited);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    // Exactly two lowercase hex chars per byte (64 total); see runtime.hexDigest.
    const hex = runtime.hexDigest(&digest);

    var lenle: [8]u8 = undefined;
    std.mem.writeInt(u64, &lenle, payload.len, .little);

    var out = try Io.Dir.cwd().createFile(io, args[3], .{ .truncate = true });
    defer out.close(io);
    try out.writeStreamingAll(io, stub);
    try out.writeStreamingAll(io, payload);
    try out.writeStreamingAll(io, runtime.MAGIC);
    try out.writeStreamingAll(io, &lenle);
    try out.writeStreamingAll(io, &hex);

    // Mark the output executable (the file is created 0644). Best-effort, posix.
    const out_z = try gpa.dupeZ(u8, args[3]);
    defer gpa.free(out_z);
    _ = std.c.chmod(out_z.ptr, 0o755);
}
