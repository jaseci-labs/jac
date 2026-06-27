const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;

pub const MAGIC = "JACBIN01";
pub const MAGIC_LEN = 8;
pub const HASH_LEN = 64;
pub const TRAILER_LEN = MAGIC_LEN + 8 + HASH_LEN;

const GZIP_BUF_LEN = flate.max_window_len;

const MAX_PATH = Io.Dir.max_path_bytes;

pub const Error = error{
    BinaryTooSmall,
    ShortTrailer,
    BadMagic,
    PayloadOffsetUnderflow,
    ShortPayloadRead,
    PayloadHashMismatch,
    NoWritableCacheDir,
    MaterializeFailed,
};

pub const Trailer = struct {
    payload_len: u64,
    hash: [HASH_LEN]u8,
    hash16: [16]u8,
};

pub fn hexDigest(digest: *const [32]u8) [HASH_LEN]u8 {
    var hex: [HASH_LEN]u8 = undefined;
    const chars = "0123456789abcdef";
    for (digest, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0xf];
    }
    return hex;
}

pub fn parseTrailer(bytes: *const [TRAILER_LEN]u8) Error!Trailer {
    if (!std.mem.eql(u8, bytes[0..MAGIC_LEN], MAGIC)) return Error.BadMagic;
    const payload_len = std.mem.readInt(u64, bytes[MAGIC_LEN..][0..8], .little);
    var t: Trailer = .{ .payload_len = payload_len, .hash = undefined, .hash16 = undefined };
    @memcpy(&t.hash, bytes[MAGIC_LEN + 8 ..][0..HASH_LEN]);
    @memcpy(&t.hash16, t.hash[0..16]);
    return t;
}

pub fn cacheRoot(
    io: Io,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    out: []u8,
) Error![]const u8 {
    var base_buf: [MAX_PATH]u8 = undefined;
    var base: []const u8 = "";
    if (nonEmpty(xdg_cache_home)) |x| {
        base = x;
    } else if (nonEmpty(home)) |h| {
        base = std.fmt.bufPrint(&base_buf, "{s}/.cache", .{h}) catch "";
    }

    if (base.len != 0) {
        const root = std.fmt.bufPrint(out, "{s}/jac", .{base}) catch return Error.NoWritableCacheDir;
        if (dirWritable(io, root)) return root;
    }

    const tmp = nonEmpty(tmpdir) orelse "/tmp";
    const root = std.fmt.bufPrint(out, "{s}/jac-cache-{d}", .{ tmp, uid }) catch return Error.NoWritableCacheDir;
    if (!dirWritable(io, root)) return Error.NoWritableCacheDir;
    return root;
}

fn nonEmpty(s: ?[]const u8) ?[]const u8 {
    if (s) |v| {
        if (v.len != 0) return v;
    }
    return null;
}

fn dirWritable(io: Io, path: []const u8) bool {
    Io.Dir.cwd().createDirPath(io, path) catch return false;
    var dir = Io.Dir.cwd().openDir(io, path, .{}) catch return false;
    defer dir.close(io);
    const probe = dir.createFile(io, ".jac-write-probe", .{ .truncate = true }) catch return false;
    probe.close(io);
    dir.deleteFile(io, ".jac-write-probe") catch {};
    return true;
}

pub fn materialize(
    io: Io,
    gpa: Allocator,
    exe_path: []const u8,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    pid: i32,
    rt_out: []u8,
) ![]const u8 {
    var file = try Io.Dir.cwd().openFile(io, exe_path, .{});
    var keep_open = true;
    defer if (keep_open) file.close(io);

    const total = try file.length(io);
    if (total < TRAILER_LEN) return Error.BinaryTooSmall;

    var traw: [TRAILER_LEN]u8 = undefined;
    if (try file.readPositionalAll(io, &traw, total - TRAILER_LEN) != TRAILER_LEN)
        return Error.ShortTrailer;
    const trailer = try parseTrailer(&traw);

    var root_buf: [MAX_PATH]u8 = undefined;
    const root = try cacheRoot(io, xdg_cache_home, home, tmpdir, uid, &root_buf);

    const rt = std.fmt.bufPrint(rt_out, "{s}/rt/{s}", .{ root, &trailer.hash16 }) catch
        return Error.MaterializeFailed;

    if (pathExists(io, rt, ".ok")) return rt;

    const poff = std.math.sub(u64, total, TRAILER_LEN + trailer.payload_len) catch
        return Error.PayloadOffsetUnderflow;
    const zbuf = try gpa.alloc(u8, trailer.payload_len);
    defer gpa.free(zbuf);
    if (try file.readPositionalAll(io, zbuf, poff) != trailer.payload_len)
        return Error.ShortPayloadRead;
    file.close(io);
    keep_open = false;

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(zbuf, &digest, .{});
    if (!std.mem.eql(u8, &hexDigest(&digest), &trailer.hash))
        return Error.PayloadHashMismatch;

    try extractPayload(io, gpa, zbuf, rt, pid);
    gcStale(io, root, &trailer.hash16);
    return rt;
}

fn extractPayload(
    io: Io,
    gpa: Allocator,
    zbuf: []const u8,
    rt: []const u8,
    pid: i32,
) !void {
    var tmp_buf: [MAX_PATH]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tmp_buf, "{s}.tmp.{d}", .{ rt, pid }) catch
        return Error.MaterializeFailed;

    Io.Dir.cwd().deleteTree(io, tmp) catch {};
    try Io.Dir.cwd().createDirPath(io, tmp);

    {
        var dest = try Io.Dir.cwd().openDir(io, tmp, .{});
        defer dest.close(io);

        const window = try gpa.alloc(u8, GZIP_BUF_LEN);
        defer gpa.free(window);

        var src = Io.Reader.fixed(zbuf);
        var dz = flate.Decompress.init(&src, .gzip, window);
        try std.tar.extract(io, dest, &dz.reader, .{
            .mode_mode = .ignore,
            .strip_components = 0,
        });

        const okf = try dest.createFile(io, ".ok", .{});
        okf.close(io);
    }

    Io.Dir.rename(Io.Dir.cwd(), tmp, Io.Dir.cwd(), rt, io) catch {
        Io.Dir.cwd().deleteTree(io, tmp) catch {};
        if (!pathExists(io, rt, ".ok")) return Error.MaterializeFailed;
    };
}

fn gcStale(io: Io, root: []const u8, keep_hash16: *const [16]u8) void {
    var rtbuf: [MAX_PATH]u8 = undefined;
    const rtdir = std.fmt.bufPrint(&rtbuf, "{s}/rt", .{root}) catch return;
    var dir = Io.Dir.cwd().openDir(io, rtdir, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, keep_hash16)) continue;
        if (std.mem.indexOf(u8, entry.name, ".tmp.") != null) continue;
        dir.deleteTree(io, entry.name) catch {};
    }
}

fn pathExists(io: Io, dir: []const u8, name: []const u8) bool {
    var buf: [MAX_PATH]u8 = undefined;
    const p = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch return false;
    const f = Io.Dir.cwd().openFile(io, p, .{}) catch return false;
    f.close(io);
    return true;
}

const testing = std.testing;

test "parseTrailer decodes magic, length and hash16" {
    var raw: [TRAILER_LEN]u8 = undefined;
    @memcpy(raw[0..MAGIC_LEN], MAGIC);
    std.mem.writeInt(u64, raw[MAGIC_LEN..][0..8], 0x1122334455, .little);
    const hex = "0123456789abcdef" ** 4;
    @memcpy(raw[MAGIC_LEN + 8 ..][0..HASH_LEN], hex);

    const t = try parseTrailer(&raw);
    try testing.expectEqual(@as(u64, 0x1122334455), t.payload_len);
    try testing.expectEqualStrings("0123456789abcdef", &t.hash16);
}

test "parseTrailer rejects a bad magic" {
    var raw: [TRAILER_LEN]u8 = std.mem.zeroes([TRAILER_LEN]u8);
    @memcpy(raw[0..MAGIC_LEN], "NOTJACBN");
    try testing.expectError(Error.BadMagic, parseTrailer(&raw));
}

test "cacheRoot prefers XDG_CACHE_HOME and falls back when unwritable" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var base_buf: [MAX_PATH]u8 = undefined;
    const base = base_buf[0..try tmp.dir.realPath(io, &base_buf)];

    var out: [MAX_PATH]u8 = undefined;
    const root = try cacheRoot(io, base, null, null, 1000, &out);
    try testing.expect(std.mem.endsWith(u8, root, "/jac"));
    try testing.expect(std.mem.startsWith(u8, root, base));

    var tmp_buf: [MAX_PATH]u8 = undefined;
    const tmpdir = tmp_buf[0..try tmp.dir.realPath(io, &tmp_buf)];
    const fb = try cacheRoot(io, "/proc/nonexistent/ro", null, tmpdir, 4242, &out);
    try testing.expect(std.mem.indexOf(u8, fb, "jac-cache-4242") != null);
}

test "materialize extracts the fixture payload and is idempotent" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    const hex = hexDigest(&digest);

    var bin = std.array_list.Managed(u8).init(testing.allocator);
    defer bin.deinit();
    try bin.appendSlice("STUB");
    try bin.appendSlice(payload);
    try bin.appendSlice(MAGIC);
    var lenle: [8]u8 = undefined;
    std.mem.writeInt(u64, &lenle, payload.len, .little);
    try bin.appendSlice(&lenle);
    try bin.appendSlice(&hex);

    try tmp.dir.writeFile(io, .{ .sub_path = "jacbin", .data = bin.items });
    var ebuf: [MAX_PATH]u8 = undefined;
    const exe = ebuf[0..try tmp.dir.realPathFile(io, "jacbin", &ebuf)];

    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf);

    try testing.expect(std.mem.endsWith(u8, rt, hex[0..16]));

    var dir = try Io.Dir.cwd().openDir(io, rt, .{});
    defer dir.close(io);
    var fbuf: [64]u8 = undefined;
    const marker = try dir.readFile(io, "python/lib/marker.txt", &fbuf);
    try testing.expectEqualStrings("pybytecode-marker\n", marker);
    const deep = try dir.readFile(io, "site/nested/deep.txt", &fbuf);
    try testing.expectEqualStrings("nested-ok\n", deep);

    var rtbuf2: [MAX_PATH]u8 = undefined;
    const rt2 = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf2);
    try testing.expectEqualStrings(rt, rt2);
}
