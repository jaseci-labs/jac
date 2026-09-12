//! Shared floor for the Zig bootstrap seeds (`build_python.zig`,
//! `fetch_typeshed.zig`): the fetch + verify + report primitives every one of
//! them needs. These programs run before any Python exists, so this is
//! std-only -- std.http, std.crypto, and two writers to stderr.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

/// GET `url` into an owned buffer, following redirects. Any transport error or
/// non-200 status is fatal: a seed with no input has nothing to fall back on.
pub fn httpGetAlloc(io: Io, gpa: Allocator, url: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const res = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &aw.writer,
        .redirect_behavior = @enumFromInt(10),
    }) catch |err| die("http fetch failed for {s}: {s}", .{ url, @errorName(err) });
    if (res.status != .ok) die("http {d} for {s}", .{ @intFromEnum(res.status), url });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

pub fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var hex: [64]u8 = undefined;
    const chars = "0123456789abcdef";
    for (digest, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0xf];
    }
    return hex;
}

pub fn fileExists(io: Io, path: []const u8) bool {
    const f = Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    f.close(io);
    return true;
}

pub fn die(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(1);
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
