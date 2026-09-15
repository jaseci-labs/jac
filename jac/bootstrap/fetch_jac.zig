//! Acquire the stage-0 compiler without needing an installed Jac or Python.
//! Reuses the bootstrap HTTP/checksum floor; verifies cached bytes on every use.
const std = @import("std");
const seed = @import("seed.zig");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();
    const url = args.next() orelse return error.MissingUrl;
    const expected = args.next() orelse return error.MissingDigest;
    const output = args.next() orelse return error.MissingOutput;
    const offline = if (args.next()) |arg| blk: {
        if (!std.mem.eql(u8, arg, "--offline")) return error.UnexpectedArgument;
        break :blk true;
    } else false;
    if (args.next() != null) return error.UnexpectedArgument;
    try validateDigest(expected);
    const io = init.io;
    const gpa = init.gpa;
    const cwd = Io.Dir.cwd();
    if (try verified(io, gpa, cwd, output, expected)) {
        try executable(io, cwd, output);
        seed.log("stage-0: verified cached compiler {s}", .{output});
        return;
    }
    if (offline) return error.BootstrapCompilerUnavailableOffline;
    seed.log("stage-0: downloading {s}", .{url});
    const bytes = try seed.httpGetAlloc(io, gpa, url);
    defer gpa.free(bytes);
    if (std.fs.path.dirname(output)) |parent| try cwd.createDirPath(io, parent);
    try install(io, gpa, cwd, output, bytes, expected);
    seed.log("stage-0: installed verified compiler {s}", .{output});
}

fn validateDigest(expected: []const u8) !void {
    if (expected.len != 64) return error.InvalidDigest;
    for (expected) |c| {
        if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return error.InvalidDigest;
    }
}

fn verified(io: Io, gpa: std.mem.Allocator, dir: Io.Dir, path: []const u8, expected: []const u8) !bool {
    try validateDigest(expected);
    const bytes = dir.readFileAlloc(io, path, gpa, .limited(512 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer gpa.free(bytes);
    const actual = seed.sha256Hex(bytes);
    return std.mem.eql(u8, &actual, expected);
}

fn executable(io: Io, dir: Io.Dir, path: []const u8) !void {
    const file = try dir.openFile(io, path, .{});
    defer file.close(io);
    try file.setPermissions(io, .fromMode(0o755));
}

fn install(io: Io, gpa: std.mem.Allocator, dir: Io.Dir, path: []const u8, bytes: []const u8, expected: []const u8) !void {
    try validateDigest(expected);
    const actual = seed.sha256Hex(bytes);
    if (!std.mem.eql(u8, &actual, expected)) return error.ChecksumMismatch;
    var random: [16]u8 = undefined;
    io.random(&random);
    const temporary = try std.fmt.allocPrint(gpa, "{s}.{x}.tmp", .{ path, random });
    defer gpa.free(temporary);
    const file = try dir.createFile(io, temporary, .{ .exclusive = true });
    defer dir.deleteFile(io, temporary) catch {};
    {
        defer file.close(io);
        try file.writeStreamingAll(io, bytes);
        try file.setPermissions(io, .fromMode(0o755));
    }
    try dir.rename(temporary, dir, path, io);
}

test "verified install repairs corrupt cache and rejects bad downloads atomically" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const payload = "compiler artifact";
    const digest = seed.sha256Hex(payload);
    try std.testing.expect(!try verified(io, gpa, tmp.dir, "jac", &digest));
    try install(io, gpa, tmp.dir, "jac", payload, &digest);
    try std.testing.expect(try verified(io, gpa, tmp.dir, "jac", &digest));
    try std.testing.expectError(error.ChecksumMismatch, install(io, gpa, tmp.dir, "jac", "wrong compiler", &digest));
    try std.testing.expect(try verified(io, gpa, tmp.dir, "jac", &digest));
    try tmp.dir.writeFile(io, .{ .sub_path = "jac", .data = "corrupt cache" });
    try std.testing.expect(!try verified(io, gpa, tmp.dir, "jac", &digest));
    try install(io, gpa, tmp.dir, "jac", payload, &digest);
    try std.testing.expect(try verified(io, gpa, tmp.dir, "jac", &digest));
}

test "invalid lock digests are rejected before acquisition" {
    try std.testing.expectError(error.InvalidDigest, validateDigest(""));
    try std.testing.expectError(error.InvalidDigest, validateDigest("g" ** 64));
}
