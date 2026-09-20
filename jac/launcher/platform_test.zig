const std = @import("std");
const platform = @import("platform.zig");

// The native executable's entry point provides these in production.
export var __jac_argc: c_int = 0;
export var __jac_argv: ?[*][*:0]const u8 = null;

// Fixtures were produced by CPython tarfile (PAX_FORMAT) and compression.zstd.
// layers contains independently compressed complete tar archives, matching
// dist.payload.assemble.tar_zst_dir, including a long Unicode PAX path.
const layers = @embedFile("fixtures/layers.tar.zst");

test "extract both payload layers with PAX paths and executable permissions" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try platform.extract(io, gpa, layers, tmp.dir);
    const first = try tmp.dir.readFileAlloc(io, "python/bin/python", gpa, .limited(100));
    defer gpa.free(first);
    try std.testing.expectEqualStrings("first layer\n", first);
    const path = "site/" ++ "long-path-" ** 20 ++ "/unicode-λ.jac";
    const second = try tmp.dir.readFileAlloc(io, path, gpa, .limited(100));
    defer gpa.free(second);
    try std.testing.expectEqualStrings("second\x00layer\n", second);
    const stat = try tmp.dir.statFile(io, "python/bin/python", .{});
    try std.testing.expect(stat.permissions.toMode() & 0o100 != 0);
}

test "reject truncated compressed payloads including the second layer" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for ([_]usize{ 1, 8, layers.len / 2, layers.len - 1 }) |length| {
        const result = platform.extract(std.testing.io, std.testing.allocator, layers[0..length], tmp.dir);
        if (result) |_| return error.AcceptedTruncatedPayload else |_| {}
    }
}

test "reject archive traversal and links" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try std.testing.expectError(error.UnsafeArchivePath, platform.extract(std.testing.io, std.testing.allocator, @embedFile("fixtures/traversal.tar.zst"), tmp.dir));
    try std.testing.expectError(error.UnsupportedArchiveLink, platform.extract(std.testing.io, std.testing.allocator, @embedFile("fixtures/symlink.tar.zst"), tmp.dir));
}
