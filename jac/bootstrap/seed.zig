//! Shared floor for the Zig bootstrap seeds (`build_python.zig`,
//! `fetch_typeshed.zig`): the fetch + verify + report primitives every one of
//! them needs. These programs run before any Python exists, so this is
//! std-only -- std.http, std.crypto, and two writers to stderr.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

/// GET a pinned source with bounded retries for transport and temporary server
/// failures. Each attempt owns its client/buffer; partial downloads are discarded.
/// Callers still verify the complete archive's checksum before using it.
pub fn httpGetAlloc(io: Io, gpa: Allocator, url: []const u8) ![]u8 {
    return fetchWithRetry(io, gpa, url, httpGetOnce) catch |err|
        die("http fetch failed for {s}: {s}", .{ url, @errorName(err) });
}

fn fetchWithRetry(io: Io, gpa: Allocator, url: []const u8, comptime fetch: anytype) ![]u8 {
    for (0..3) |attempt| {
        return fetch(io, gpa, url) catch |err| {
            if (attempt == 2 or err == error.HttpStatusFailure or
                err == error.OutOfMemory or err == error.Canceled) return err;
            log("http retry {d}/3 for {s}: {s}", .{ attempt + 2, url, @errorName(err) });
            try Io.sleep(io, .fromMilliseconds(@as(i64, @intCast(attempt + 1)) * 500), .awake);
            continue;
        };
    }
    unreachable;
}

fn httpGetOnce(io: Io, gpa: Allocator, url: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const res = try client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &aw.writer,
        .redirect_behavior = @enumFromInt(10),
    });
    if (res.status != .ok) {
        const code = @intFromEnum(res.status);
        log("http {d} for {s}", .{ code, url });
        if (code == 408 or code == 429 or code >= 500) return error.HttpRetryableStatus;
        return error.HttpStatusFailure;
    }
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

test "source downloads recover from a transient TLS failure without fallback data" {
    const Fetch = struct {
        var calls: usize = 0;
        fn get(_: Io, a: Allocator, _: []const u8) ![]u8 {
            calls += 1;
            if (calls == 1) return error.TlsInitializationFailed;
            return a.dupe(u8, "complete archive");
        }
    };
    Fetch.calls = 0;
    const data = try fetchWithRetry(std.testing.io, std.testing.allocator, "https://source.invalid/archive", Fetch.get);
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("complete archive", data);
    try std.testing.expectEqual(@as(usize, 2), Fetch.calls);
}

test "permanent HTTP failures do not retry" {
    const Fetch = struct {
        var calls: usize = 0;
        fn get(_: Io, _: Allocator, _: []const u8) ![]u8 {
            calls += 1;
            return error.HttpStatusFailure;
        }
    };
    Fetch.calls = 0;
    try std.testing.expectError(error.HttpStatusFailure, fetchWithRetry(std.testing.io, std.testing.allocator, "https://source.invalid/missing", Fetch.get));
    try std.testing.expectEqual(@as(usize, 1), Fetch.calls);
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
